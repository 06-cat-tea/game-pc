class_name WorldView
extends Node2D

signal interacted(kind: String, id: String)
signal position_changed(x: float, y: float)
signal hint_changed(text: String)
var db: GameContent
var session: GameSession
var scene_id = ""
var map_root: Node2D
var camera: Camera2D
var hero: Sprite2D
var hero_shadow: Sprite2D
var marker: Sprite2D
var targets = []
var grid = AStarGrid2D.new()
var walking_path = []
var pending_target = {}
var player = Vector2.ZERO
var blocked = false:
	set(value):
		blocked=value
		if value:
			for target in targets:
				for child in target.node.get_children():
					if child.has_meta("world_caption"): child.visible=false
var direction = 3
var move_clock = 0.0
var last_hint = ""
var path_stall = 0.0
var textures = {}
var caption_clock=0.0
var region_layer: RegionScene
var town_life: TownLife
var presentation_revision=-1

func texture(path: String) -> Texture2D:
	if path == "": return null
	if not textures.has(path): textures[path] = load(path)
	return textures[path]

func setup(content: GameContent, game: GameSession):
	db = content; session = game
	camera = Camera2D.new(); add_child(camera); camera.enabled = true

func iso(point: Vector2) -> Vector2:
	return WorldPresentation.iso(point,scene_id)

func uniso(point: Vector2) -> Vector2:
	if db.is_outdoor(scene_id): return Vector2(point.x/96.0+point.y/48.0,point.y/48.0-point.x/96.0)
	return Vector2((point.x-960)/165.6+(point.y-170)/82.8,(point.y-170)/82.8-(point.x-960)/165.6)

func entry(building: Dictionary) -> Vector2:
	if building.has("entry"): return Vector2(building.entry[0],building.entry[1])
	var art = db.raw.art.buildings[building.id]
	return Vector2(building.x+building.w+1.5,building.y+building.d/2.0) if art.get("entrySide", "y") == "x" else Vector2(building.x+building.w/2.0,building.y+building.d+1.5)

func show_location():
	if session.state.is_empty(): return
	var location = session.state.location
	if scene_id == location.scene and presentation_revision==session.presentation_revision: return
	presentation_revision=session.presentation_revision
	scene_id = location.scene; walking_path = []; pending_target = {}; targets = []
	if map_root != null: remove_child(map_root); map_root.queue_free()
	map_root = Node2D.new(); add_child(map_root)
	region_layer=null
	var ground = WorldGround.new(); map_root.add_child(ground); ground.setup(db,scene_id)
	var depth = Node2D.new(); depth.y_sort_enabled = true; map_root.add_child(depth)
	if scene_id == "town":
		for building in db.raw.buildings:
			var art = db.raw.art.buildings[building.id]
			_shadow(depth,iso(Vector2(building.x+building.w/2.0,building.y+building.d/2.0)),float(building.w+building.d)*48)
			var sprite = _sprite(depth, str(art.path), iso(Vector2(building.x+building.w/2.0,building.y+building.d/2.0)), float(building.w+building.d)*58, art.get("anchor",[0.5,0.88]))
			var item = {"kind":"building","id":building.id,"label":building.name,"point":entry(building),"node":sprite,"width":float(building.w+building.d)*58}
			targets.append(item); _caption(sprite,building.name)
		for id in db.raw.npcs:
			var npc = db.raw.npcs[id]
			if not npc.has("position") or npc.get("place", "town") != "town": continue
			_add_npc(depth,id,Vector2(npc.position.x,npc.position.y))
		for decor in WorldPresentation.config().decor:
			var p=Vector2(decor.point[0],decor.point[1]); _shadow(depth,iso(p),decor.width*.7)
			_sprite(depth,decor.asset,iso(p),decor.width,decor.anchor)
	elif db.regions.has(scene_id):
		region_layer=RegionScene.new(); map_root.add_child(region_layer); region_layer.setup(self,depth)
	else:
		if db.raw.scenes[scene_id].get("procedural",false):
			var interior=StoryInterior.new(); map_root.add_child(interior); interior.setup(db.raw.scenes[scene_id])
		else:
			var background = Sprite2D.new(); background.texture = texture(db.raw.scenes[scene_id].background); background.position = Vector2(960,540); background.modulate=Color(1.0,0.985,0.955); background.z_index = -5; map_root.add_child(background)
		var ambience=WorldPresentation.config().ambience.get(scene_id,{"overlay":"res://assets/refined-world/interaction.svg","tint":"f1d3a0","opacity":0.0})
		var light=Sprite2D.new(); light.texture=WorldPresentation.texture(ambience.overlay); light.position=Vector2(960,540); light.modulate=Color(ambience.tint,ambience.opacity); light.z_index=-4; map_root.add_child(light)
		for prop in session.progression.scene_props(scene_id):
			var point = Vector2(prop.x,prop.y)
			var ring=Node2D.new(); ring.position=iso(point); depth.add_child(ring)
			var symbol=Sprite2D.new(); symbol.texture=WorldPresentation.texture("res://assets/refined-world/interaction.svg"); symbol.scale=Vector2(0.52,0.32); ring.add_child(symbol)
			_shadow(depth,iso(point)+Vector2(8,4),64)
			_caption(ring,prop.name)
			targets.append({"kind":"prop","id":prop.id,"label":prop.name,"point":point,"node":ring,"width":54.0})
		for npc in db.scene_npcs(scene_id): _add_npc(depth,npc.id,Vector2(npc.get("x",4.4),npc.get("y",3.2)))
		var exit_point = Vector2(9,9)
		var destination=session.story.return_scene(); var label="返回"+db.location_title(destination)
		var sign_node = Node2D.new(); sign_node.position = iso(exit_point); depth.add_child(sign_node); _caption(sign_node,label)
		var exit_icon=Sprite2D.new(); exit_icon.texture=WorldPresentation.texture("res://assets/refined-world/interaction.svg"); exit_icon.scale=Vector2(.7,.43); exit_icon.modulate=Color("d2b875"); sign_node.add_child(exit_icon)
		targets.append({"kind":"exit","id":destination,"label":label,"point":exit_point,"node":sign_node,"width":90.0})
	hero = _sprite(depth,db.art("actors","hero"),Vector2.ZERO,90 if db.is_outdoor(scene_id) else 125,[0.5,0.95])
	if not db.is_outdoor(scene_id):
		var ambient=BuildingAmbience.new(); map_root.add_child(ambient); ambient.setup(self)
	town_life=TownLife.new(self); town_life.setup(depth)
	hero_shadow=_shadow(depth,Vector2.ZERO,56 if db.is_outdoor(scene_id) else 80)
	player = Vector2(location.x,location.y)
	if not _can_walk(player): player = _safe_point(player)
	_update_actor(Vector2.ZERO,0)
	_setup_grid()
	_update_camera()
	_update_captions()

