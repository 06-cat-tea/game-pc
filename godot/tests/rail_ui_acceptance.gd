extends RefCounted

func _nodes(root: Node) -> Array:
	var nodes=[]
	for child in root.get_children(): nodes.append(child); nodes.append_array(_nodes(child))
	return nodes

func _button(root: Node, text: String) -> Button:
	for node in _nodes(root):
		if node is Button and node.text==text: return node
	return null

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame
	game.new_game("warden"); game.session.state.settings.reduce_motion=true; game.refresh()
	await tree.process_frame
	var menu_button: Button
	for node in _nodes(game.main_view):
		if node is Button and node.tooltip_text=="旅人终端 · Esc": menu_button=node
	var press=InputEventMouseButton.new(); press.position=menu_button.get_global_rect().get_center(); press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true
	tree.root.push_input(press,true)
	var release=press.duplicate(); release.pressed=false; tree.root.push_input(release,true)
	await tree.process_frame
	verify.call(game.overlay=="terminal","实际鼠标点击 HUD 可打开终端")
	game.open_menu("inventory"); var ui_state=game.menus.pages.state("inventory"); ui_state.category="weapon"; ui_state.selection="gear-1"; game.replace_menu("inventory")
	game.open_menu("character"); game.back_menu()
	verify.call(game.overlay=="inventory" and ui_state.category=="weapon" and ui_state.selection=="gear-1","逐级返回保留背包分类和选中装备")
	game.back_menu(); verify.call(game.overlay=="terminal","背包返回来源终端")
	game.back_menu(); verify.call(game.overlay=="" and not game.world.blocked,"终端返回场景并解除输入阻断")
	for i in 50: game.session.add_gear("sword")
	game.open_menu("inventory"); await tree.process_frame; await tree.process_frame
	var grid_scroll=game._scrolls(game.overlay_root)[0]; grid_scroll.scroll_vertical=500
	game.open_menu("character"); await tree.process_frame; game.back_menu(); await tree.process_frame; await tree.process_frame
	verify.call(game._scrolls(game.overlay_root)[0].scroll_vertical==500,"离开再返回背包恢复网格滚动位置")
	var tab=InputEventKey.new(); tab.keycode=KEY_TAB; tab.physical_keycode=KEY_TAB; tab.pressed=true
	game._input(tab)
	var focus=tree.root.gui_get_focus_owner()
	verify.call(game.overlay=="inventory" and focus!=null and game.overlay_root.is_ancestor_of(focus),"面板中 Tab 聚焦当前界面且不打开轮盘或穿透 HUD")
	var before=game.session.state.duplicate(true)
	for kind in ["terminal","new","character","party","skills","inventory","craft","journal","map","shop","actions","training","settings","saves"]:
		game.close_menu(); game.open_menu(kind)
		await tree.process_frame
		await tree.process_frame
		var audit=RailAudit.inspect(game.overlay_root)
		verify.call(audit.passed,"功能页按钮位于画面或局部滚动区域："+kind+" "+str(audit.overflow))
	verify.call(before==game.session.state,"浏览全套界面不修改剧情、装备、资源或存档状态")
	game.open_menu("character"); var point=game.world.player
	Input.action_press("move_down"); game.world._process(0.2); Input.action_release("move_down")
	verify.call(game.world.player==point,"打开界面时阻止场景移动")
	game.close_menu(); game.refresh(); await tree.process_frame
	var hud=game.main_view.get_children().duplicate()
	Input.action_press("move_down")
	for i in 8: game.world._process(0.02)
	Input.action_release("move_down")
	verify.call(hud==game.main_view.get_children(),"移动和小地图更新不重建 HUD")
	game.menus.pages.state("map").category="region"; game.open_menu("map"); await tree.process_frame
	var map: RailMap
	for node in _nodes(game.overlay_root):
		if node is RailMap: map=node
	var building=game.db.raw.buildings[0]; var hit=InputEventMouseButton.new(); hit.pressed=true; hit.button_index=MOUSE_BUTTON_LEFT; hit.position=map.project(Vector2(building.x+building.w/2,building.y+building.d/2)); map._gui_input(hit)
	verify.call(game.menus.pages.state("map").selection==building.id,"地图点击使用真实建筑坐标选中地点")
	game.close_menu(); game.open_menu("npc","mira"); var dialogue: RailDialogue
	for node in game.overlay_root.get_children():
		if node is RailDialogue: dialogue=node
	verify.call(dialogue.choice_buttons.all(func(button): return button.disabled),"对白未读完时阻止提前选择")
	while dialogue.page_index<dialogue.pages.size()-1: dialogue.advance(); dialogue.advance()
	dialogue.advance(); verify.call(dialogue.caption.visible_characters==dialogue.caption.text.length(),"点击可补全当前对白")
	game.session.state.affinity.mira.value=maxi(20,int(game.session.state.affinity.mira.value))
	game.open_menu("topic","mira|past")
	for node in game.overlay_root.get_children():
		if node is RailDialogue: dialogue=node
	while dialogue.page_index<dialogue.pages.size()-1: dialogue.advance(); dialogue.advance()
	dialogue.advance(); var affinity=game.session.state.affinity.mira.value
	dialogue.choose(0); dialogue.choose(0)
	verify.call(game.overlay=="message" and game.session.state.affinity.mira.value==affinity+2,"连点对话选项只结算一次")
	game.back_menu(); verify.call(game.overlay=="npc" and game.menu_subject=="mira","对白回复返回原 NPC")
	game.menus._confirm("测试确认","取消应回到原交谈页面。",func(): pass); game.back_menu()
	verify.call(game.overlay=="npc","取消确认框恢复来源页面")
	game.session.state.gear={}; ui_state.category="weapon"; game.replace_menu("inventory")
	await tree.process_frame
	verify.call(_nodes(game.overlay_root).any(func(node): return node is Label and node.text=="这个分类还没有物品"),"空背包分类显示空状态")
	ui_state.category="items"; ui_state.selection="item:potion"; game.session.state.items.potion=0; game.replace_menu("inventory")
	verify.call(_button(game.overlay_root,"使用道具").disabled,"数量为零的道具不可使用")
	game.close_menu(); game.session.enter_training("warden",["mira","eira","ridge-scout"],6); game.session.start_battle("town-trial-2",417); game.mode="battle"; game.focused=false
	var boss=game.session.engine.unit("enemy-0"); boss.phase=2; boss.intent={"kind":"summon","target":"hero","label":"召唤","power":1.0}
	for i in 3: game.session.engine._enemy_action(boss)
	game.session.engine._begin_round(); game.session.engine._prepare_turn()
	game.refresh(); await tree.process_frame
	verify.call(game.session.engine.battle.units.filter(func(unit): return unit.team=="enemy" and unit.hp>0).size()==6,"战斗夹具包含六名敌人")
	verify.call(RailAudit.inspect(game.main_view).passed,"四人六敌战斗按钮无越界且技能与确认操作不重叠")
	var hero=game.session.engine.unit("hero"); var first_position=game.battle_view.fighter_position(hero); var old_slot=hero.slot; hero.slot=3 if old_slot!=3 else 0
	verify.call(game.battle_view.fighter_position(hero)!=first_position,"战场位置跟随实际前后排 slot 变化")
	hero.slot=old_slot
	var positions=[]
	for formation in ["balanced","assault","watch"]:
		game.session.engine.battle.formation=formation; positions.append(game.battle_view.fighter_position(hero))
	verify.call(positions[0]!=positions[1] and positions[1]!=positions[2],"均衡、突击、守望分别使用对应阵型布局")
	game.session.engine.battle.formation="balanced"
	var friends=game.session.engine.battle.units.filter(func(unit): return unit.team=="ally")
	for front in friends.filter(func(unit): return unit.slot<2):
		for back in friends.filter(func(unit): return unit.slot>=2):
			verify.call(game.battle_view.fighter_position(front).x>game.battle_view.fighter_position(back).x,"前排位于更靠近敌人的一侧")
	while game.session.engine.current().team!="ally": game.session.engine.submit(game.session.engine.ai_command())
	var actor=game.session.engine.current(); actor.mp=0; game.refresh(); await tree.process_frame
	var skills=_nodes(game.main_view).filter(func(node): return node is Button and node.has_meta("avoid_overlap") and "MP" in node.text)
	verify.call(not skills.is_empty() and skills.all(func(button): return button.disabled),"法力不足的技能按钮全部禁用")
	var fallen=game.session.engine.unit("mira"); fallen.hp=0; game.choose_action("revive"); game.refresh()
	verify.call(game.selected_target=="mira","苏生道具默认选择倒地队员")
	game.session.exit_training(); game.queue_free(); await tree.process_frame
