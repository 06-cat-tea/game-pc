extends SceneTree

var surface: SubViewport
var game
var frames=[]
var failures=[]
var output="res://../artifacts/godot/regional-redraw-review"

func _initialize(): call_deferred("run")

func shot(label: String):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var audit=RailAudit.inspect(game.main_view)
	if not audit.passed: failures.append(label+": "+str(audit.overflow))
	surface.get_texture().get_image().save_png(output.path_join(label+".png"))
	frames.append({"label":label,"size":str(surface.size),"audit":audit.passed})

func place(id: String, p: Vector2):
	game.session.state.location={"scene":id,"x":p.x,"y":p.y}; game.world.scene_id=""; game.mode="world"; game.refresh()
	game.world.stop(); game.world._update_actor(Vector2.ZERO,0); game.world._update_camera(); game.world.region_layer._update_visibility()
	await process_frame

func run():
	create_timer(240).timeout.connect(func(): push_error("Regional review timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	surface=SubViewport.new(); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true
	await process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	game.toast_label.hide(); game.world.set_process(false)
	var spots={"wood":Vector2(16,35),"pass":Vector2(38,27),"fen":Vector2(28,27),"coast":Vector2(37,30.5)}
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(3840,2160)]:
		surface.size=dimensions
		for id in spots:
			game.session.state.phase=1; await place(id,spots[id]); await shot(id+"-"+str(dimensions.x))
	surface.size=Vector2i(1920,1080)
	for id in spots:
		await place(id,spots[id])
		for b in game.db.regions[id].buildings:
			game.world.player=Vector2(b.entry[0],b.entry[1]); game.world._update_actor(Vector2.ZERO,0); game.world._update_camera(); game.world.region_layer._update_visibility(); await shot("detail-"+b.id)
		game.session.state.phase=3; game.world.lighting._process(.3); await shot(id+"-night")
		game.session.state.phase=1
	# Bake actual region overviews in neutral daylight, without touching town/city maps.
	game.ui.hide(); surface.size_2d_override=Vector2i(2048,1024); surface.transparent_bg=true
	var bake_ids=[] if "--screens-only" in OS.get_cmdline_user_args() else spots.keys()
	for id in bake_ids:
		await place(id,spots[id]); game.world.hero.hide(); game.world.hero_shadow.hide(); game.world.region_layer.freeze_for_capture()
		for target in game.world.targets:
			for child in target.node.get_children():
				if child.has_meta("world_caption"): child.hide()
		for resident in game.world.region_layer.residents: resident.node.hide(); resident.shadow.hide()
		var bounds=WorldPresentation.bounds(id); var dimensions=Vector2i(2048,roundi(2048*bounds.size.y/bounds.size.x))
		surface.size=dimensions; surface.size_2d_override=dimensions; game.world.camera.position=bounds.get_center(); game.world.camera.zoom=Vector2.ONE*2048.0/bounds.size.x
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var image=surface.get_texture().get_image(); image.save_png("res://assets/refined-world/maps/"+id+".png"); image.save_png(output.path_join(id+"-overview.png"))
	# A closer harbor-wide view makes the separate working facilities reviewable.
	await place("coast",Vector2(42,24)); surface.size=Vector2i(2560,1440); surface.size_2d_override=surface.size; surface.transparent_bg=false
	game.world.hero.hide(); game.world.hero_shadow.hide(); game.world.lighting.freeze_for_map(); game.world.region_layer.particles.hide(); game.world.region_layer.set_process(false); game.world.camera.position=game.world.iso(Vector2(43,25))+Vector2(0,-120); game.world.camera.zoom=Vector2.ONE*.95
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(output.path_join("harbor-panorama.png"))
	var report={"passed":failures.is_empty(),"failures":failures,"frames":frames,"maps":["wood","pass","fen","coast"],"native4K":true}
	var file=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("REGIONAL REDRAW REVIEW: "+JSON.stringify(report)); game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)