func _shadow(parent: Node2D, point: Vector2, width: float) -> Sprite2D:
	var shadow=Sprite2D.new(); shadow.texture=WorldPresentation.texture("res://assets/refined-world/contact-shadow.svg"); shadow.position=point+Vector2(12,7); shadow.z_index=-1
	shadow.scale=Vector2(width/512.0,width/512.0); parent.add_child(shadow)
	return shadow

func _sprite(parent: Node2D, path: String, position_value: Vector2, width: float, anchor: Array) -> Sprite2D:
	var sprite = Sprite2D.new(); sprite.texture = texture(path); sprite.centered = false; sprite.position = position_value
	if sprite.texture != null:
		sprite.offset = Vector2(-sprite.texture.get_width()*anchor[0],-sprite.texture.get_height()*anchor[1]); sprite.scale = Vector2.ONE*width/sprite.texture.get_width()
	parent.add_child(sprite)
	return sprite

func _caption(parent: Node2D, text: String):
	var label = Label.new(); label.text = text; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; label.position = Vector2(-180,12); label.size = Vector2(360,34)
	label.add_theme_font_override("font",UIkit.font()); label.add_theme_font_size_override("font_size",20); label.add_theme_color_override("font_color",Color("f3e6c5")); label.add_theme_color_override("font_outline_color",Color("121c22")); label.add_theme_constant_override("outline_size",4)
	# Labels inherit the sprite's transform; compensate so all names stay readable.
	if parent is Sprite2D: label.scale = Vector2.ONE / parent.scale; label.position = Vector2(-180*label.scale.x,12*label.scale.y)
	parent.add_child(label); label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("world_caption",true); label.visible=false

func _add_npc(parent: Node2D, id: String, point: Vector2):
	point=_safe_point(point)
	var npc = db.raw.npcs[id]
	var path = db.art("actors", id)
	if path == "": path = db.art("actors",npc.get("type","villager"))
	var sprite = _sprite(parent,path,iso(point),50 if db.world_interactions.children.has(id) else 78 if db.is_outdoor(scene_id) else 112,[0.5,0.95]); _caption(sprite,npc.name)
	_shadow(parent,iso(point),54 if scene_id=="town" else 76)
	targets.append({"kind":"npc","id":id,"label":npc.name,"point":point,"node":sprite,"width":70.0})

