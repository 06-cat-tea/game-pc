class_name CombatEffects
extends Control

var game_ref: WeakRef
var seen={}
var battle_id=""
var visuals=[]
var elapsed=0.0
var duration=0.0
var anchors={}
var reduced=false

func setup(owner):
	game_ref=weakref(owner); UIkit.fill(self); mouse_filter=Control.MOUSE_FILTER_IGNORE

func reset():
	seen={}; visuals=[]; battle_id=""; elapsed=0; queue_redraw()

func play(packet: Array, positions: Dictionary, reduce_motion: bool) -> float:
	var id=""
	for event in packet:
		if event.has("event_id"): id=str(event.event_id).rsplit(":",true,1)[0]; break
	var owner=game_ref.get_ref()
	var current=str(owner.session.engine.battle.get("instance_id",id))
	if current!=battle_id: seen={}; battle_id=current
	var fresh=[]
	for event in packet:
		if str(event.get("event_id",""))!="" and not seen.has(str(event.event_id)): fresh.append(event)
	if fresh.is_empty(): return 0.0
	visuals=[]; anchors=positions.duplicate(); elapsed=0; reduced=reduce_motion
	var ultimate=false
	var ultimate_duration=1.0
	for event in fresh:
		var key=str(event.get("event_id",""))
		if key=="" or seen.has(key): continue
		seen[key]=true
		if event.kind in ["cast","damage","heal","revive","status","mana","dot","break","shield_absorb","shield_break","formation"]:
			visuals.append(event.duplicate(true))
			if event.get("action","")=="ultimate":
				ultimate=true; ultimate_duration={"hero":1.0,"mira":1.05,"toren":.9,"sylvi":1.0,"ridge-scout":.9,"eira":1.1,"alchemist":1.0}.get(event.get("caster",""),1.0)
	duration=.12 if reduced else ultimate_duration if ultimate else .55
	queue_redraw()
	return duration if not visuals.is_empty() else 0.0

func _process(delta: float):
	var game=game_ref.get_ref() if game_ref!=null else null
	if visuals.is_empty() or (game!=null and game.paused): return
	elapsed+=delta
	if elapsed>=duration: visuals=[]
	queue_redraw()

func point(id: String, fallback: Vector2 = Vector2(960,440)) -> Vector2:
	return anchors.get(id,fallback)

func star(center: Vector2, radius: float, color: Color, rays: int = 4):
	var vertices=PackedVector2Array()
	for i in rays*2:
		vertices.append(center+Vector2.from_angle(-PI/2+i*PI/rays)*radius*(1 if i%2==0 else .25))
	draw_colored_polygon(vertices,color)

