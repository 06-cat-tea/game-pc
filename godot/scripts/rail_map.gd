class_name RailMap
extends Control

signal picked(id: String)
var game
var compact=false
var selected=""
var scene_override="town"
var clock=0.0
var image: TextureRect
var last_scene=""
var hovered=""
var zoom=1.0
var pan=Vector2.ZERO
var dragging=false
const COMPACT_SCALE=.13

func setup(owner, small: bool = false):
	game=owner; compact=small; mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=not compact
	if not compact:
		var saved=game.menus.pages.state("map").get("view_states",{}).get(scene_override,{})
		zoom=saved.get("zoom",1.0); pan=saved.get("pan",Vector2.ZERO)
	tooltip_text="打开地点地图" if compact else "选择地标查看详情"
	if compact:
		image=TextureRect.new(); image.size=size; image.mouse_filter=Control.MOUSE_FILTER_IGNORE; image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		var material_value=ShaderMaterial.new(); material_value.shader=load("res://shaders/minimap.gdshader"); image.material=material_value; add_child(image)
	_update_image(); queue_redraw()

func map_scene() -> String: return game.world.scene_id if compact else scene_override

func _process(delta: float):
	clock+=delta
	if clock>=0.12: clock=0; _update_image(); queue_redraw()

func _update_image():
	if not compact: return
	var id=map_scene(); var bounds=WorldPresentation.bounds(id)
	if id!=last_scene:
		image.texture=WorldPresentation.overview(id); last_scene=id
	var center=WorldPresentation.iso(game.world.player,id) if game.db.is_outdoor(id) else bounds.get_center()
	var visible_size=Vector2.ONE*size.x/COMPACT_SCALE if game.db.is_outdoor(id) else Vector2.ONE*bounds.size.y
	image.material.set_shader_parameter("map_center",(center-bounds.position)/bounds.size)
	image.material.set_shader_parameter("map_span",visible_size/bounds.size)

func map_rect() -> Rect2:
	var bounds=WorldPresentation.bounds(map_scene()); var available=size-Vector2(48,110)
	var factor=minf(available.x/bounds.size.x,available.y/bounds.size.y)
	var dimensions=bounds.size*factor*zoom
	return Rect2(size/2-dimensions/2+pan,dimensions)

func project(point: Vector2) -> Vector2:
	var id=map_scene(); var world=WorldPresentation.iso(point,id)
	if compact:
		if game.db.is_outdoor(id): return size/2+(world-WorldPresentation.iso(game.world.player,id))*COMPACT_SCALE
		return size/2+(world-WorldPresentation.bounds(id).get_center())*size.x/1080.0
	var bounds=WorldPresentation.bounds(id); var rect=map_rect()
	return rect.position+(world-bounds.position)/bounds.size*rect.size

func _draw():
	if game==null: return
	var id=map_scene()
	if compact:
		draw_circle(size/2,size.x/2,UIkit.PAPER)
		# Child texture draws above this surface; markers are drawn by a top overlay.
		if not has_node("Markers"):
			var overlay=Control.new(); overlay.name="Markers"; overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(overlay); overlay.draw.connect(_draw_markers.bind(overlay))
		get_node("Markers").queue_redraw()
		return
	var texture=WorldPresentation.overview(id)
	if texture!=null: draw_texture_rect(texture,map_rect(),false)
	_draw_markers(self)