func _can_walk(point: Vector2) -> bool:
	if db.regions.has(scene_id): return RegionCatalog.walkable(scene_id,point)
	if scene_id == "town":
		if point.x < 2 or point.y < 2 or point.x > 61 or point.y > 45: return false
		for polygon in db.raw.layout.get("water", []):
			var points = PackedVector2Array()
			for p in polygon: points.append(Vector2(p[0],p[1]))
			if Geometry2D.is_point_in_polygon(point,points): return false
		for building in db.raw.buildings:
			if Rect2(building.x-0.3,building.y-0.3,building.w+0.6,building.d+0.6).has_point(point): return false
		return true
	if point.x < 0.35 or point.y < 0.35 or point.x > 9.6 or point.y > 9.6: return false
	for collision in db.raw.scenes[scene_id].get("collisions", []):
		if collision.has("x") and Rect2(float(collision.x)-float(collision.w)/2,float(collision.y)-float(collision.d)/2,float(collision.w),float(collision.d)).has_point(point): return false
		var points = PackedVector2Array()
		for p in collision.get("polygon", []): points.append(Vector2(p[0],p[1]))
		if points.size() > 2 and Geometry2D.is_point_in_polygon(point,points): return false
	return true

func _safe_point(requested: Vector2) -> Vector2:
	if _can_walk(requested): return requested
	for radius in range(1,20):
		for i in 16:
			var p = requested+Vector2.from_angle(float(i)*TAU/16.0)*radius*0.3
			if _can_walk(p): return p
	if db.regions.has(scene_id):
		var spawn=db.regions[scene_id].spawn; return Vector2(spawn[0],spawn[1])
	return Vector2(30,27) if scene_id == "town" else Vector2(8.5,8.5)

func _setup_grid():
	grid.region = Rect2i(0,0,64,48) if scene_id == "town" else Rect2i(0,0,40,40)
	grid.cell_size = Vector2.ONE if scene_id == "town" else Vector2(0.25,0.25)
	if db.regions.has(scene_id):
		var data=db.regions[scene_id]; grid.region=Rect2i(0,0,data.columns,data.rows); grid.cell_size=Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x: grid.set_point_solid(Vector2i(x,y),not _can_walk(Vector2(x,y)*grid.cell_size))

func navigate(point: Vector2, target: Dictionary = {}):
	var destination = _safe_point(point)
	var cell_size = grid.cell_size.x
	var from = _walkable_cell(Vector2i((player/cell_size).round())); var to = _walkable_cell(Vector2i((destination/cell_size).round()))
	if not grid.is_in_boundsv(from) or not grid.is_in_boundsv(to): return
	var path = grid.get_id_path(from,to)
	if path.is_empty(): stop(); return
	walking_path = []
	for id in path: walking_path.append(Vector2(id)*cell_size)
	if not walking_path.is_empty(): walking_path.pop_front()
	if not walking_path.is_empty() and (walking_path[-1]-destination).length()>0.01 and _can_walk(destination): walking_path.append(destination)
	elif walking_path.is_empty() and player.distance_to(destination)>0.01: walking_path.append(destination)
	path_stall=0
	pending_target = target

func _walkable_cell(requested: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(requested) and not grid.is_point_solid(requested): return requested
	for radius in range(1,9):
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1):
				var point=requested+Vector2i(dx,dy)
				if grid.is_in_boundsv(point) and not grid.is_point_solid(point): return point
	return Vector2i(-1,-1)

func stop():
	walking_path = []; pending_target = {}; move_clock = 0.0; path_stall=0
	if is_instance_valid(hero): _update_actor(Vector2.ZERO,0)

func projection() -> Transform2D:
	var config=WorldPresentation.config().coordinates.town if db.is_outdoor(scene_id) else WorldPresentation.config().coordinates.scene
	return Transform2D(Vector2(config.axisX[0],config.axisX[1]),Vector2(config.axisY[0],config.axisY[1]),Vector2.ZERO)

func screen_step(screen_direction: Vector2, delta: float, running: bool = false) -> Vector2:
	var axes=projection()
	var pixels_per_second=(axes*Vector2(1,-1).normalized()).length()*4.2
	return axes.affine_inverse()*(screen_direction.normalized()*pixels_per_second*delta*(1.8 if running else 1.0))

