extends RefCounted

func nodes(root: Node) -> Array:
	var result=[]
	for child in root.get_children(): result.append(child); result.append_array(nodes(child))
	return result

func button(root: Node, text: String) -> Button:
	for node in nodes(root):
		if node is Button and node.text==text: return node
	return null

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame
	game.new_game("warden"); await tree.process_frame
	game.world.set_process(false); game.focused=true
	for scene in ["town","room-chapel"]:
		game.session.state.location.scene=scene; game.world.scene_id=""; game.refresh()
		var reference=0.0
		for i in 8:
			var expected=Vector2.from_angle(-PI/2+i*PI/4)
			var step=game.world.screen_step(expected,0.1)
			var projected=game.world.projection()*step
			verify.call(projected.normalized().distance_to(expected)<0.0001,"屏幕八方向角度准确："+scene+"/"+str(i))
			if i==0: reference=projected.length()
			verify.call(absf(projected.length()-reference)<0.001,"八方向步速一致："+scene+"/"+str(i))
			var running=game.world.projection()*game.world.screen_step(expected,0.1,true)
			verify.call(absf(running.length()/reference-1.8)<0.001,"跑步保持 1.8 倍："+scene+"/"+str(i))
			game.world._update_actor(step,0.1)
			verify.call(game.world.direction==i,"八向朝向跟随实际投影位移")
			game.world._update_actor(Vector2.ZERO,0.1)
			verify.call(game.world.direction==i and game.world.move_clock==0,"停止保留朝向并使用站立帧")
		game.world.blocked=false
		for i in 8:
			game.world.player=Vector2(30,27) if scene=="town" else Vector2(8,8)
			var start=game.world.player
			var expected=Vector2.from_angle(-PI/2+i*PI/4)
			for axis in [["move_left",maxf(0,-expected.x)],["move_right",maxf(0,expected.x)],["move_up",maxf(0,-expected.y)],["move_down",maxf(0,expected.y)]]:
				if axis[1]>0.1: Input.action_press(axis[0])
			game.world._process(0.05)
			for action in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
			var actual=game.world.projection()*(game.world.player-start)
			verify.call(actual.normalized().distance_to(expected)<0.0001 and absf(actual.length()-reference/2)<0.001,"实际键盘输入八向等速："+scene+"/"+str(i))
		var destination=Vector2(30.13,27.17) if scene=="town" else Vector2(8.53,8.62)
		game.world.player=Vector2(30,27) if scene=="town" else Vector2(8,8)
		game.world.navigate(destination)
		for tick in 120: game.world._process(0.1)
		verify.call(game.world.player.distance_to(destination)<0.011 and game.world.walking_path.is_empty(),"寻路准确停在非网格终点，无越过和来回摆动："+scene)
		game.world.stop()
		verify.call(game.world.hero.texture==game.world.texture(game.db.movement.directions[game.db.movement.order[game.world.direction]].idle),"停止立即恢复对应方向站立帧")
	game.world.player=Vector2(0.36,8)
	game.world._move_step(Vector2(-.6,1))
	var slide=game.world.projection()*(game.world.player-Vector2(.36,8))
	verify.call(game.world._can_walk(game.world.player) and slide.length()>0 and slide.x<=.001 and slide.y>=-.001,"墙边按屏幕分量滑动且不反向、不穿墙")
	game.world.walking_path=[Vector2(-1,game.world.player.y)]
	for tick in 12: game.world._process(0.1)
	verify.call(game.world.walking_path.is_empty(),"无法推进的寻路清理状态，不持续卡墙行走")
	for id in ["hero","mira","toren","sylvi","ridge-scout","eira","alchemist"]:
		for mood in ["neutral","smile","serious","avatar"]:
			verify.call("/static-v2/" in game.db.art("portraits",id,mood),"主队完整新立绘及头像可读取："+id+"/"+mood)
	var saved=game.db.raw.art.portraits.eira.duplicate(true)
	game.db.raw.art.portraits.eira.smile="res://missing-expression.webp"
	verify.call(game.db.art("portraits","eira","smile")==saved.neutral,"表情缺失回退常态")
	game.db.raw.art.portraits.eira.neutral="res://missing-neutral.webp"
	verify.call(game.db.art("portraits","eira","smile")==saved.fallback,"常态缺失回退职业素材")
	game.db.raw.art.portraits.eira=saved
	game.session.state.location={"scene":"town","x":30.0,"y":27.0}; game.world.scene_id=""; game.refresh()
	game.open_menu("inventory"); await tree.process_frame
	var background=game.overlay_root.get_child(0)
	var category=button(game.overlay_root,"消耗品"); category.grab_focus(); category.pressed.emit()
	verify.call(game.overlay_root.get_child(0)==background and game.overlay_root.modulate.a==1,"分类切换保留背景且整页始终不透明")
	verify.call(game.get_viewport().gui_get_focus_owner()==category,"分类切换保留鼠标选项的键盘焦点")
	category=button(game.overlay_root,"全部物品"); category.pressed.emit()
	verify.call(game.menus.pages.state("inventory").category=="all","复用按钮的回调使用最新分类")
	for i in 3:
		button(game.overlay_root,"消耗品").pressed.emit(); button(game.overlay_root,"全部物品").pressed.emit()
		await tree.process_frame
		verify.call(game.overlay_root.modulate.a==1 and game.overlay_root.get_child(0)==background,"连续点选没有背景消失帧")
	game.open_menu("settings"); game.refresh_menu(); await tree.process_frame
	var slider=nodes(game.overlay_root).filter(func(n): return n is HSlider)[0]
	slider.value=0.35
	verify.call(is_equal_approx(game.session.state.settings.master_volume,0.35),"刷新后设置滑块和标签回调有效")
	game.open_menu("npc","mira"); var dialogue=game.overlay_root.get_child(0); var portrait=dialogue.portrait_view; background=dialogue.get_child(0)
	game.session.state.affinity.mira.value=30
	game.open_menu("topic","mira|past")
	verify.call(game.overlay_root.get_child(0)==dialogue and dialogue.portrait_view==portrait and dialogue.get_child(0)==background,"话题切换保留对话背景、立绘和整个对话节点")
	while dialogue.page_index<dialogue.pages.size()-1: dialogue.advance(); dialogue.advance()
	dialogue.advance(); var affinity=game.session.state.affinity.mira.value
	dialogue.choose(0); dialogue.choose(0)
	verify.call(game.overlay=="message" and game.session.state.affinity.mira.value==affinity+2 and game.overlay_root.get_child(0)==dialogue and dialogue.portrait_view==portrait,"回复局部更新且连续点击只结算一次")
	game.close_menu(); game.session.enter_training("warden",["mira","eira","ridge-scout"],6); game.session.start_battle("town-trial-2",417); game.mode="battle"; game.focused=false; game.refresh()
	while game.session.engine.current().team!="ally": game.session.engine.submit(game.session.engine.ai_command())
	game.refresh(); background=game.main_view.get_child(0)
	var actor=game.session.engine.current()
	for skill in actor.skills:
		game.choose_action("ability",skill)
		verify.call(game.main_view.get_child(0)==background,"选择战斗技能保留背景与战场节点")
	game.session.exit_training(); game.queue_free(); await tree.process_frame