func _draw_markers(surface: Control):
	if compact: _compact_markers(surface); return
	var id=map_scene()
	for e in game.db.world_interactions.entrances:
		if e.region!=id: continue
		var p=project(Vector2(e.point[0],e.point[1]))
		if compact and p.distance_to(size/2)>size.x/2-12: continue
		var known=e.id in game.session.tasks.ledger.entrances
		surface.draw_arc(p,6 if compact else 12,0,TAU,20,UIkit.GOLD if known else UIkit.MUTED,2,true)
		if not compact: surface.draw_string(UIkit.font(),p+Vector2(16,6),e.name if known else "入口线索",HORIZONTAL_ALIGNMENT_LEFT,240,17,UIkit.INK)
	if id==game.world.scene_id:
		for target in game.world.targets:
			if target.kind!="town-life": continue
			var p=project(target.point)
			if compact and p.distance_to(size/2)>size.x/2-12: continue
			surface.draw_circle(p,3 if compact else 5,Color("b69c6c"))
	if id=="city" and not compact and zoom<1.8:
		for district in game.db.regions.city.districts:
			var p=project(Vector2(district.x,district.y+2))
			surface.draw_style_box(UIkit.style(Color(.96,.95,.92,.88)),Rect2(p-Vector2(70,20),Vector2(140,30)))
			surface.draw_string(UIkit.font(),p-Vector2(66,-3),district.name,HORIZONTAL_ALIGNMENT_CENTER,132,17,UIkit.INK)
	if game.db.is_outdoor(id):
		for b in candidates():
			var p=project(Vector2(b.x+b.w/2,b.y+b.d/2))
			if compact and p.distance_to(size/2)>size.x/2-12: continue
			surface.draw_circle(p,5 if compact else 9,UIkit.PAPER)
			surface.draw_circle(p,3 if compact else 5,UIkit.GOLD if b.id==selected else Color("526879"))
			if not compact and b.id in [selected,hovered]:
				var label_width=160.0; var origin=p+Vector2(-label_width/2,16)
				surface.draw_style_box(UIkit.style(Color(0.97,0.96,0.93,0.92)),Rect2(origin-Vector2(2,16),Vector2(label_width+4,28)))
				surface.draw_string(UIkit.font(),origin+Vector2(0,5),b.name,HORIZONTAL_ALIGNMENT_CENTER,label_width,17,UIkit.INK)
	else:
		var exit_marker=project(Vector2(9,9)); surface.draw_arc(exit_marker,7 if compact else 12,0,TAU,24,UIkit.GOLD,2,true)
		if not compact: surface.draw_string(UIkit.font(),exit_marker+Vector2(16,5),"返回"+game.db.location_title(game.db.place_of(id)),HORIZONTAL_ALIGNMENT_LEFT,240,17,UIkit.INK)
		for prop in game.db.raw.scenes[id].props:
			var p=project(Vector2(prop.x,prop.y))
			if compact and p.distance_to(size/2)>size.x/2-10: continue
			surface.draw_circle(p,4 if compact else 8,UIkit.PAPER); surface.draw_circle(p,2 if compact else 4,UIkit.GOLD)
			if not compact and prop.id==selected:
				surface.draw_style_box(UIkit.style(Color(0.97,0.96,0.93,0.94)),Rect2(p+Vector2(-94,12),Vector2(188,32)))
				surface.draw_string(UIkit.font(),p+Vector2(-90,35),prop.name,HORIZONTAL_ALIGNMENT_CENTER,180,18,UIkit.INK)
	var location=game.session.state.location; var point=Vector2(location.x,location.y)
	for npc in npc_candidates():
		var marker=project(Vector2(npc.x,npc.y))
		if compact and marker.distance_to(size/2)>size.x/2-12: continue
		surface.draw_circle(marker,4 if compact else 7,Color("829c9d"))
		if not compact: surface.draw_circle(marker,2,UIkit.PAPER)
	for target in task_markers():
		var marker=project(target)
		if compact and marker.distance_to(size/2)>size.x/2-14: continue
		var radius=7 if compact else 12
		surface.draw_colored_polygon(PackedVector2Array([marker+Vector2(0,-radius),marker+Vector2(radius,0),marker+Vector2(0,radius),marker+Vector2(-radius,0)]),UIkit.GOLD)
		surface.draw_circle(marker,2.5,UIkit.PAPER)
	if id=="town" and not game.db.is_outdoor(location.scene):
		for b in game.db.raw.buildings:
			if "room-"+b.id==location.scene: point=Vector2(b.x+b.w/2,b.y+b.d/2)
		var e=game.session.tasks.entrance_for(location.scene)
		if not e.is_empty() and e.region==id: point=Vector2(e.point[0],e.point[1])
	if id==location.scene or (id=="town" and not game.db.is_outdoor(location.scene)):
		var p=project(point); surface.draw_circle(p,10,Color(0.95,0.94,0.90,0.85))
		surface.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-8),p+Vector2(-6,7),p+Vector2(0,4),p+Vector2(6,7)]),Color("385d7b"))
	if compact:
		surface.draw_arc(size/2,size.x/2-2,0,TAU,80,UIkit.ACCENT,2,true)
		surface.draw_string(UIkit.font(),Vector2(size.x/2-7,21),"N",HORIZONTAL_ALIGNMENT_LEFT,30,16,UIkit.INK)

