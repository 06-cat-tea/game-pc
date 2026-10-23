extends RefCounted

var surface: SubViewport
var game

func key(code: int):
	var event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; surface.push_input(event,true)
	event=event.duplicate(); event.pressed=false; surface.push_input(event,true)

func click(node: Control):
	var event=InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.position=node.get_global_rect().get_center(); event.pressed=true; surface.push_input(event,true)
	event=event.duplicate(); event.pressed=false; surface.push_input(event,true)

func nodes(root: Node) -> Array:
	var result=[]
	for child in root.get_children(): result.append(child); result.append_array(nodes(child))
	return result

func button(text: String) -> Button:
	for node in nodes(game.overlay_root):
		if node is Button and node.text.contains(text): return node
	return null

func run(tree: SceneTree, check: Callable):
	surface=SubViewport.new(); surface.size=Vector2i(1280,720); surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; tree.root.add_child(surface)
	game=load("res://scenes/main.tscn").instantiate(); surface.add_child(game); game.capture_mode=true; game.capture_args.path=""; game.set_process(false); game.world.set_process(false)
	await tree.process_frame; game.new_game("warden"); game.focused=true
	game.navigate("room-guildhall"); await tree.process_frame
	var prop=game.db.raw.scenes["room-guildhall"].props.filter(func(p): return p.id=="noticeboard")[0]
	game.world.player=Vector2(prop.x,prop.y); key(KEY_F); await tree.process_frame
	check.call(game.overlay=="commission-board","真实 F 通过物理公告板打开专用委托界面")
	var row=button("边境新人的名册"); check.call(row!=null,"未发现入口时仍能接取独立的公会名册")
	if row==null: surface.queue_free(); return
	click(row); await tree.process_frame
	var identity=row.get_instance_id(); click(button("接取委托")); await tree.process_frame; await tree.process_frame
	check.call(game.session.tasks.accepted("first") and button("边境新人的名册").get_instance_id()==identity,"真实鼠标接取，保留原任务节点与有效选择")
	game.session.state.materials.herb=3
	row=button("边境药草清单"); click(row); await tree.process_frame
	identity=row.get_instance_id(); click(button("接取委托")); await tree.process_frame; await tree.process_frame
	check.call(game.session.tasks.status("service:guildhall")=="ready" and button("边境药草清单").get_instance_id()==identity,"可交付排序移动时仍保留该任务的同一个节点")
	var gold=game.session.state.gold; var submit=button("交付并领取奖励"); check.call(submit!=null,"可交付详情提供明确领奖按钮")
	if submit!=null: click(submit)
	await tree.process_frame; await tree.process_frame
	check.call(game.session.state.gold==gold+18 and game.session.state.materials.herb==0,"真实交付按一次扣料与发奖")
	key(KEY_ESCAPE); await tree.process_frame; key(KEY_J); await tree.process_frame
	check.call(game.overlay=="journal" and button("已完成（1）")!=null,"真实 J 打开日志，完成任务默认收纳")
	var archive=button("已完成（1）")
	if archive!=null: click(archive)
	await tree.process_frame; await tree.process_frame
	row=button("边境药草清单")
	check.call(row!=null,"鼠标可展开完成记录")
	if row!=null: click(row)
	await tree.process_frame
	check.call(button("定位目标")==null and button("交付并领取奖励")==null,"完成记录保留说明且移除所有待办按钮")
	click(button("采集")); await tree.process_frame; await tree.process_frame
	check.call(button("边境药草清单")!=null and nodes(game.overlay_root).filter(func(n): return n is Button and n.get_meta("selected",false)).size()==2,"分类筛选保留一个分类选中与一个任务选中")
	key(KEY_ESCAPE); await tree.process_frame
	check.call(game.overlay=="" and not game.world.blocked,"Esc 关闭委托日志并恢复场景输入")
	game.navigate("pass"); game.session.state.chapter_complete=true; game.session.state.story.stage=3; game.open_menu("npc","toren"); await tree.process_frame
	var main=button("核对星钟线索")
	check.call(main!=null,"托伦提供独立主线交谈入口")
	# Dialogue options are only active after the text is displayed.
	for child in game.overlay_root.get_children():
		if child is RailDialogue:
			while child.page_index<child.pages.size()-1: child.advance(); child.advance()
			child.advance()
	if main!=null:
		(main.get_parent().get_parent() as ScrollContainer).ensure_control_visible(main)
		await tree.process_frame; click(main)
	await tree.process_frame
	check.call(game.session.state.story.stage==4 and not game.session.tasks.accepted("quest:caravan"),"主线对话推进事实，不自动接取护送支线")
	surface.queue_free(); await tree.process_frame
	tree.results.append("委托真实输入：F 公告板、鼠标接取与交付、同节点排序、J 日志、完成收纳与分类单选、Esc 恢复、主线与支线解耦")
