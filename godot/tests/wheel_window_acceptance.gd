extends SceneTree

var failures=[]
var details={}
var helper=preload("res://tests/quick_wheel_acceptance.gd").new()

func _initialize(): call_deferred("run")

func verify(passed: bool, description: String):
	if not passed: failures.append(description); push_error(description)

func run():
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.capture_mode=true
	await process_frame
	game.new_game("warden"); game.session.state.settings.reduce_motion=true; game.refresh()
	await process_frame; await process_frame
	root.grab_focus(); await create_timer(0.15).timeout
	details.focused=root.has_focus(); details.driver=DisplayServer.get_name()
	details.desktop_mouse=str(DisplayServer.mouse_get_position()); details.window_position=str(root.position)
	helper.key(root,KEY_TAB,true)
	await create_timer(0.08).timeout
	var wheel: QuickWheel=game.quick_wheel
	details.window=str(root.size); details.center=str(wheel.center()); details.mouse=str(wheel.get_local_mouse_position())
	details.stretch=str(root.get_stretch_transform()); details.screen=str(root.get_screen_transform())
	verify(wheel.get_local_mouse_position().distance_to(wheel.center())<4,"真实窗口打开轮盘后鼠标居中")
	verify(wheel.selected_index==-1,"鼠标居中不误选")
	helper.key(root,KEY_TAB,false)
	verify(game.overlay=="","真实窗口立即松开取消")
	var expected=["inventory","journal","party","skills","craft","map","rest","settings"]
	for i in 8:
		helper.key(root,KEY_TAB,true); wheel=game.quick_wheel
		var point=wheel.center()+Vector2.from_angle(deg_to_rad(-90+i*45))*200
		root.warp_mouse(wheel.get_global_transform_with_canvas()*point)
		await create_timer(0.06).timeout
		verify(wheel.get_local_mouse_position().distance_to(point)<4,"窗口缩放后系统鼠标坐标正确："+str(i))
		# Warping updates Godot's mouse position without emitting a motion event.
		# Feed that actual viewport position through the normal input route.
		var event=InputEventMouseMotion.new(); event.position=root.get_mouse_position(); root.push_input(event,true)
		verify(wheel.selected_index==i,"系统鼠标移动正确选择方向："+str(i))
		helper.key(root,KEY_TAB,false)
		verify(game.overlay==("" if i==6 else expected[i]),"真实窗口松开执行高亮项："+str(i))
		game.close_menu()
	details.passed=failures.is_empty(); details.failures=failures
	var destination=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--wheel-report="): destination=argument.trim_prefix("--wheel-report=")
	if destination!="":
		var file=FileAccess.open(destination,FileAccess.WRITE); file.store_string(JSON.stringify(details,"  ")); file.close()
	print("WINDOW WHEEL: "+JSON.stringify(details))
	quit(0 if failures.is_empty() else 1)