func _compact_markers(surface: Control):
	var center=size/2; var radius=size.x/2
	surface.draw_arc(center,radius-1,0,TAU,100,Color("28352d"),4,true)
	surface.draw_arc(center,radius-3,0,TAU,100,Color("d6c395"),1.5,true)
	surface.draw_arc(center,radius-8,0,TAU,100,Color(.94,.88,.70,.35),1,true)
	var icons={"clocktower":"clock","chapel":"chapel","inn":"inn","market":"market"}
	for b in candidates():
		if not icons.has(b.id): continue
		var p=project(Vector2(b.x+b.w/2,b.y+b.d/2))
		if p.distance_to(center)>radius-24: continue
		surface.draw_circle(p,14,Color(.08,.14,.11,.8)); surface.draw_arc(p,14,0,TAU,32,Color("d6c395"),1,true)
		var symbol=UIkit.texture("res://assets/ui/hud-filled/"+icons[b.id]+".svg")
		surface.draw_texture_rect(symbol,Rect2(p-Vector2(12,12),Vector2(24,24)),false)
	var targets=task_markers()
	if targets.is_empty() and map_scene()=="town" and not game.session.state.chapter_complete:
		targets.append(Vector2(game.db.town_design.points["entrance-town-wall"][0],game.db.town_design.points["entrance-town-wall"][1]))
	if not targets.is_empty():
		var p=project(targets[0]); var delta=p-center
		if delta.length()>radius-22: p=center+delta.normalized()*(radius-22)
		var symbol=UIkit.texture("res://assets/ui/hud-filled/diamond.svg")
		surface.draw_texture_rect(symbol,Rect2(p-Vector2(12,15),Vector2(24,30)),false)
	surface.draw_circle(center,13,Color(.94,.94,.86,.8))
	surface.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-12),center+Vector2(-9,9),center+Vector2(0,4),center+Vector2(9,9)]),Color("64a9c4"))
	surface.draw_circle(Vector2(center.x,12),15,Color(.08,.13,.10,.72))
	surface.draw_string(UIkit.hud_font(),Vector2(center.x-8,21),"N",HORIZONTAL_ALIGNMENT_LEFT,30,22,Color("f6eed8"))

