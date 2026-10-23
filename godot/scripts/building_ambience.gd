class_name BuildingAmbience
extends Node2D

var world_ref: WeakRef
var clock=0.0
var tick=0.0

func setup(world): world_ref=weakref(world); z_index=2; queue_redraw()

func _process(delta: float):
	var world=world_ref.get_ref()
	if world==null or not world.visible or not world.is_processing(): return
	tick+=delta
	if tick<.05: return
	clock+=tick; tick=0; queue_redraw()

func _draw():
	var world=world_ref.get_ref()
	if world==null or world.db.is_outdoor(world.scene_id): return
	var phase=int(world.session.state.phase)
	if phase>=2: draw_rect(Rect2(0,0,1920,1080),Color("293b50",.06 if phase==2 else .15))
	var scene=world.scene_id
	for prop in world.session.progression.scene_props(scene):
		if not prop.has("building") and not prop.has("awakening"): continue
		var p=world.iso(Vector2(prop.x,prop.y))
		draw_arc(p,23,0,TAU,32,Color("d8bd85",.5),1.2,true)
		var diamond=PackedVector2Array([p+Vector2(0,-48),p+Vector2(9,-28),p+Vector2(0,-8),p+Vector2(-9,-28)])
		draw_colored_polygon(diamond,Color("d3bd90",.6)); draw_line(p-Vector2(0,18),p-Vector2(0,38),Color("f6e7bf"),1.5,true)
	if scene=="room-lighthouse":
		var center=world.iso(Vector2(4,3))-Vector2(0,130); var angle=-.3+sin(clock*.3)*.45
		draw_colored_polygon(PackedVector2Array([center,center+Vector2.from_angle(angle-.12)*450,center+Vector2.from_angle(angle+.12)*450]),Color("f4d997",.05 if phase<2 else .13))
	if scene=="room-grayforge" and not world.session.state.settings.reduce_motion:
		var center=world.iso(Vector2(5,3))-Vector2(0,60)
		for i in 7:
			var t=fposmod(clock*.5+i*.17,1); var pos=center+Vector2(sin(i*2.3)*45*t,-100*t)
			draw_circle(pos,1.5,Color("ffd38d",sin(t*PI)*.6))
