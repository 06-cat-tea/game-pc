extends RefCounted

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	game.navigate("city"); await tree.process_frame
	var city=game.db.regions.city; var world=game.world
	verify.call(city.designVersion==2 and city.buildings.size()==52,"新版王城保留52栋建筑与原有ID")
	var from=world._walkable_cell(Vector2i(world.player.round()))
	var original_point=world.player
	for target in world.targets:
		verify.call(world._can_walk(target.point),"王城真实交互点可通行："+target.id)
		verify.call(not world.grid.get_id_path(from,world._walkable_cell(Vector2i(target.point.round()))).is_empty(),"王城真实交互点连通："+target.id)
		world.player=target.point
		verify.call(world._nearest().get("id","")==target.id,"F命中对应王城目标："+target.id)
	world.player=original_point
	for road in city.roads:
		var a=Vector2(road.points[0][0],road.points[0][1]); var b=Vector2(road.points[1][0],road.points[1][1]); var tangent=(b-a).normalized().orthogonal()
		var open=true
		for i in range(ceili(a.distance_to(b)*4)+1):
			var center=a.move_toward(b,i*.25)
			for side in [-1.0,0.0,1.0]:
				var p=center+tangent*side*(float(road.width)*.5-.35)
				if not world._can_walk(p): open=false
		verify.call(open,"王城道路完整净宽："+str(road.points))
	var legal=Vector2(90,66); game.session.state.location={"scene":"city","x":legal.x,"y":legal.y}; world.scene_id=""; world.show_location()
	verify.call(world.player==legal,"王城合法旧坐标原位保留")
	var b=city.buildings[0]; var occupied=Vector2(b.x+b.w*.5,b.y+b.d*.5)
	game.session.state.location={"scene":"city","x":occupied.x,"y":occupied.y}; world.scene_id=""; world.show_location()
	verify.call(world.player!=occupied and world._can_walk(world.player) and city.terrain[int(world.player.y)][int(world.player.x)]=="road","新建筑占用旧落点时迁到安全道路并同步存档")
	for building in city.buildings:
		var room="room-"+building.id
		if not game.db.raw.scenes.has(room): continue
		game.session.state.location={"scene":"city","x":building.entry[0],"y":building.entry[1]}
		verify.call(game.session.visit(room)=="","王城原有内室仍可进入："+building.id); game.refresh(); await tree.process_frame
		verify.call(game.session.visit("city")=="","王城内室仍可返回："+building.id); game.refresh(); await tree.process_frame
		verify.call(world.player.distance_to(Vector2(building.entry[0],building.entry[1]))<.01,"返回点对应新建筑入口："+building.id)
	for id in GameContent.OUTDOORS:
		game.navigate(id); await tree.process_frame
		var lighting=world.lighting
		game.session.state.phase=1; lighting._process(.2); lighting.update_lights(); var day=lighting.ambient.color
		verify.call(lighting.strength==0.0 and lighting.sources.all(func(s): return not s.light.enabled),"白天关闭室外灯火："+id)
		game.session.state.phase=3; lighting._process(.2); lighting.update_lights(); var night=lighting.ambient.color
		verify.call(night.get_luminance()<day.get_luminance()*.35,"深夜光照明显暗于正午："+id)
		verify.call(lighting.sources.filter(func(s): return s.light.enabled).size()+(1 if lighting.hero_light.enabled else 0)<=8,"室外最多8个局部光源："+id)
		game.session.state.settings.reduce_motion=false; game.session.state.phase=0; lighting._process(.05)
		verify.call(lighting.ambient.color!=lighting.desired and lighting.ambient.color!=night,"正常模式平滑切换时段："+id)
		game.session.state.settings.reduce_motion=true; lighting._process(.05)
		verify.call(lighting.ambient.color==lighting.desired,"减少动效直接切换时段："+id)
	game.open_menu("wheel"); await tree.process_frame
	verify.call(game.quick_wheel.icons.all(func(icon): return icon.texture!=null and "hud-filled" in icon.texture.resource_path),"新版轮盘使用统一实心图标")
	game.close_menu(); game.queue_free(); await tree.process_frame