func _move_step(step: Vector2):
	var pieces=maxi(1,ceili(step.length()/0.12))
	var part=step/pieces
	var axes=projection(); var inverse=axes.affine_inverse()
	for i in pieces:
		if _can_walk(player+part): player+=part; continue
		var screen=axes*part
		var candidates=[Vector2(screen.x,0),Vector2(0,screen.y)]
		candidates.sort_custom(func(a,b): return a.length_squared()>b.length_squared())
		for candidate in candidates:
			var slide=inverse*candidate
			if slide.length()>0.00001 and _can_walk(player+slide): player+=slide; break

func _process(delta: float):
	if hero == null or not visible or blocked: return
	if town_life!=null: town_life.process(delta)
	var input = Input.get_vector("move_left","move_right","move_up","move_down")
	var movement = input.normalized()
	if movement != Vector2.ZERO: walking_path=[]; pending_target={}
	elif not walking_path.is_empty():
		if not pending_target.is_empty() and player.distance_to(pending_target.point)<2.2:
			var target=pending_target; stop(); interacted.emit(target.kind,target.id); return
		while not walking_path.is_empty() and player.distance_to(walking_path[0])<0.01:
			walking_path.pop_front()
		if not walking_path.is_empty(): movement=(projection()*(walking_path[0]-player)).normalized()
		elif not pending_target.is_empty(): var target = pending_target; pending_target = {}; interacted.emit(target.kind,target.id); return
	var step=screen_step(movement,delta,Input.is_action_pressed("run"))
	if input==Vector2.ZERO and not walking_path.is_empty() and step.length()>player.distance_to(walking_path[0]): step=walking_path[0]-player
	var before=player
	_move_step(step)
	var actual=player-before
	var moved=actual.length()>0.00001
	if not walking_path.is_empty():
		path_stall=0 if moved else path_stall+delta
		if path_stall>0.45: stop()
	if moved: position_changed.emit(player.x,player.y)
	_update_actor(actual,delta)
	_update_camera()
	caption_clock+=delta
	if caption_clock>0.12: caption_clock=0; _update_captions()
	var nearest = _nearest()
	var hint = "WASD 移动 · Shift 奔跑"
	if not nearest.is_empty(): hint = GameBindings.label("interact")+"  " + nearest.label
	if hint != last_hint: last_hint = hint; hint_changed.emit(hint)

func _update_captions():
	var mouse=get_global_mouse_position()
	for target in targets:
		var near=player.distance_to(target.point)<3.4
		var hit=Rect2(target.node.global_position-Vector2(target.width/2.0,target.width),Vector2(target.width,target.width+32))
		for child in target.node.get_children():
			if child.has_meta("world_caption"): child.visible=near or hit.has_point(mouse)

func _update_actor(movement: Vector2, delta: float):
	if hero == null: return
	if movement.length() > 0:
		move_clock += delta*(1.8 if Input.is_action_pressed("run") else 1.0)
		var screen_motion = projection()*movement
		direction=int(floor(fposmod(screen_motion.angle()+PI/2+PI/8,TAU)/(TAU/8)))
	else: move_clock = 0
	var frame = 0 if move_clock == 0 else 1+int(move_clock*db.movement.fps)%4
	var animation=db.movement.directions[db.movement.order[direction]]
	var path=animation.idle if frame==0 else animation.walk[frame-1]
	if not ResourceLoader.exists(path): path=db.art("actors","hero")
	hero.texture = texture(path); hero.position = iso(player)
	if is_instance_valid(hero_shadow): hero_shadow.position=hero.position+Vector2(7,5)

func _update_camera(): camera.position = iso(player)+Vector2(0,-65) if db.is_outdoor(scene_id) else Vector2(960,540)

func _nearest() -> Dictionary:
	var found = {}; var distance = 2.6
	for target in targets:
		var value = player.distance_to(target.point)
		if value < distance: found = target; distance = value
	return found

func _unhandled_input(event: InputEvent):
	if blocked or not visible or hero == null: return
	if event.is_action_pressed("interact"):
		var target = _nearest()
		if not target.is_empty(): interacted.emit(target.kind,target.id); get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse = get_global_mouse_position(); var selected = {}; var closest = INF
		for target in targets:
			var hit = Rect2(target.node.global_position-Vector2(target.width/2.0,target.width),Vector2(target.width,target.width+45))
			if hit.has_point(mouse) and mouse.distance_to(target.node.global_position) < closest: selected = target; closest = mouse.distance_to(target.node.global_position)
		if not selected.is_empty():
			if player.distance_to(selected.point) < 2.8: interacted.emit(selected.kind,selected.id)
			else: navigate(selected.point,selected)
		else: navigate(uniso(mouse))
		get_viewport().set_input_as_handled()
