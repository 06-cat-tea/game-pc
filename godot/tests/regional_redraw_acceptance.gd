extends RefCounted

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	var art_paths=[]; var count=0
	for id in ["wood","pass","fen","coast"]:
		game.navigate(id); await tree.process_frame
		var region=game.db.regions[id]; var world=game.world
		var decor_types={}
		for decor in region.decor: decor_types[decor.asset]=true
		verify.call(region.get("artVersion","")=="regional-redraw-v1" and region.decor.size()>120 and decor_types.size()>=4,"四地接入独立画风及多种用途化细节："+id)
		var from=world._walkable_cell(Vector2i(world.player.round()))
		for building in region.buildings:
			count+=1; art_paths.append(building.art)
			verify.call("assets/regional-redraw/" in building.art,"功能建筑使用独立重绘："+building.id)
		for target in world.targets:
			verify.call(world._can_walk(target.point),"新场景保留真实任务与入口落点："+target.id)
			verify.call(not world.grid.get_id_path(from,world._walkable_cell(Vector2i(target.point.round()))).is_empty(),"新场景实际寻路可达："+target.id)
		for road in region.roads:
			var clear=true
			for i in range(1,road.points.size()):
				var a=Vector2(road.points[i-1][0],road.points[i-1][1]); var b=Vector2(road.points[i][0],road.points[i][1]); var normal=(b-a).normalized().orthogonal()
				for step in range(ceili(a.distance_to(b)*4)+1):
					var p=a.move_toward(b,step*.25)
					for side in [-1.0,0.0,1.0]:
						if not world._can_walk(p+normal*side*(float(road.width)*.5-.35)): clear=false
			verify.call(clear,"道路净宽与新装饰避让："+id+" "+str(road.get("kind",road.get("building_id",""))))
		var legal=Vector2(region.spawn[0],region.spawn[1]); game.session.state.location={"scene":id,"x":legal.x,"y":legal.y}; world.scene_id=""; world.show_location()
		verify.call(world.player==legal,"四地合法旧档落点原位保留："+id)
		if id=="coast":
			verify.call(region.harbor.facilities.size()==3 and region.bridges.size()==3,"归帆港由港务所、三座独立设施及三段栈桥组成")
			for facility in region.harbor.facilities:
				var p=Vector2(facility.entry[0],facility.entry[1])
				verify.call(world._can_walk(p) and not world.grid.get_id_path(from,world._walkable_cell(Vector2i(p.round()))).is_empty(),"港区独立设施门前可达："+facility.id)
				var occupied=Vector2(facility.x+facility.w/2,facility.y+facility.d/2)
				verify.call(not world._can_walk(occupied),"港区附属建筑实际基底碰撞："+facility.id)
				game.session.state.location={"scene":"coast","x":occupied.x,"y":occupied.y}; world.scene_id=""; world.show_location()
				verify.call(world._can_walk(world.player) and world.player!=occupied,"旧档被港区新设施占用时安全恢复："+facility.id)
			for bridge in region.bridges: verify.call(world._can_walk(Vector2(bridge.x,bridge.y)),"港区栈桥可步行："+str(bridge.kind))
			var resident=world.region_layer.residents[0]; var before=resident.point; world.region_layer._process(.5)
			verify.call(resident.point==before,"减少动效冻结港区生活人物")
			game.session.state.settings.reduce_motion=false; world.blocked=false; world.region_layer._process(.5)
			verify.call(resident.point!=before,"港区生活人物沿可通行路线活动")
			game.session.state.settings.reduce_motion=true
	verify.call(count==19 and art_paths.size()==19,"四地保留19处原有功能建筑")
	var unique={}
	for p in art_paths: unique[p]=true
	verify.call(unique.size()==19,"19处地标采用19种独立造型")
	game.queue_free(); await tree.process_frame
