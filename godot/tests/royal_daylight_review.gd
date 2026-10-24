extends SceneTree

var surface: SubViewport
var game
var output="res://../artifacts/godot/royal-daylight-review"
var frames=[]
var failures=[]

func _initialize(): call_deferred("run")
func shot(label: String):
	game.world.lighting._process(1.0); game.world.lighting.update_lights()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var audit=RailAudit.inspect(game.overlay_root if game.overlay!="" else game.main_view)
	if not audit.passed: failures.append(label+": "+str(audit.overflow))
	surface.get_texture().get_image().save_png(output.path_join(label+".png"))
	frames.append({"name":label,"size":str(surface.size),"audit":audit.passed})

func position_at(point: Vector2):
	game.world.player=game.world._safe_point(point); game.world._update_actor(Vector2.ZERO,0); game.world._update_camera()

func run():
	create_timer(240).timeout.connect(func(): push_error("Royal review timeout"); quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	surface=SubViewport.new(); surface.size=Vector2i(1920,1080); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true
	await process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	game.session._add_member("mira",game.db.actors.mira.job,12); game.session.state.active=["hero","mira"]; game.toast_clock=0; game.toast_label.text=""
	game.world.set_process(false)
	for id in GameContent.OUTDOORS:
		game.navigate(id); game.world.set_process(false)
		if id=="city": position_at(Vector2(48,42))
		for phase in ([0,1,2,3] if id in ["town","city"] else [1,3]):
			game.session.state.phase=phase; game.refresh(); game.world.set_process(false)
			await shot(id+"-phase-"+str(phase)+"-1920x1080")
	game.navigate("city"); game.world.set_process(false); game.session.state.phase=1; game.refresh()
	for d in game.db.regions.city.districts:
		position_at(Vector2(d.x,d.y)); await shot("district-"+d.id)
	for dimensions in [Vector2i(1280,720),Vector2i(3840,2160)]:
		surface.size=dimensions; position_at(Vector2(48,42))
		for phase in [1,3]:
			game.session.state.phase=phase; game.refresh(); game.world.set_process(false); await shot("city-phase-"+str(phase)+"-"+str(dimensions.x)+"x"+str(dimensions.y))
		game.open_menu("wheel"); await shot("wheel-neutral-"+str(dimensions.x)+"x"+str(dimensions.y))
		game.quick_wheel.select_at(game.quick_wheel.center()+Vector2(0,-200)); await shot("wheel-selected-"+str(dimensions.x)+"x"+str(dimensions.y)); game.close_menu()
	surface.size=Vector2i(1920,1080); game.session.state.phase=1; game.refresh(); game.world.set_process(false); game.open_menu("wheel"); game.quick_wheel.select_at(game.quick_wheel.center()+Vector2(0,-200)); await shot("wheel-selected-1920x1080"); game.close_menu()
	# Neutral-time maps bake from actual scene geometry; runtime light culling is frozen.
	surface.transparent_bg=true
	game.ui.hide(); game.world.hero.hide(); game.world.hero_shadow.hide(); game.world.region_layer.freeze_for_capture()
	for target in game.world.targets:
		for child in target.node.get_children():
			if child.has_meta("world_caption"): child.hide()
	var bounds=WorldPresentation.bounds("city"); surface.size=Vector2i(4096,roundi(4096*bounds.size.y/bounds.size.x)); surface.size_2d_override=surface.size
	game.world.camera.position=bounds.get_center(); game.world.camera.zoom=Vector2.ONE*4096.0/bounds.size.x
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png(output.path_join("city-overview.png"))
	surface.size=Vector2i(2048,roundi(2048*bounds.size.y/bounds.size.x)); surface.size_2d_override=surface.size; game.world.camera.zoom=Vector2.ONE*2048.0/bounds.size.x
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	surface.get_texture().get_image().save_png("res://assets/refined-world/maps/city.png")
	var file=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE); file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"frames":frames},"  ")); file.close()
	print("ROYAL DAYLIGHT REVIEW: "+JSON.stringify({"passed":failures.is_empty(),"frames":frames.size(),"failures":failures})); quit(0 if failures.is_empty() else 1)
