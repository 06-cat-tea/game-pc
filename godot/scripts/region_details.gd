class_name RegionDetails
extends Node2D

var region: Dictionary

func setup(data: Dictionary): region=data; queue_redraw()

func point(x: float,y: float) -> Vector2: return WorldPresentation.iso(Vector2(x,y),region.id)

func _draw():
	if region.is_empty(): return
	for b in region.bridges:
		var x=b.x-b.w/2; var y=b.y-b.d/2
		var corners=PackedVector2Array([point(x,y),point(x+b.w,y),point(x+b.w,y+b.d),point(x,y+b.d)])
		var uv=PackedVector2Array([Vector2(0,0),Vector2(2,0),Vector2(2,2),Vector2(0,2)])
		draw_polygon(corners,PackedColorArray([Color("e6dcc3") if region.id=="city" else Color("b9a47c")]),uv,WorldPresentation.texture(region.road))
		var length=b.w if region.id=="city" else b.d
		for i in range(1,int(length*2)):
			var offset=i*.5
			if region.id=="city": draw_line(point(x+offset,y),point(x+offset,y+b.d),Color("a19982"),1.2,true)
			else: draw_line(point(x,y+offset),point(x+b.w,y+offset),Color("705b43"),2,true)
		var rail_edges=[[0,1],[2,3]] if region.id=="city" else [[0,3],[1,2]]
		for edge in rail_edges:
			var a=corners[edge[0]]; var end=corners[edge[1]]
			draw_line(a,end,Color(0.2,0.22,0.20,.25),11,true)
			draw_colored_polygon(PackedVector2Array([a,end,end-Vector2(0,14),a-Vector2(0,14)]),Color("a59b81") if region.id=="city" else Color("887254"))
			draw_line(a-Vector2(0,18),end-Vector2(0,18),Color("e4d6b9") if region.id=="city" else Color("c7ae81"),5,true)
			for i in 6:
				var p=a.lerp(end,float(i)/5); draw_line(p,p-Vector2(0,22),Color("9d9073"),5,true); draw_circle(p-Vector2(0,23),4,Color("e8d5aa"))
	if region.id=="pass":
		for road in region.roads:
			if road.get("building_id","")!="deep-mine": continue
			var points=PackedVector2Array(); var other=PackedVector2Array()
			for p in road.points:
				var pos=point(p[0],p[1]); points.append(pos-Vector2(9,0)); other.append(pos+Vector2(9,0)); draw_line(pos-Vector2(16,-3),pos+Vector2(16,-3),Color("665344"),5,true)
			draw_polyline(points,Color("a8a29a"),3,true); draw_polyline(other,Color("a8a29a"),3,true)
