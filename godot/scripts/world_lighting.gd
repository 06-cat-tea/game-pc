class_name WorldLighting
extends Node2D

# One world canvas modulation, independent of the HUD's CanvasLayer.
static var config: Dictionary = {}
var world_ref: WeakRef
var ambient: CanvasModulate
var sources=[]
var emissions=[]
var halo_texture: GradientTexture2D
var strength=0.0
var phase=-1
var desired: Color
var desired_strength=0.0
var tick=0.0
var frozen=false
var hero_light: PointLight2D

static func settings() -> Dictionary:
	if config.is_empty(): config=JSON.parse_string(FileAccess.get_file_as_string("res://data/daylight.json"))
	return config

func setup(view: WorldView):
	world_ref=weakref(view)
	var gradient=Gradient.new(); gradient.offsets=PackedFloat32Array([0.0,.12,.45,1.0]); gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,.65),Color(1,1,1,.15),Color(1,1,1,0)])
	halo_texture=GradientTexture2D.new(); halo_texture.gradient=gradient; halo_texture.fill=GradientTexture2D.FILL_RADIAL; halo_texture.fill_from=Vector2(.5,.5); halo_texture.fill_to=Vector2(1,.5); halo_texture.width=256; halo_texture.height=256
	ambient=CanvasModulate.new(); add_child(ambient)
	if view.db.is_outdoor(view.scene_id):
		hero_light=PointLight2D.new(); hero_light.texture=halo_texture; hero_light.color=Color("b8ceec"); hero_light.texture_scale=1.3; hero_light.energy=.34; add_child(hero_light)
	_sync_phase(true); update_lights()

func add_emission(sprite: Sprite2D):
	var zones=settings().emission_zones.get(sprite.texture.resource_path,[])
	if zones.is_empty(): return
	var windows=PackedVector4Array()
	for r in zones: windows.append(Vector4(r[0],r[1],r[2],r[3]))
	while windows.size()<8: windows.append(Vector4.ZERO)
	var emission=Sprite2D.new(); emission.texture=sprite.texture; emission.centered=false; emission.offset=sprite.offset
	var material_value=ShaderMaterial.new(); material_value.shader=load("res://shaders/window_emission.gdshader"); material_value.set_shader_parameter("night_strength",strength); material_value.set_shader_parameter("windows",windows); emission.material=material_value
	sprite.add_child(emission); emissions.append(material_value)

func add_source(point: Vector2, color_value: Color, radius: float, energy: float, height: float=70.0):
	var view=world_ref.get_ref()
	var base=view.iso(point)
	var light=PointLight2D.new(); light.texture=halo_texture; light.color=color_value; light.texture_scale=radius/128.0; light.position=base-Vector2(0,height*.30); light.energy=energy; light.enabled=false; add_child(light)
	var pool=Sprite2D.new(); pool.texture=halo_texture; pool.position=base; pool.scale=Vector2(radius/128.0,radius/330.0)
	var add_material=CanvasItemMaterial.new(); add_material.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD; add_material.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED; pool.material=add_material; pool.z_index=1; add_child(pool)
	var flare=Sprite2D.new(); flare.texture=halo_texture; flare.position=base-Vector2(0,height); flare.scale=Vector2(.20,.25); flare.material=add_material; flare.z_index=2; add_child(flare)
	sources.append({"light":light,"pool":pool,"flare":flare,"energy":energy,"color":color_value,"point":point})

func _sync_phase(immediate: bool=false):
	var view=world_ref.get_ref()
	if view==null: return
	var current=int(view.session.state.phase)
	if phase!=current or immediate:
		phase=current; var data=settings(); var outdoor=view.db.is_outdoor(view.scene_id)
		if outdoor:
			var p=data.phases[phase]; desired=Color(p.ambient)*Color(data.regions[view.scene_id].tint); desired_strength=float(p.lamps)
		else:
			desired=Color(data.interior.night_ambient if phase==3 else data.interior.ambient); desired_strength=0.0
		if immediate or view.session.state.settings.reduce_motion: ambient.color=desired; strength=desired_strength
	if view.session.state.settings.reduce_motion: ambient.color=desired; strength=desired_strength

func _process(delta: float):
	var view=world_ref.get_ref()
	if view==null or frozen: return
	_sync_phase()
	var weight=minf(1.0,delta*4.0/float(settings().transition_seconds))
	ambient.color=ambient.color.lerp(desired,weight); strength=lerpf(strength,desired_strength,weight)
	for material_value in emissions: material_value.set_shader_parameter("night_strength",strength)
	if hero_light!=null:
		hero_light.position=view.iso(view.player)-Vector2(0,28); hero_light.energy=.34*strength; hero_light.enabled=strength>.01
	tick+=delta
	if tick>=.12: tick=0.0; update_lights()

func update_lights():
	var view=world_ref.get_ref()
	if view==null: return
	var center=view.camera.position
	var nearest=sources.duplicate(); nearest.sort_custom(func(a,b): return a.light.position.distance_squared_to(center)<b.light.position.distance_squared_to(center))
	for source in sources:
		source.light.enabled=false
		var visible_now=source.pool.position.distance_to(center)<1700 and strength>.01
		source.pool.visible=visible_now; source.flare.visible=visible_now
		source.pool.modulate=Color(source.color,strength*.22); source.flare.modulate=Color(source.color,strength*.80)
	# Seven scene lights plus the small hero fill never exceed eight active lights.
	for source in nearest.slice(0,7):
		source.light.enabled=strength>.01 and source.light.position.distance_to(center)<1300
		source.light.energy=source.energy*strength
	if view.region_layer!=null:
		var positions=PackedVector2Array()
		for source in nearest.slice(0,7): positions.append(source.point)
		while positions.size()<8: positions.append(Vector2(-1000,-1000))
		for material_value in view.region_layer.ground.materials:
			material_value.set_shader_parameter("night_strength",strength); material_value.set_shader_parameter("lamp_positions",positions)

func freeze_for_map():
	# Maps always bake in neutral daylight, independent of the player's current time.
	frozen=true; ambient.color=Color("fffdf5"); strength=0.0
	for material_value in emissions: material_value.set_shader_parameter("night_strength",0.0)
	for source in sources: source.light.enabled=false; source.pool.hide(); source.flare.hide()
	if hero_light!=null: hero_light.enabled=false
	var view=world_ref.get_ref()
	if view!=null and view.region_layer!=null:
		for material_value in view.region_layer.ground.materials: material_value.set_shader_parameter("night_strength",0.0)
