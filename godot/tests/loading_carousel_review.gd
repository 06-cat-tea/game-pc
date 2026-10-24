extends SceneTree

var surface: SubViewport
var game
var output="res://../artifacts/godot/loading-carousel-review"
var frames=[]
var failures=[]

func _initialize(): call_deferred("run")

func capture(name: String):
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var screen=game.loading; var audit=RailAudit.inspect(screen.panel)
	if screen.progress_bar.size.y>7: failures.append(name+": progress bar too tall")
	if not audit.passed: failures.append(name+": "+str(audit.overflow))
	for label in [screen.caption,screen.picture_label,screen.stage_label,screen.tip_category,screen.tip_label]:
		if not Rect2(-1,-1,1922,1082).encloses(label.get_global_rect()): failures.append(name+": text out of viewport "+label.text)
	surface.get_texture().get_image().save_png(output.path_join(name+".png"))
	frames.append({"name":name,"size":str(surface.size),"image":screen.image_key,"tip":screen.tip_id,"audit":audit.passed})

func run():
	create_timer(120).timeout.connect(func(): push_error("Loading review timed out"); quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	surface=SubViewport.new(); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true
	await process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	for size_value in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(3840,2160)]:
		surface.size=size_value
		for key in ["departure","town","city","battle"]:
			game.loading.begin(key,"正在载入场景素材"); await capture(key+"-"+str(size_value.x)+"x"+str(size_value.y)); game.loading.complete()
	game.session.state.settings.reduce_motion=false; game.loading.begin("wood","正在准备旅程")
	game.loading._process(8.1)
	for i in 90: await process_frame; game.loading._process(.01)
	await create_timer(.65).timeout; await capture("rotated-3840x2160")
	game.loading.fail("网络连接暂时中断，请重试。"); await capture("error-3840x2160"); game.loading.complete()
	var report={"passed":failures.is_empty(),"frames":frames,"failures":failures}
	var file=FileAccess.open(output.path_join("review.json"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("LOADING REVIEW: "+JSON.stringify({"passed":report.passed,"frames":frames.size(),"failures":failures})); quit(0 if report.passed else 1)
