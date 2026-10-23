extends SceneTree

func _initialize(): call_deferred("run")

func key(code: int, down: bool):
	var event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=down; Input.parse_input_event(event)

func run():
	create_timer(120).timeout.connect(func(): push_error("Motion capture timed out"); quit(2))
	var directory=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--motion-dir="): directory=arg.trim_prefix("--motion-dir=")
	if directory=="": quit(2); return
	DirAccess.make_dir_recursive_absolute(directory)
	var viewport=SubViewport.new(); viewport.size=Vector2i(960,540); viewport.size_2d_override=Vector2i(1920,1080); viewport.size_2d_override_stretch=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate(); viewport.add_child(game); game.capture_mode=true; game.capture_args.path=""; game.set_process(false)
	game.new_game("warden"); game.world.set_process(false); game.world.set_process_unhandled_input(false)
	var caption=UIkit.text(game.ui,"",Vector2(550,30),Vector2(820,70),32,UIkit.GOLD)
	caption.add_theme_stylebox_override("normal",UIkit.style(UIkit.PAPER))
	var keys=[[KEY_W],[KEY_W,KEY_D],[KEY_D],[KEY_S,KEY_D],[KEY_S],[KEY_S,KEY_A],[KEY_A],[KEY_W,KEY_A]]
	var labels=["W / ↑","W+D / ↗","D / →","S+D / ↘","S / ↓","S+A / ↙","A / ←","W+A / ↖"]
	var frames=[]; var failures=[]; var index=0
	for scene in ["room-city-academy-3","town","wood"]:
		game.session.state.location={"scene":scene,"x":30 if scene=="town" else 5,"y":27 if scene=="town" else 5}; game.world.scene_id=""; game.refresh(); game.world.blocked=false
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var origin=game.world.player
		if scene=="wood":
			var found=false
			for y in range(5,game.db.regions[scene].rows-5):
				if found: break
				for x in range(5,game.db.regions[scene].columns-5):
					var open=true
					for direction in 8:
						var step=game.world.screen_step(Vector2.from_angle(-PI/2+direction*PI/4),.08)*6
						for sample in 60:
							if not game.world._can_walk(Vector2(x,y)+step*(sample+1)/60): open=false
					if open: origin=Vector2(x,y); found=true; break
		for dir in 8:
			game.world.player=origin; game.world.stop(); game.world.blocked=false
			caption.text=game.db.location_title(scene)+"  ·  "+labels[dir]+"  ·  "+game.db.movement.order[dir].to_upper()
			for code in keys[dir]: key(code,true)
			await process_frame
			for frame in 6:
				var before=game.world.player; game.world._process(.08)
				var motion=game.world.projection()*(game.world.player-before); var expected=Vector2.from_angle(-PI/2+dir*PI/4)
				if motion.length()<.01 or motion.normalized().distance_to(expected)>.01 or game.world.direction!=dir: failures.append(scene+"/"+str(dir))
				await RenderingServer.frame_post_draw
				var file=directory.path_join("motion-%04d.png" % index); viewport.get_texture().get_image().save_png(file)
				frames.append({"file":file,"scene":scene,"direction":game.db.movement.order[dir],"screenMotion":[motion.x,motion.y],"frame":frame}); index+=1
			for code in keys[dir]: key(code,false)
			await process_frame; game.world._process(.01)
	var output=FileAccess.open(directory.path_join("motion-recording.json"),FileAccess.WRITE); output.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"fps":10,"frames":frames},"  ")); output.close()
	print("MOTION RECORDING: "+JSON.stringify({"passed":failures.is_empty(),"frames":frames.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