func _gui_input(event: InputEvent):
	if event is InputEventMouseMotion and dragging:
		pan+=event.relative; _remember_view(); queue_redraw(); accept_event(); return
	if event is InputEventMouseMotion and not compact and game.db.is_outdoor(map_scene()):
		hovered=""; tooltip_text="点击地标查看详情"
		for b in candidates():
			if project(Vector2(b.x+b.w/2,b.y+b.d/2)).distance_to(event.position)<24: hovered=b.id; tooltip_text=b.name; break
		queue_redraw()
	if event is InputEventMouseButton and not compact and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var rect=map_rect(); var uv=(event.position-rect.position)/rect.size
		zoom=clampf(zoom*(1.2 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.2),1.0,3.0)
		var resized=map_rect(); pan+=event.position-(resized.position+uv*resized.size)
		if zoom==1.0: pan=Vector2.ZERO
		_remember_view(); queue_redraw(); accept_event(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed: dragging=false
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not compact:
			for e in game.db.world_interactions.entrances:
				if e.region==map_scene() and project(Vector2(e.point[0],e.point[1])).distance_to(event.position)<18:
					accept_event(); game.open_menu("entrance",e.id); return
		if compact: game.open_menu("map")
		else:
			for npc in npc_candidates():
				if project(Vector2(npc.x,npc.y)).distance_to(event.position)<13:
					game.seek(map_scene(),"npc",npc.id); accept_event(); return
			var best=""; var distance=28.0
			for item in candidates():
				var p=Vector2(item.x+item.get("w",0)/2,item.y+item.get("d",0)/2) if game.db.is_outdoor(map_scene()) else Vector2(item.x,item.y)
				var d=project(p).distance_to(event.position)
				if d<distance: distance=d; best=item.id
			if best!="": selected=best; picked.emit(best); queue_redraw()
			else: dragging=true
		accept_event()

func candidates() -> Array:
	var id=map_scene()
	if id=="town": return game.db.raw.buildings
	if game.db.regions.has(id): return game.db.regions[id].buildings
	return game.db.raw.scenes[id].props

func npc_candidates() -> Array:
	var result=[]; var scene=map_scene()
	if game.db.is_outdoor(scene):
		for id in game.db.raw.npcs:
			var npc=game.db.raw.npcs[id]
			if npc.get("place","")==scene and npc.has("position"): result.append({"id":id,"x":npc.position.x,"y":npc.position.y})
	else:
		for npc in game.db.scene_npcs(scene): result.append({"id":npc.id,"x":npc.get("x",4.4),"y":npc.get("y",3.2)})
	return result

func task_markers() -> Array:
	var result=[]
	for task in game.session.tasks.ledger.records:
		if game.session.tasks.status(task)=="completed": continue
		var target=game.session.tasks.target(task)
		if target.get("unknown",false) or target.get("scene","")!=map_scene(): continue
		if map_scene()==game.world.scene_id:
			for actual in game.world.targets:
				if actual.kind==target.kind and actual.id==target.id: result.append(actual.point)
		elif target.kind=="entrance":
			var e=game.session.tasks.entrance(target.id); result.append(Vector2(e.point[0],e.point[1]))
		elif target.kind=="town-life":
			for d in game.db.world_interactions.resources+game.db.world_interactions.objects+game.db.world_interactions.animals:
				if d.id==target.id: result.append(Vector2(d.point[0],d.point[1]))
		elif target.kind=="npc":
			for npc in npc_candidates():
				if npc.id==target.id: result.append(Vector2(npc.x,npc.y))
	if not game.session.state.chapter_complete: return result
	var scene=map_scene(); var stage=int(game.session.state.story.stage); var id="mira"; var building=""
	if stage==1: building="moss-shrine"
	elif stage in [3,4]: id="toren"
	elif stage in [5,6]: id="eira"
	if building!="" and game.db.regions.has(scene):
		for b in game.db.regions[scene].buildings:
			if b.id==building: result.append(Vector2(b.entry[0],b.entry[1]))
		return result
	for npc in npc_candidates():
		if npc.id==id: result.append(Vector2(npc.x,npc.y))
	return result

func _remember_view():
	var ui_state=game.menus.pages.state("map")
	if not ui_state.has("view_states"): ui_state.view_states={}
	pan.x=clampf(pan.x,-size.x*(zoom-.5),size.x*(zoom-.5)); pan.y=clampf(pan.y,-size.y*(zoom-.5),size.y*(zoom-.5))
	ui_state.view_states[scene_override]={"zoom":zoom,"pan":pan}
