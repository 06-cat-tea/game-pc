class_name TownLife
extends RefCounted

var world
var animals=[]
var clock=0.0
var discovery_clock=0.0

func _init(owner): world=owner

func setup(parent: Node2D):
	animals=[]; clock=0
	var db=world.db
	for e in db.world_interactions.entrances:
		if e.region!=world.scene_id: continue
		add_marker(parent,"entrance",e.id,e.name,Vector2(e.point[0],e.point[1]))
	if world.scene_id!="town": return
	for d in db.world_interactions.animals:
		var point=Vector2(d.point[0],d.point[1])
		var sprite=world._sprite(parent,d.frames[0],world.iso(point),d.width,[0.5,0.95])
		world._caption(sprite,d.name+" · "+d.species)
		var target={"kind":"town-life","id":d.id,"label":d.name,"point":point,"node":sprite,"width":float(d.width)}
		world.targets.append(target)
		animals.append({"data":d,"home":point,"target":target,"time":0.0,"destination":point,"moving":false,"phase":animals.size()*1.7})
	for d in db.world_interactions.resources:
		var target=add_marker(parent,"town-life",d.id,d.name,Vector2(d.point[0],d.point[1]))
		if world.session.state.task_state.town.get(d.id,false): target.node.modulate.a=.3; target.label=d.name+" · 已采集"
	for d in db.world_interactions.objects: add_marker(parent,"town-life",d.id,d.name,Vector2(d.point[0],d.point[1]))

func add_marker(parent: Node2D,kind: String,id: String,label: String,point: Vector2) -> Dictionary:
	var ring=Node2D.new(); ring.position=world.iso(point); parent.add_child(ring)
	var icon=Sprite2D.new(); icon.texture=WorldPresentation.texture("res://assets/refined-world/interaction.svg"); icon.scale=Vector2(.7,.43); icon.modulate=Color("d2b875"); ring.add_child(icon)
	world._caption(ring,label)
	var target={"kind":kind,"id":id,"label":label,"point":point,"node":ring,"width":60.0}; world.targets.append(target)
	return target

func clear_line(a: Vector2,b: Vector2) -> bool:
	var count=maxi(1,ceili(a.distance_to(b)/.15))
	for i in range(count+1):
		if not world._can_walk(a.lerp(b,float(i)/count)): return false
	return true

func process(delta: float):
	if world.blocked: return
	for target in world.targets:
		if target.kind=="town-life" and world.session.tasks.ledger.town.get(target.id,false): target.node.modulate.a=.3
	clock+=delta; discovery_clock+=delta
	for a in animals:
		a.time+=delta
		if a.time>=2.8:
			a.time=0; var angle=clock*.73+a.phase
			var candidate=a.home+Vector2(cos(angle),sin(angle))*.65
			a.destination=candidate if clear_line(a.target.point,candidate) else a.home
		var before=a.target.point
		a.target.point=before.move_toward(a.destination,delta*.45)
		var moved=before.distance_to(a.target.point)>.0001
		a.target.node.position=world.iso(a.target.point)
		if moved: a.target.node.flip_h=a.destination.x<a.target.point.x
		a.target.node.texture=world.texture(a.data.frames[1+int(clock*5)%2] if moved else a.data.frames[0])
	if discovery_clock<.2: return
	discovery_clock=0
	for e in world.db.world_interactions.entrances:
		if e.region!=world.scene_id or e.id in world.session.state.task_state.entrances: continue
		var p=Vector2(e.point[0],e.point[1])
		var screen=world.get_viewport().get_canvas_transform()*world.iso(p)
		if world.player.distance_to(p)<=3 and world.get_viewport_rect().has_point(screen) and clear_line(world.player,p): world.session.tasks.discover(e.id)
