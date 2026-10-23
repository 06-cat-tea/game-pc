extends RefCounted

var completed=false
var timings=[]
var surface: SubViewport
var game

func key(code: int):
	var event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; surface.push_input(event,true)
	event=event.duplicate(); event.pressed=false; surface.push_input(event,true)

func click(point: Vector2):
	var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.pressed=true; surface.push_input(event,true)
	event=event.duplicate(); event.pressed=false; surface.push_input(event,true)

func run(tree: SceneTree, verify: Callable):
	surface=SubViewport.new(); surface.size=Vector2i(1280,720); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; tree.root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true; game.capture_args.path=""; game.set_process(false); game.world.set_process(false)
	await tree.process_frame
	game.new_game("warden"); game.store.base_path="user://tests/dialogue-return"
	var cache=game.db.raw.scenes["room-guildhall"].props.filter(func(prop): return prop.action=="cache")[0]
	for method in ["enter","space","caption","return-button","escape","header-button"]:
		game.session.visit("room-guildhall"); game.world.scene_id=""; game.refresh(); await tree.process_frame
		game.world.player=Vector2(cache.x,cache.y)+Vector2(-.5,0); game.focused=true
		var begin=Time.get_ticks_usec(); key(KEY_F); await tree.process_frame
		verify.call(game.overlay=="message","真实F打开旅行储物柜提示："+method)
		if game.overlay!="message": continue
		var dialogue=game.overlay_root.get_child(0)
		verify.call(dialogue is RailDialogue and dialogue.caption.text.contains("补给") if method=="enter" else dialogue is RailDialogue,"储物柜提示正常呈现："+method)
		if method in ["enter","space"]:
			key(KEY_ENTER if method=="enter" else KEY_SPACE); key(KEY_ENTER if method=="enter" else KEY_SPACE)
		elif method=="caption": click(Vector2(440,930)); click(Vector2(440,930))
		elif method=="return-button":
			click(dialogue.advance_button.get_global_rect().get_center()); click(dialogue.advance_button.get_global_rect().get_center())
		elif method=="header-button": click(Vector2(1740,73))
		else: key(KEY_ESCAPE)
		await tree.process_frame
		verify.call(game.overlay=="" and not game.world.blocked,"真实输入可以退出提示并恢复移动："+method)
		timings.append({"method":method,"elapsedMs":(Time.get_ticks_usec()-begin)/1000.0,"overlay":game.overlay})
		game.close_menu()
	var before=game.session.state.duplicate(true)
	var begin=Time.get_ticks_usec(); var saved=game.store.save(1)
	verify.call(saved=="","物件交互后的原生存档正常写入")
	timings.append({"method":"disk-save","elapsedMs":(Time.get_ticks_usec()-begin)/1000.0})
	begin=Time.get_ticks_usec(); game.navigate("town")
	timings.append({"method":"return-town","elapsedMs":(Time.get_ticks_usec()-begin)/1000.0})
	verify.call(game.session.state.location.scene=="town" and game.session.state.materials==before.materials,"返回晨星镇保留储物柜物资")
	surface.queue_free(); await tree.process_frame; completed=true
