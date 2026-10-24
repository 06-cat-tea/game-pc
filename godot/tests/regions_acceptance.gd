extends RefCounted

func nodes(root: Node) -> Array:
	var result=[]
	for child in root.get_children(): result.append(child); result.append_array(nodes(child))
	return result

func map_control(game) -> RailMap:
	for node in nodes(game.overlay_root):
		if node is RailMap: return node
	return null

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true; game.refresh(); await tree.process_frame
	var db=game.db; var story=game.session.state.duplicate(true); story.erase("location"); story.erase("story")
	verify.call(db.regions.size()==5 and db.regions.city.buildings.size()==52 and db.regions.city.districts.size()==9,"五地独立配置及王城九街区、52 栋建筑")
	for id in db.regions:
		var error=game.session.visit(id); game.refresh(); await tree.process_frame
		verify.call(error=="" and game.world.scene_id==id and not game.session.state.chapter_complete,"首章开始后直接前往："+id)
		var current=game.session.state.duplicate(true); current.erase("location"); current.erase("story")
		verify.call(story==current,"自由探索不修改剧情、资源、好感和招募："+id)
		verify.call(game.world._can_walk(game.world.player),"区域出生点可通行："+id)
		verify.call(game.world.grid.region.size==Vector2i(db.regions[id].columns,db.regions[id].rows),"区域寻路采用真实尺寸："+id)
		var from=game.world._walkable_cell(Vector2i(game.world.player.round()))
		for b in db.regions[id].buildings:
			var entry=Vector2(b.entry[0],b.entry[1]); var to=game.world._walkable_cell(Vector2i(entry.round()))
			verify.call(game.world._can_walk(entry) and not game.world.grid.get_id_path(from,to).is_empty(),"从出生点可到达地标："+b.id)
			verify.call(not game.world._can_walk(Vector2(b.x+b.w/2,b.y+b.d/2)),"建筑基底阻挡移动："+b.id)
		for polygon in db.regions[id].water:
			var center=Vector2.ZERO
			for p in polygon: center+=Vector2(p[0],p[1])
			center/=polygon.size()
			var bridge=db.regions[id].bridges.any(func(b): return Rect2(b.x-b.w/2,b.y-b.d/2,b.w,b.d).has_point(center))
			if not bridge: verify.call(not game.world._can_walk(center),"水域阻挡移动："+id)
		for b in db.regions[id].bridges: verify.call(game.world._can_walk(Vector2(b.x,b.y)),"桥面可以跨越水域："+id)
		if id=="city": verify.call(not game.world._can_walk(Vector2(62,30)) and game.world._can_walk(Vector2(62,42)),"王城运河阻挡且桥梁连通")
		var cached=WorldPresentation.overview(id); verify.call(cached!=null and cached==WorldPresentation.overview(id),"真实彩色地图读取缓存："+id)
		var region_layer=game.world.region_layer
		verify.call(region_layer!=null and region_layer.ground.layers.size()==3,"分层地形、水面与场景表现已接入："+id)
		region_layer._process(.2)
		verify.call(not region_layer.particles.visible and region_layer.ground.materials[2].get_shader_parameter("scene_clock")==0.0,"减少动效冻结水面并隐藏粒子："+id)
		game.session.state.settings.reduce_motion=false; region_layer._process(.3); var clock=region_layer.scene_clock
		game.world.blocked=true; region_layer._process(.3)
		verify.call(region_layer.scene_clock==clock and region_layer.particles.speed_scale==0,"打开界面冻结区域动效："+id)
		game.world.blocked=false; game.session.state.settings.reduce_motion=true
		var visible_roofs=region_layer.visuals.filter(func(item): return item.fade and item.node.visible)
		if not visible_roofs.is_empty():
			var item=visible_roofs[0]; var original=game.world.player
			game.world.player=game.world.uniso(item.node.position-Vector2(0,30)); game.world.camera.position=item.node.position; region_layer._update_visibility()
			verify.call(item.node.modulate.a<.5,"树冠与屋顶遮挡时淡化："+id)
			game.world.player=original; game.world._update_camera()
		game.menus.pages.state("map").region=id; game.menus.pages.state("map").category="region"; game.open_menu("map"); await tree.process_frame
		var map=map_control(game); var b=db.regions[id].buildings[0]; var click=InputEventMouseButton.new(); click.pressed=true; click.button_index=MOUSE_BUTTON_LEFT; click.position=map.project(Vector2(b.x+b.w/2,b.y+b.d/2)); map._gui_input(click)
		verify.call(game.menus.pages.state("map").selection==b.id,"地图点击使用实际区域投影："+id)
		await tree.process_frame; map=map_control(game)
		var zoom_event=InputEventMouseButton.new(); zoom_event.pressed=true; zoom_event.button_index=MOUSE_BUTTON_WHEEL_UP; zoom_event.position=map.size/2; map._gui_input(zoom_event)
		var old_pan=map.pan; var drag=InputEventMouseButton.new(); drag.pressed=true; drag.button_index=MOUSE_BUTTON_LEFT; drag.position=Vector2(3,3); map._gui_input(drag)
		var move=InputEventMouseMotion.new(); move.position=Vector2(28,20); move.relative=Vector2(25,17); map._gui_input(move)
		verify.call(map.zoom>1 and map.pan!=old_pan,"地图滚轮缩放和拖动："+id)
		var zoom=map.zoom; var pan=map.pan; game.close_menu(); game.open_menu("map"); await tree.process_frame; map=map_control(game)
		verify.call(map.zoom==zoom and map.pan==pan,"地图视角属于临时 UI 状态并可恢复："+id)
		var point=game.world.player; Input.action_press("move_down"); game.world._process(.25); Input.action_release("move_down")
		verify.call(game.world.player==point,"区域地图阻断场景输入："+id)
		game.close_menu(); game.menus.pages.state("map").view_states={}
		game._interact("landmark",db.regions[id].buildings[0].id)
		verify.call(game.overlay=="map" and game.menus.pages.state("map").region==id,"场景 E 交互打开对应地标介绍："+id)
		game.close_menu()
	game.navigate("city"); game.world.player=Vector2(90,66); game.session.state.location.x=90.0; game.session.state.location.y=66.0
	verify.call(game.world._can_walk(game.world.player),"王城超过 64×48 范围的落点可通行")
	var store=SaveStore.new(game.session,"user://tests/regions"); var saved=store.save(1); game.navigate("town"); var loaded=store.load_slot(1); game.refresh()
	verify.call(saved=="" and loaded=="" and game.world.player==Vector2(90,66) and game.world.scene_id=="city","王城大坐标按原生 v1 格式完整存读")
	game._interact("travel","town")
	while game.loading.busy: await tree.process_frame
	verify.call(game.world.scene_id=="town","区域旅行点返回晨星镇")
	var original=game.session.state.duplicate(true)
	game.session.enter_training("warden",["mira"],6)
	verify.call(game.session.visit("wood")!="" and game.session.state.location.scene=="town-trial","训练期间禁止跨区域旅行")
	game.session.start_battle("town-trial-2",417)
	verify.call(game.session.visit("city")!="","战斗期间禁止区域旅行")
	game.session.exit_training(); verify.call(game.session.state==original,"退出训练恢复完整剧情快照")
	game.refresh(); game.navigate("wood"); await tree.process_frame; var count=nodes(game.world).size(); var textures=game.world.textures.size()
	for i in 3:
		for id in db.regions: game.navigate(id); await tree.process_frame
		game.navigate("wood"); await tree.process_frame
	verify.call(nodes(game.world).size()==count,"重复切换五地不累计节点")
	verify.call(game.world.textures.size()==textures,"所有区域预热后纹理缓存保持稳定")
	game.queue_free(); await tree.process_frame