func _draw():
	if visuals.is_empty(): return
	var t=clampf(elapsed/maxf(.01,duration),0,1); var fade=sin(t*PI)
	for event in visuals:
		var target=point(str(event.get("target",""))); var origin=point(str(event.get("actor","")),target-Vector2(140,0))
		var element=str(event.get("element","physical"))
		var tint=Color({"physical":"d9c08a","astral":"b9a9ed","fire":"edb27a","poison":"79bdb1","holy":"eddfae"}.get(element,"d9c08a"),fade)
		if event.kind=="cast":
			if event.get("action","")=="ultimate":
				var game=game_ref.get_ref(); var d=game.db.progression.ultimates.get(event.actor,{})
				tint=Color(d.get("color","#d5b773"),fade)
				var center=Vector2(960,370)
				if not reduced:
					for ring in 2: draw_arc(center,110+ring*35+t*18,-PI*.9+ring*.4,PI*.65+ring*.4,64,Color(tint,.22*fade),2,true)
					star(center,76+sin(t*PI)*20,Color(tint,.25*fade))
					match str(event.actor):
						"hero":
							for i in 5:
								var p=center+Vector2((i-2)*40,-170+t*210); draw_line(p-Vector2(22,55),p,tint,2,true); star(p,6,tint)
						"mira":
							var points=PackedVector2Array()
							for i in 6: points.append(center+Vector2.from_angle(-PI/2+i*TAU/5)*130); star(points[-1],5,tint)
							draw_polyline(points,tint,1.5,true)
						"toren":
							var points=PackedVector2Array()
							for i in 7: points.append(center+Vector2.from_angle(-PI/2+i*TAU/6)*(100+t*20))
							draw_polyline(points,tint,3,true)
						"sylvi":
							for i in 6:
								var p=center+Vector2.from_angle(i*TAU/6)*105; draw_arc(p,27,-PI*.8,PI*.4,20,tint,2,true)
						"ridge-scout":
							for i in 3: draw_line(center+Vector2(-140,-70+i*42),center+Vector2(140,25+i*42),tint,3-i*.7,true)
						"eira":
							for i in 7:
								var p=center+Vector2((i-3)*32,70-t*60); draw_line(p-Vector2(0,80),p,Color(tint,.4*fade),2,true); star(p,7,tint)
						"alchemist":
							for i in 8: draw_circle(center+Vector2(cos(i*2.4)*115,sin(i*2.4)*80-t*28),5+i%3,tint,false,1.5,true)
				var emblem=UIkit.icon("ultimate-"+str(event.actor))
				if emblem!=null: draw_texture_rect(emblem,Rect2(center-Vector2(45,45),Vector2(90,90)),false,Color(1,1,1,fade))
				draw_style_box(UIkit.button_style(Color("263440",fade*.86),Color("cbb889",fade),8),Rect2(640,183,640,58))
				draw_string(UIkit.font(),Vector2(680,224),str(event.get("label","觉醒")),HORIZONTAL_ALIGNMENT_CENTER,560,28,Color("f3e5c5",fade))
			elif not reduced: draw_arc(origin,42+t*26,-PI,PI,40,Color(tint,.45*fade),2,true)
			continue
		if event.kind in ["damage","dot"]:
			if not reduced:
				if element=="physical":
					if event.get("ranged",false):
						var head=origin.lerp(target,minf(1,t*3)); var direction=(target-origin).normalized()
						draw_line(head-direction*70,head,tint,2,true)
						draw_line(head-direction.rotated(.55)*12,head,tint,2,true); draw_line(head-direction.rotated(-.55)*12,head,tint,2,true)
					else:
						draw_line(target+Vector2(-55,-38)*(1-t),target+Vector2(48,34),tint,5*(1-t)+1,true)
						draw_arc(target,35+t*40,-PI*.85,PI*.1,30,tint,3,true)
				elif element=="poison":
					for i in 7:
						var p=target+Vector2(cos(i*2.4)*45,sin(i*2.4)*22-t*60); draw_circle(p,5+(i%3)*3,Color(tint,.65*fade))
				else:
					draw_line(origin.lerp(target,minf(1,t*3)),target,tint,3,true)
					star(target,28+t*50,Color(tint,.55*fade),6 if element=="fire" else 4)
					if element=="fire":
						for i in 6: draw_circle(target+Vector2(sin(i*2.4)*32,-t*65+i%2*15),4+i%3,Color(tint,.5*fade))
				draw_arc(target,30+t*55,0,TAU,48,Color(tint,.65*fade),2,true)
			draw_string(UIkit.font(),target+Vector2(-55,-35-t*45),"−"+str(event.value),HORIZONTAL_ALIGNMENT_CENTER,110,34,Color("77453b",fade))
		elif event.kind in ["heal","revive","mana"]:
			var glow=Color("90bca6",fade) if event.kind!="mana" else Color("8eafce",fade)
			if event.get("caster","")=="eira": glow=Color("dfc98b",fade)
			if not reduced:
				draw_arc(target,30+t*45,0,TAU,48,glow,2,true)
				for i in 3:
					var p=target+Vector2((i-1)*29,-25-t*65); draw_line(p-Vector2(8,0),p+Vector2(8,0),glow,2,true); draw_line(p-Vector2(0,8),p+Vector2(0,8),glow,2,true)
			draw_string(UIkit.font(),target+Vector2(-55,-35-t*45),"+"+str(event.value),HORIZONTAL_ALIGNMENT_CENTER,110,30,Color("527f69",fade))
		elif event.kind in ["shield_absorb","shield_break"]:
			draw_string(UIkit.font(),target+Vector2(-80,-35-t*30),("护盾 -%d" % event.value) if event.kind=="shield_absorb" else "护盾破裂",HORIZONTAL_ALIGNMENT_CENTER,160,21,Color("6b969e",fade))
		elif event.kind in ["status","break"]:
			var shield=event.get("effect","")=="shield"
			if not reduced:
				var points=PackedVector2Array()
				for i in 7: points.append(target+Vector2.from_angle(-PI/2+i*TAU/6)*(64 if shield else 45))
				draw_polyline(points,Color(tint,.6*fade),3 if shield else 1.5,true)
			draw_string(UIkit.font(),target+Vector2(-70,12-t*20),"韧性击破" if event.kind=="break" else BattleEngine.EFFECT_NAMES.get(event.get("effect",""),"状态"),HORIZONTAL_ALIGNMENT_CENTER,140,22,Color("877143",fade))
