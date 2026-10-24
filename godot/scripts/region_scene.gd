class_name RegionScene
extends Node2D

var world_ref: WeakRef
var world:
	get: return world_ref.get_ref()
var region: Dictionary
var ground: RegionGround
var visuals=[]
var lights=[]
var residents=[]
var flags=[]
var particles: CPUParticles2D
var scene_clock=0.0
var tick=0.0
var capture=false
var backdrop: Polygon2D

func setup(view: WorldView, depth: Node2D):
	world_ref=weakref(view); region=RegionCatalog.get_region(view.scene_id)
	backdrop=Polygon2D.new(); var bounds=WorldPresentation.bounds(region.id).grow(4000)
	backdrop.polygon=PackedVector2Array([bounds.position,Vector2(bounds.end.x,bounds.position.y),bounds.end,Vector2(bounds.position.x,bounds.end.y)]); backdrop.color=Color(region.palette.fog); backdrop.z_index=-20; add_child(backdrop)
	ground=RegionGround.new(); ground.z_index=-5; add_child(ground); ground.setup(region.id)
	var details=RegionDetails.new(); details.z_index=-4; add_child(details); details.setup(region)
	for b in region.buildings:
		var pos=world.iso(Vector2(b.x+b.w/2,b.y+b.d/2)); var width=float(b.get("display_width",float(b.w+b.d)*58))
		var shadow=world._shadow(depth,pos,width*.88); var sprite=world._sprite(depth,b.art,pos,width,b.anchor)
		world._caption(sprite,b.name); world.targets.append({"kind":"building","id":b.id,"label":b.name,"point":Vector2(b.entry[0],b.entry[1]),"node":sprite,"width":width})
		visuals.append({"node":sprite,"shadow":shadow,"fade":true}); world.lighting.add_emission(sprite)
	for decor in region.decor:
		var pos=world.iso(Vector2(decor.point[0],decor.point[1])); var shadow=world._shadow(depth,pos,decor.width*.68)
		var sprite=world._sprite(depth,decor.asset,pos,decor.width,decor.anchor)
		visuals.append({"node":sprite,"shadow":shadow,"fade":decor.tall and decor.style!="lamp"})
		if decor.style=="banner":
			var flag_material=ShaderMaterial.new(); flag_material.shader=load("res://shaders/region_flag.gdshader"); sprite.material=flag_material; flags.append(flag_material)
		if decor.style=="lamp": world.lighting.add_source(Vector2(decor.point[0],decor.point[1]),Color("ffd28a"),250,1.0,sprite.texture.get_height()*sprite.scale.y*.84)
	var exit=Node2D.new(); exit.position=world.iso(Vector2(region.spawn[0],region.spawn[1]))+Vector2(-56,28); depth.add_child(exit)
	var icon=Sprite2D.new(); icon.texture=WorldPresentation.texture("res://assets/refined-world/interaction.svg"); icon.scale=Vector2(.5,.3); exit.add_child(icon); world._caption(exit,"返回晨星镇")
	world.targets.append({"kind":"travel","id":"town","label":"返回晨星镇","point":Vector2(region.spawn[0],region.spawn[1])+Vector2(0,1),"node":exit,"width":70.0})
	var ramp=Gradient.new(); ramp.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)]); var radial=GradientTexture2D.new(); radial.gradient=ramp; radial.fill=GradientTexture2D.FILL_RADIAL; radial.fill_from=Vector2(.5,.5); radial.fill_to=Vector2(1,.5); radial.width=256; radial.height=256
	if region.id!="city":
		for data in region.lights: world.lighting.add_source(Vector2(data.point[0],data.point[1]),Color(data.color),float(data.radius),maxf(.6,float(data.energy)*2.5),float(data.get("height",55)))
	for id in world.db.raw.npcs:
		var npc=world.db.raw.npcs[id]
		if npc.get("place","")==region.id and npc.has("position"): world._add_npc(depth,id,Vector2(npc.position.x,npc.position.y))
	particles=CPUParticles2D.new(); particles.amount=32 if region.id in ["wood","fen"] else 18; particles.lifetime=9; particles.preprocess=1; particles.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE; particles.emission_rect_extents=Vector2(920,580); particles.gravity=Vector2.ZERO; particles.direction=Vector2(-1,.4); particles.spread=22; particles.initial_velocity_min=7; particles.initial_velocity_max=19; particles.scale_amount_min=1; particles.scale_amount_max=2.8; particles.color=Color(region.palette.accent,.38); particles.texture=radial; particles.scale=Vector2.ONE*.018; particles.emission_rect_extents/=particles.scale.x; particles.z_index=3; add_child(particles)
	particles.initial_velocity_min/=particles.scale.x; particles.initial_velocity_max/=particles.scale.x
	_update_visibility()

func freeze_for_capture():
	world.lighting.freeze_for_map()
	capture=true; scene_clock=0; ground.set_clock(0); particles.hide(); set_process(false)
	backdrop.hide()
	for cell in ground.layers[0].get_used_cells():
		if cell.x<0 or cell.y<0 or cell.x>=region.columns or cell.y>=region.rows: ground.layers[0].erase_cell(cell)
	ground.layers[0].update_internals()
	for v in visuals: v.node.show(); v.node.modulate.a=1; v.shadow.show()
	for material_value in flags: material_value.set_shader_parameter("scene_clock",0.0)

func _process(delta: float):
	if world==null: return
	if not world.visible:
		particles.emitting=false; particles.speed_scale=0.0
		return
	var reduced=world.session.state.settings.reduce_motion; var stopped=world.blocked or reduced
	particles.visible=not reduced; particles.speed_scale=0.0 if stopped else 1.0; particles.emitting=not stopped
	if not stopped: scene_clock+=delta
	ground.set_clock(0.0 if reduced else scene_clock)
	for material_value in flags: material_value.set_shader_parameter("scene_clock",0.0 if reduced else scene_clock)
	particles.position=world.camera.position
	if not world.blocked:
		for resident in residents:
			if not resident.node.visible: continue
			var target=resident.data.points[resident.index]; var destination=Vector2(target[0],target[1]); var step=resident.point.move_toward(destination,delta*.65)
			if world._can_walk(step): resident.point=step
			else: resident.index=(resident.index+1)%resident.data.points.size()
			if resident.point.distance_to(destination)<.08: resident.index=(resident.index+1)%resident.data.points.size()
			resident.node.position=world.iso(resident.point); resident.shadow.position=resident.node.position+Vector2(6,5)
	tick+=delta
	if tick>.12: tick=0; _update_visibility()

func _update_visibility():
	if world==null: return
	var center=world.camera.position; var hero_pos=world.iso(world.player)
	for item in visuals:
		var node=item.node; var visible_now=absf(node.position.x-center.x)<1500 and absf(node.position.y-center.y)<1100
		node.visible=visible_now; item.shadow.visible=visible_now
		if not visible_now: continue
		var obscured=false
		if item.fade and node.texture!=null and hero_pos.y<node.position.y+10:
			var rect=Rect2(node.position+node.offset*node.scale,node.texture.get_size()*node.scale)
			obscured=rect.grow(-16).has_point(hero_pos-Vector2(0,35))
		node.modulate.a=.38 if obscured else 1.0
	for resident in residents:
		resident.node.visible=resident.node.position.distance_to(center)<1600; resident.shadow.visible=resident.node.visible
