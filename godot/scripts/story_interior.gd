class_name StoryInterior
extends Node2D

var scene={}
var base=Color("c7baa0")
var painted=false

func setup(definition: Dictionary):
	scene=definition
	# Reuse the authored room art as native 2D floor/wall/furniture layers.
	# The fallback geometry below is for a missing optional illustration only.
	var path=str(scene.get("background",""))
	if ResourceLoader.exists(path):
		var texture_value=load(path) as Texture2D
		var zones=[{"name":"Walls","rect":Rect2(0,0,1920,270)},{"name":"FloorAndFurnishings","rect":Rect2(0,270,1920,810)}]
		for zone in zones:
			var layer=Polygon2D.new(); layer.name=zone.name; var r=zone.rect
			layer.polygon=PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
			var uvs=PackedVector2Array()
			for point in layer.polygon: uvs.append(point/Vector2(1920,1080)*texture_value.get_size())
			layer.uv=uvs; layer.texture=texture_value; layer.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; add_child(layer)
		painted=true
	base={"castle":Color("d8cfb7"),"church":Color("c7ccd1"),"academy":Color("b3bdc4"),"alchemy":Color("b1c1b7"),"forge":Color("b0a18e"),"harbor":Color("b2bfc0")}.get(scene.get("style","town"),Color("c9b89a"))
	z_index=-5; queue_redraw()

func p(x: float,y: float) -> Vector2: return WorldPresentation.iso(Vector2(x,y),scene.id)

func shape(points: Array,color: Color): draw_colored_polygon(PackedVector2Array(points),color)

func _draw():
	if scene.is_empty() or painted: return
	draw_rect(Rect2(0,0,1920,1080),Color("d9d4c9"))
	shape([p(0,0),p(10,0),p(10,10),p(0,10)],base)
	for y in 10:
		for x in 10:
			shape([p(x,y),p(x+1,y),p(x+1,y+1),p(x,y+1)],base.lightened(.05 if (x+y)%2==0 else -.025))
			draw_polyline(PackedVector2Array([p(x,y),p(x+1,y),p(x+1,y+1)]),Color(base.darkened(.15),.45),1,true)
	var height=Vector2(0,178)
	shape([p(0,0),p(10,0),p(10,0)-height,p(0,0)-height],base.lightened(.19))
	shape([p(0,0),p(0,10),p(0,10)-height,p(0,0)-height],base.darkened(.12))
	draw_line(p(0,0)-height,p(10,0)-height,Color("a89063"),7,true)
	draw_line(p(0,0)-height,p(0,10)-height,Color("a89063"),7,true)
	for i in [2,5,8]:
		var pos=p(i,0)-Vector2(0,125)
		shape([pos+Vector2(-33,-20),pos+Vector2(33,13),pos+Vector2(33,81),pos+Vector2(-33,48)],Color("6b8c9c"))
		shape([pos+Vector2(-25,-9),pos+Vector2(25,16),pos+Vector2(25,66),pos+Vector2(-25,41)],Color("dae6de"))
		var light=pos+Vector2(20,160)
		shape([light,light+Vector2(170,85),light+Vector2(105,120),light+Vector2(-65,35)],Color(1,.96,.77,.1))
	var carpet=base.lerp(Color("536b7c"),.6)
	shape([p(4,3),p(7,3),p(7,8),p(4,8)],carpet)
	draw_polyline(PackedVector2Array([p(4,3),p(7,3),p(7,8),p(4,8),p(4,3)]),Color("c4ab75"),4,true)
	for prop in scene.props: furniture(prop)

func furniture(prop: Dictionary):
	var x=float(prop.x); var y=float(prop.y); var name=str(prop.name)
	var height=48.0 if name.contains("桌") or name.contains("台") else 94.0
	var w=1.2; var d=.75
	var top=Color("a38d68") if name.contains("桌") or name.contains("架") else Color("aeb7b0")
	var a=p(x-w/2,y-d/2); var b=p(x+w/2,y-d/2); var c=p(x+w/2,y+d/2); var e=p(x-w/2,y+d/2); var h=Vector2(0,height)
	draw_set_transform(Vector2(10,7)); shape([a,b,c,e],Color(0,0,0,.17)); draw_set_transform(Vector2.ZERO)
	shape([e,c,c-h,e-h],top.darkened(.32)); shape([b,c,c-h,b-h],top.darkened(.16)); shape([a-h,b-h,c-h,e-h],top)
	if name.contains("书") or name.contains("簿") or name.contains("档"):
		for i in 6:
			var at=(e-h).lerp(c-h,(i+.5)/7.0)+Vector2(0,12)
			draw_line(at,at+Vector2(0,26),[Color("667687"),Color("8f6d62"),Color("c8b17e")][i%3],8)
	else:
		var center=(a+b+c+e)/4-h
		draw_circle(center,13,Color("e6ddbd")); draw_arc(center,14,0,TAU,20,Color("ad9163"),2,true)
