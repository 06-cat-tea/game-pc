extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var surface=SubViewport.new(); surface.size=Vector2i(1920,1080); surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	var game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true; game.capture_args.path="performance"; game.focused=true
	await process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=false
	var reports=[]
	var night="--night" in OS.get_cmdline_user_args()
	var redraw="--regional-redraw" in OS.get_cmdline_user_args()
	var warmup_ms=5000 if redraw else 2200
	var detailed_spots={"wood":Vector2(16,35),"pass":Vector2(38,27),"fen":Vector2(28,27),"coast":Vector2(37,30.5)}
	if night:
		game.session.state.phase=3
	for id in (detailed_spots.keys() if redraw else (GameContent.OUTDOORS if night else game.db.regions.keys())):
		game.navigate(id)
		if redraw:
			game.world.player=detailed_spots[id]; game.world._update_actor(Vector2.ZERO,0); game.world._update_camera()
		if id=="city": game.world.player=Vector2(48,42); game.world._update_actor(Vector2.ZERO,0); game.world._update_camera()
		# Godot's performance counters refresh once per second; exclude region load and counter rollover.
		var warmup_end=Time.get_ticks_msec()+warmup_ms
		while Time.get_ticks_msec()<warmup_end: await process_frame
		var samples=[]; var cpu=[]; var previous=Time.get_ticks_usec(); var peak_nodes=0; var distance=0.0; var last_position=game.world.player
		for i in 240:
			if i==120: Input.action_release("move_right")
			Input.action_press("move_right" if i<120 else "move_left")
			await process_frame
			var now=Time.get_ticks_usec(); samples.append(float(now-previous)/1000.0); previous=now; cpu.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
			distance+=game.world.player.distance_to(last_position); last_position=game.world.player
			if i%60==0: peak_nodes=maxi(peak_nodes,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		Input.action_release("move_right"); Input.action_release("move_left")
		samples.sort(); cpu.sort(); var mean=0.0
		for value in samples: mean+=value/samples.size()
		var report={"region":id,"phase":game.session.state.phase,"rendered_size":"1920x1080","frames":samples.size(),"mean_ms":snappedf(mean,.01),"mean_fps":snappedf(1000.0/mean,.1),"p95_ms":snappedf(samples[int(samples.size()*.95)],.01),"engine_process_p95_ms":snappedf(cpu[int(cpu.size()*.95)],.01),"scene_tree_nodes":peak_nodes,"particles":game.world.region_layer.particles.amount if game.world.region_layer!=null else 0,"distance_walked":snappedf(distance,.01)}
		reports.append(report); print("REGION PERFORMANCE: "+JSON.stringify(report))
	var result={"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"warmup_ms_per_region":warmup_ms,"detailed_redraw_spots":redraw,"reports":reports,"gate":"Night: monotonic rendered frame mean <33.34 ms and p95 <25 ms, movement >1 cell. Engine monitor retained separately as diagnostic; the night gate uses directly measured frame intervals. Day: existing engine-process gate.","passed":reports.all(func(r): return r.mean_ms<33.34 and (r.p95_ms<25 if night else r.engine_process_p95_ms<25) and r.distance_walked>1.0)}
	var destination=OS.get_environment("ASHEN_PERF_REPORT"); if destination=="": destination="user://regions-performance.json"
	var file=FileAccess.open(destination,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")); file.close(); game.queue_free(); await process_frame; quit(0 if result.passed else 1)
