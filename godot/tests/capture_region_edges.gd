extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var surface=SubViewport.new(); surface.size=Vector2i(1920,1080); surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	var game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true; game.capture_args.path="edge-capture"; game.focused=true
	await process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	var directory=OS.get_environment("ASHEN_EDGE_DIR"); var results=[]
	for id in game.db.regions:
		game.navigate(id); game.world.player=Vector2(2.1,game.db.regions[id].rows-3.1); game.world._update_actor(Vector2.ZERO,0); game.world._update_camera()
		await create_timer(.35).timeout; await RenderingServer.frame_post_draw
		var output=directory.path_join("edge-"+id+"-1920x1080.png"); surface.get_texture().get_image().save_png(output)
		var audit=RailAudit.inspect(game.main_view); audit.passed=audit.passed and game.world._can_walk(game.world.player)
		results.append({"view":"edge-"+id,"width":1920,"height":1080,"output":output,"passed":audit.passed}); print("REGION EDGE: "+id+" "+str(audit.passed))
	var file=FileAccess.open(directory.path_join("regions-edge-acceptance.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"passed":results.all(func(r): return r.passed),"results":results},"  ")); file.close(); quit(0 if results.all(func(r): return r.passed) else 1)
