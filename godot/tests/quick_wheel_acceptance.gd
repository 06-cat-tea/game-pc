extends RefCounted

func key(viewport: Viewport, code: int, pressed: bool, echo: bool = false):
	var event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=pressed; event.echo=echo
	viewport.push_input(event,true)

func motion(viewport: Viewport, wheel: QuickWheel, point: Vector2):
	var event=InputEventMouseMotion.new(); event.position=wheel.get_global_transform_with_canvas()*point
	viewport.push_input(event,true)

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame
	game.new_game("warden"); game.session.state.settings.reduce_motion=true; game.refresh()
	await tree.process_frame
	var viewport=game.get_viewport()
	var expected=["inventory","journal","party","skills","craft","map","rest","settings"]
	for i in 8:
		key(viewport,KEY_TAB,true)
		var wheel: QuickWheel=game.quick_wheel
		verify.call(game.overlay=="wheel" and game.wheel_open and wheel!=null,"Tab 打开轮盘："+expected[i])
		verify.call(wheel.selected_index==-1,"打开后没有默认选中项："+expected[i])
		var echo_wheel=wheel
		key(viewport,KEY_TAB,true,true)
		verify.call(game.quick_wheel==echo_wheel,"长按重复事件不重建轮盘")
		motion(viewport,wheel,wheel.center()+Vector2.from_angle(deg_to_rad(-90+i*45))*200)
		verify.call(wheel.selected_index==i and wheel.caption.text==QuickWheel.ENTRIES[i].name,"鼠标八方向高亮正确："+expected[i])
		var supplies=game.session.state.supplies
		key(viewport,KEY_TAB,false)
		while game.loading.busy: await tree.process_frame
		verify.call(not game.wheel_open and game.overlay==("" if i==6 else expected[i]),"松开执行高亮项目："+expected[i])
		verify.call(game.session.state.supplies==supplies-(1 if i==6 else 0),"只在休息选项消耗一次补给")
		key(viewport,KEY_TAB,false)
		verify.call(game.session.state.supplies==supplies-(1 if i==6 else 0),"重复松开不重复结算")
		game.close_menu()
	key(viewport,KEY_TAB,true); key(viewport,KEY_TAB,false)
	verify.call(game.overlay=="" and not game.wheel_open,"打开后立即松开取消，不使用打开前鼠标位置")
	var hud_button=game.main_view.find_children("*","Button",true,false)[0]
	hud_button.grab_focus(); key(viewport,KEY_TAB,true)
	key(viewport,KEY_ENTER,true); key(viewport,KEY_ENTER,false)
	key(viewport,KEY_SPACE,true); key(viewport,KEY_SPACE,false)
	verify.call(game.overlay=="wheel","轮盘阻止 Enter 和空格激活后方已聚焦 HUD")
	await tree.process_frame
	key(viewport,KEY_TAB,true,true)
	verify.call(viewport.gui_get_focus_owner()==null,"长按 Tab 重复事件不将焦点转移到后方 HUD")
	key(viewport,KEY_TAB,false)
	key(viewport,KEY_TAB,true)
	var wheel: QuickWheel=game.quick_wheel
	for i in 8:
		var boundary=deg_to_rad(-67.5+i*45)
		motion(viewport,wheel,wheel.center()+Vector2.from_angle(boundary-0.001)*200)
		verify.call(wheel.selected_index==i,"扇区边界前属于当前方向："+str(i))
		motion(viewport,wheel,wheel.center()+Vector2.from_angle(boundary+0.001)*200)
		verify.call(wheel.selected_index==(i+1)%8,"扇区边界后属于下一方向："+str(i))
	motion(viewport,wheel,wheel.center()+Vector2(84.9,0))
	verify.call(wheel.selected_index==-1 and wheel.caption.text=="移动鼠标选择","中央死区清除高亮和功能名")
	key(viewport,KEY_TAB,false)
	verify.call(game.overlay=="","中央松开取消")
	key(viewport,KEY_TAB,true); wheel=game.quick_wheel
	motion(viewport,wheel,wheel.center()+Vector2(200,0))
	key(viewport,KEY_ESCAPE,true); key(viewport,KEY_TAB,false); key(viewport,KEY_ESCAPE,false)
	verify.call(game.overlay=="" and not game.wheel_open and not game.world.blocked,"Esc 取消后 Tab 松开不执行，场景恢复")
	key(viewport,KEY_TAB,true); wheel=game.quick_wheel
	motion(viewport,wheel,wheel.center()+Vector2(-200,0))
	var supplies=game.session.state.supplies
	game._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	key(viewport,KEY_TAB,false)
	verify.call(game.overlay=="" and not game.wheel_open and game.world.blocked and game.session.state.supplies==supplies,"失焦取消选中休息且持续阻断场景")
	key(viewport,KEY_TAB,true)
	verify.call(game.overlay=="","窗口失焦时不能打开轮盘")
	game._notification(Control.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	key(viewport,KEY_TAB,false)
	verify.call(not game.world.blocked,"重新聚焦恢复探索输入")
	for i in 5:
		key(viewport,KEY_TAB,true); key(viewport,KEY_TAB,false)
	verify.call(game.overlay=="" and not game.wheel_open,"连续快速开关不残留轮盘状态")
	key(viewport,KEY_TAB,true); wheel=game.quick_wheel
	var point=game.world.player
	Input.action_press("move_down"); game.world._process(0.1); Input.action_release("move_down")
	verify.call(game.world.player==point,"轮盘期间阻止移动")
	var click=InputEventMouseButton.new(); click.pressed=true; click.button_index=MOUSE_BUTTON_LEFT; click.position=Vector2(1810,80)
	viewport.push_input(click,true); click=click.duplicate(); click.pressed=false; viewport.push_input(click,true)
	verify.call(game.overlay=="wheel" and game.world.walking_path.is_empty(),"鼠标点击不提交轮盘或穿透到 HUD 与场景")
	key(viewport,KEY_TAB,false)
	Input.action_press("move_down"); game.world._process(0.1); Input.action_release("move_down")
	verify.call(game.world.player!=point,"取消轮盘后可以继续移动")
	game.open_menu("inventory"); await tree.process_frame
	key(viewport,KEY_TAB,true); key(viewport,KEY_TAB,false)
	var focus=viewport.gui_get_focus_owner()
	verify.call(game.overlay=="inventory" and focus!=null and game.overlay_root.is_ancestor_of(focus),"面板内 Tab 仍然切换焦点")
	game.close_menu()
	game.open_menu("wheel"); wheel=game.quick_wheel
	motion(viewport,wheel,wheel.center()+Vector2(0,-200))
	verify.call(wheel.take_selection()==0 and wheel.take_selection()==-1,"轮盘提交接口只返回一次结果")
	game.close_menu(); game.queue_free(); await tree.process_frame
