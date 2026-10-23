extends RefCounted

func nodes(root: Node) -> Array:
	var result=[]
	for child in root.get_children(): result.append(child); result.append_array(nodes(child))
	return result

func contrast(a: Color,b: Color) -> float:
	var x=a.srgb_to_linear(); var y=b.srgb_to_linear()
	var l1=x.r*.2126+x.g*.7152+x.b*.0722; var l2=y.r*.2126+y.g*.7152+y.b*.0722
	return (maxf(l1,l2)+.05)/(minf(l1,l2)+.05)

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true; game.refresh(); await tree.process_frame
	verify.call(contrast(UIkit.INK,UIkit.PAPER)>10,"浅色正文与米白底对比度超过 10:1")
	verify.call(contrast(UIkit.MUTED,UIkit.PAPER)>4.5,"浅色说明文字对比度达到 4.5:1")
	verify.call(contrast(UIkit.GOLD,UIkit.PAPER)>3,"强调标题与米白底对比度达到 3:1")
	var button=UIkit.action(game.main_view,"主题测试",Vector2.ZERO,Vector2(200,60),func(): pass)
	UIkit.selected(button,true)
	verify.call(button.get_meta("selected") and button.get_theme_stylebox("normal").border_color==UIkit.GOLD,"选中项采用金色定位标")
	verify.call(button.get_theme_stylebox("focus").border_color==UIkit.GOLD,"键盘焦点具有独立边框")
	verify.call(button.get_theme_color("font_disabled_color")!=UIkit.INK,"禁用文字与正常状态可区分")
	button.queue_free()
	var ground: WorldGround
	for node in nodes(game.world.map_root):
		if node is WorldGround: ground=node
	verify.call(ground.layers.size()==3,"地表具有草地、土壤过渡与石路三层")
	for layer in ground.layers:
		verify.call(layer.get_used_cells().size()==3072,"分层地表完整覆盖 64×48："+layer.name)
		verify.call(not layer.collision_enabled and not layer.navigation_enabled,"表现层不替换原通行规则："+layer.name)
		for cell in [Vector2i(0,0),Vector2i(30,27),Vector2i(63,47)]:
			verify.call((layer.map_to_local(cell)+layer.position).distance_to(game.world.iso(Vector2(cell))+Vector2(0,24))<.01,"地表与原等距坐标对齐："+str(cell))
	verify.call(not WorldPresentation.terrain_cells.is_empty(),"地表单元数据可重复复用")
	var safe=true
	for decor in WorldPresentation.config().decor:
		var p=Vector2(decor.point[0],decor.point[1])
		if game.db.raw.terrain[int(p.y)][int(p.x)]=="road": safe=false
		for b in game.db.raw.buildings:
			if p.distance_to(game.world.entry(b))<(2.7 if decor.large else 1.65): safe=false
		for target in game.world.targets:
			if target.kind=="npc" and p.distance_to(target.point)<(2.7 if decor.large else 1.65): safe=false
		verify.call(ResourceLoader.exists(decor.asset),"装饰资源已完整打包："+decor.asset.get_file())
	verify.call(safe,"场景装饰避开道路、建筑入口和 NPC")
	verify.call(game.world._can_walk(Vector2(30,27)),"原生 v1 存档出生落点仍可通行")
	var s=game.session.state.duplicate(true); s.location={"scene":"town","x":30.0,"y":27.0}
	game.session.state=s; game.refresh(); verify.call(game.world.player==Vector2(30,27),"旧档坐标可原样恢复")
	var scenes=["town"]; scenes.append_array(game.db.raw.scenes.keys())
	for id in scenes:
		game.session.state.location={"scene":id,"x":30.0 if id=="town" else 8.5,"y":27.0 if id=="town" else 8.5}; game.refresh(); await tree.process_frame
		verify.call(game.world.scene_id==id and game.world._can_walk(game.world.player),"场景切换保留安全落点："+id)
		var texture=WorldPresentation.overview(id)
		verify.call(texture!=null and texture.get_width()>=1400,"已烘焙实际彩色场景底图："+id)
		verify.call(texture==WorldPresentation.overview(id),"导航底图读取复用缓存："+id)
		var map=RailMap.new(); map.scene_override=id; map.size=Vector2(1150,650); game.main_view.add_child(map); map.setup(game)
		var p=Vector2(30,27) if id=="town" else Vector2(4,4); var bounds=WorldPresentation.bounds(id); var expected=map.map_rect().position+(game.world.iso(p)-bounds.position)/bounds.size*map.map_rect().size
		verify.call(map.project(p).distance_to(expected)<.01,"地点地图与场景共享投影："+id)
		if id!="town" and not game.db.raw.scenes[id].props.is_empty():
			var prop=game.db.raw.scenes[id].props[0]; var choice=[""]; map.picked.connect(func(value): choice[0]=value)
			var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=map.project(Vector2(prop.x,prop.y)); map._gui_input(click)
			verify.call(choice[0]==prop.id,"内室或路线标记鼠标命中："+id)
		map.queue_free(); await tree.process_frame
	game.session.state.location={"scene":"town","x":30.0,"y":27.0}; game.refresh(); await tree.process_frame
	var count=nodes(game.world).size(); var texture_count=WorldPresentation.textures.size(); var data=WorldPresentation.terrain_cells
	for i in 4:
		game.session.visit("room-chapel"); game.refresh(); await tree.process_frame
		game.session.visit("town"); game.refresh(); await tree.process_frame
	verify.call(nodes(game.world).size()==count,"反复进入场景没有累计节点")
	verify.call(WorldPresentation.textures.size()==texture_count and data==WorldPresentation.terrain_cells,"反复切换复用纹理和地表缓存")
	var hud=game.main_view.get_children().duplicate(); var cached=WorldPresentation.textures.size()
	Input.action_press("move_down")
	for i in 120: game.world._process(1.0/60)
	Input.action_release("move_down")
	verify.call(game.main_view.get_children()==hud and WorldPresentation.textures.size()==cached,"连续移动只更新人物与标记")
	var labels=nodes(game.world.map_root).filter(func(n): return n is Label and n.has_meta("world_caption"))
	verify.call(labels.any(func(n): return not n.visible),"远处普通名称默认收起")
	game.session.visit("room-chapel"); game.refresh(); game.menus.pages.state("map").category="current"; game.open_menu("map"); await tree.process_frame
	game.close_menu(); game.session.visit("town"); game.refresh(); game.open_menu("map"); await tree.process_frame
	verify.call(nodes(game.overlay_root).any(func(n): return n is Button and n.text=="进入内室"),"从内室地图返回城镇时清理失效选择并恢复地点详情")
	game.queue_free(); await tree.process_frame
