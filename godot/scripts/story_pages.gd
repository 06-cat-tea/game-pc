class_name StoryPages
extends RefCounted

var game
var pages

func _init(owner, rail): game=owner; pages=rail

func build(kind: String, subject: String) -> bool:
	if kind=="journal": journal(); return true
	if kind in ["lore","people","achievements"]: library(kind); return true
	if kind=="building" and not game.db.raw.buildings.any(func(b): return b.id==subject): building(subject); return true
	if kind=="region-event": event(subject); return true
	if kind=="core-event": core_event(subject); return true
	if kind=="challenge": challenge(subject); return true
	if kind=="local-service": local_service(subject); return true
	if kind=="region-actions": actions(); return true
	return false

func _entry(id,title,text,tag,scene="",label="前往目标",callback=Callable()) -> Dictionary:
	return {"id":id,"name":title,"desc":text,"tag":tag,"scene":scene,"label":label,"callback":callback}

func collection(kind: String,title: String,entries: Array,categories: Array):
	var root=pages.shell(title); var state=pages.state(kind)
	if state.category=="all": state.category="全部"
	for i in categories.size():
		var category=categories[i]
		var button=UIkit.action(root,category,Vector2(0,i*66),Vector2(220,56),func(): state.category=category; game.replace_menu(kind))
		button.set_meta("ui_key","category:"+category); UIkit.selected(button,state.category==category)
	var filtered=entries.filter(func(e): return (state.category in ["all","全部"] and not (kind=="journal" and e.tag=="记录")) or e.tag==state.category)
	var archived=filtered.filter(func(e): return e.get("completed",false))
	var grouped=kind in ["journal","commission-board"]
	if grouped and not state.get("show_completed",false): filtered=filtered.filter(func(e): return not e.get("completed",false))
	if filtered.is_empty() and not archived.is_empty():
		UIkit.action(root,"已完成（%d）  ▸" % archived.size(),Vector2(260,100),Vector2(500,54),func(): state.show_completed=true; game.refresh_menu())
		return
	if filtered.is_empty(): UIkit.text(root,"这里还没有记录。",Vector2(260,100),Vector2(1500,100),28); return
	if not filtered.any(func(e): return e.id==state.selection): state.selection=filtered[0].id
	var list=UIkit.scroll_at(root,Vector2(260,0),Vector2(500,788)); var selected=filtered[0]
	var archive_header=false
	for e in filtered:
		if grouped and e.get("completed",false) and not archive_header:
			archive_header=true
			UIkit.button(list,"已完成（%d）  ▾" % archived.size(),func(): state.show_completed=false; game.refresh_menu())
		var button=UIkit.button(list,("✧  " if e.id==state.selection else "    ")+e.tag+" / "+e.name,func(): state.selection=e.id; game.replace_menu(kind)); button.custom_minimum_size.y=74; button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; button.set_meta("ui_key","entry:"+e.id); UIkit.selected(button,e.id==state.selection)
		if e.id==state.selection: selected=e
	if grouped and not archived.is_empty() and not state.get("show_completed",false): UIkit.button(list,"已完成（%d）  ▸" % archived.size(),func(): state.show_completed=true; game.refresh_menu())
	var detail=UIkit.card(root,Vector2(800,0),Vector2(992,788),Color(UIkit.NIGHT,.62) if UIkit.is_dark(root) else Color(UIkit.PAPER,.7))
	UIkit.text(detail,selected.tag,Vector2(36,26),Vector2(920,36),22,UIkit.GOLD)
	UIkit.text(detail,selected.name,Vector2(36,80),Vector2(920,88),36)
	var body=UIkit.scroll_at(detail,Vector2(36,172),Vector2(920,390)); UIkit.label(body,selected.desc,25)
	var reward_icons={}
	for key in selected.get("reward",{}):
		if key in ["gold","herb","ore","shard"]: reward_icons[key]=selected.reward[key]
	if not reward_icons.is_empty(): ItemIcons.strip(detail,game.db,reward_icons,Vector2(36,566),190)
	var callback=selected.callback
	if callback.is_valid() or selected.scene!="":
		UIkit.action(detail,selected.label,Vector2(36,690),Vector2(920,58),func():
			if callback.is_valid(): callback.call()
			else: await game.travel_to(selected.scene),true,game.session.state.battle!=null or game.session.state.training)

func journal():
	game.menus.quest_pages.journal()

func rewards(value: Dictionary) -> String:
	var result=[]
	for key in value:
		result.append(game.db.raw.items[value[key]].name if key=="item" else str({"xp":"经验","gold":"金币","rep":"声望"}.get(key,key))+" "+str(int(value[key]) if value[key] is float and value[key]==floor(value[key]) else value[key]))
	return " · ".join(result)

func main_target() -> String:
	return ["room-clocktower","wood","room-clocktower","pass","pass","fen","fen","room-clocktower","room-clocktower"][int(game.session.state.story.stage)]

func quest_target(id: String) -> String:
	return {"pages":"wood","roots":"wood","herbs":"wood","caravan":"pass","candle":"fen","moon":"fen-temple","pact":"fen-crypt","names":"fen-crypt","wreck":"coast","letters":"room-lighthouse"}.get(id,"town")

func prop_scene(key: String) -> String:
	for id in game.db.raw.scenes:
		var d=game.db.raw.scenes[id]
		for p in d.props:
			if str(d.get("occupantKey",d.get("buildingId",id)))+":"+p.id==key: return id
	return "town"

func library(kind: String):
	var db=game.db; var s=game.session.state; var entries=[]; var categories=["全部"]
	if kind=="lore":
		categories.append_array(["世界志","装备来历"])
		for d in db.narrative.lore:
			entries.append(_entry(d.id,d.title,d.sub+"\n\n"+("\n\n".join(d.paragraphs) if s.story.stage>=d.min else "继续星钟调查后解锁这篇记录。"),"世界志"))
		for id in db.narrative.origins: entries.append(_entry("item:"+id,db.raw.items[id].name,db.narrative.origins[id],"装备来历"))
	elif kind=="people":
		for place in GameContent.OUTDOORS: categories.append(db.location_title(place))
		for id in db.raw.npcs:
			var n=db.raw.npcs[id]; var place=n.get("place","")
			if place=="":
				for scene in db.narrative.indoor:
					if db.scene_npcs(scene).any(func(p): return p.id==id): place=db.place_of(scene); break
			var text=n.get("role","")+"\n\n"+n.get("line","")+"\n\n"+db.raw.companions.get(id,{}).get("bio","")+"\n\n"+n.get("task","")+"\n好感：%d / 100" % s.affinity[id].value
			for topic in db.raw.dialogues[id]:
				var t=db.raw.dialogues[id][topic]
				text+="\n\n"+t.title+"\n"+("\n".join(t.intro)+"\n"+t.end if s.affinity[id].value>=t.min else "好感达到 %d 后解锁。" % t.min)
			entries.append(_entry(id,n.name,text,db.location_title(place),"","前往交谈",func(): seek_npc(id)))
	else:
		categories.append("旅途成就")
		for a in db.narrative.achievements:
			var status="已领取" if a.id in s.story.claimed else "已达成" if game.session.story.achievement_complete(a.id) else "未达成"
			entries.append(_entry(a.id,a.name,a.desc+"\n\n"+status+"\n奖励：金币 %d、星屑 1" % a.gold,"旅途成就","","领取奖励",func(): game.toast(game.session.story.claim(a.id)); game.replace_menu("achievements")))
	collection(kind,{"lore":"世界志","people":"人物档案","achievements":"旅途成就"}[kind],entries,categories)

func seek_npc(id: String):
	var npc=game.db.raw.npcs[id]; var scene=npc.get("place","")
	if scene=="":
		for candidate in game.db.narrative.indoor:
			if game.db.scene_npcs(candidate).any(func(n): return n.id==id): scene=candidate; break
	game.seek(scene,"npc",id)

func building(id: String):
	var b=game.db.building(id); var root=pages.shell(b.get("name","地点")); var body=UIkit.scroll_at(root,Vector2.ZERO,Vector2(1792,788))
	UIkit.label(body,b.description,28)
	if game.db.progression.buildings.has(id): UIkit.button(body,"✧ "+game.db.progression.buildings[id].name,func(): game.open_menu("building-service",id))
	var discovery="building:"+id
	if discovery not in game.session.state.story.discovered: game.session.state.story.discovered.append(discovery)
	var scene="room-"+id
	if game.db.raw.scenes.has(scene): UIkit.button(body,"进入内室 · "+game.db.raw.scenes[scene].title,func(): await game.travel_to(scene))
	var route=game.db.narrative.entrances.get(id,"")
	if route!="" and route!=scene: UIkit.button(body,"探索路线 · "+game.db.raw.scenes[route].title,func(): await game.travel_to(route))
	if b.get("talk",null)!=null: UIkit.button(body,"交谈",func(): game.open_menu("npc",b.talk))
	var action=b.get("action",null)
	if action!=null: UIkit.button(body,"地点行动 · "+action_name(action),func(): perform_activity(action))
	UIkit.button(body,"查看当地行动与事件",func(): game.open_menu("region-actions"))

func action_name(id: String) -> String:
	for place in game.db.narrative.places.values():
		for a in place.actions:
			if a[0]==id: return a[1]
	return str(game.db.narrative.services.get(id.get_slice(":",1),{}).get("name",id))

func perform_activity(id: String):
	if id=="city:guide": game.menus.pages.state("map").region="city"; game.menus.pages.state("map").category="region"; game.open_menu("map"); return
	if id=="city:archive": game.open_menu("lore"); return
	if id=="city:music": game.message("水园小调",game.db.narrative.places.city.desc,"region-actions"); return
	if id.begins_with("world:") or id.begins_with("city:"): game.open_menu("local-service",id); return
	if id in ["tavern","lighthouse"]: game.open_menu("core-event",id); return
	if id in ["market","forge"]: game.open_menu("shop","forge" if id=="forge" else "hero"); return
	var text=game.session.story.activity(id)
	if game.session.state.battle!=null: game.close_menu(); game.refresh()
	else: game.message(action_name(id),text,"region-actions")

func actions():
	var place=game.session.story.place(); var db=game.db; var root=pages.shell(db.location_title(place)+" · 地点行动"); var body=UIkit.scroll_at(root,Vector2.ZERO,Vector2(1792,788))
	for id in db.progression.buildings:
		if db.progression.buildings[id].place==place: UIkit.button(body,"✧ 六地见闻 · "+db.building(id).name,func(): game.open_menu("building-service",id))
	for a in db.narrative.places[place].actions: UIkit.button(body,a[1]+"  /  "+a[2],func(): perform_activity(a[0]))
	if place=="town": UIkit.button(body,"礼拜堂 · 祈愿与旧事",func(): game.open_menu("core-event","prayer"))
	for id in db.narrative.events:
		var event=db.narrative.events[id]
		if event.place==place: UIkit.button(body,"旅途插曲 · "+event.title,func(): game.open_menu("region-event",id),game.session.state.story.events.has(id))
	for id in db.narrative.challenges:
		var c=db.narrative.challenges[id]
		if c.place==place: UIkit.button(body,"挑战 Lv.%d · %s" % [c.level,c.name],func(): game.open_menu("challenge",id))
	for b in db.narrative.buildings:
		if b.place==place and str(b.get("action","")).begins_with("world:"): UIkit.button(body,action_name(b.action),func(): perform_activity(b.action))
	for npc in db.scene_npcs(game.session.state.location.scene):
		if str(npc.get("service","")).begins_with("world:"): UIkit.button(body,action_name(npc.service),func(): perform_activity(npc.service))
	if place=="city":
		for key in db.narrative.cityServices:
			var service=db.narrative.cityServices[key]
			UIkit.button(body,service.name+" · "+service.description,func():
				if key=="guide": game.open_menu("map")
				elif key=="archive": game.open_menu("lore")
				elif key=="music": game.message(service.name,db.narrative.places.city.desc,"region-actions")
				else: perform_activity("city:"+key))

func event(id: String):
	var e=game.db.narrative.events[id]; var root=pages.shell(e.title); var body=UIkit.scroll_at(root,Vector2.ZERO,Vector2(1792,788)); UIkit.label(body,e.body,29)
	for i in e.options.size():
		var option=e.options[i]
		UIkit.button(body,option.name+" · "+option.desc,func(): game.message(e.title,game.session.story.choose_event(id,i),"region-actions"),game.session.state.story.events.has(id))

func core_event(id: String):
	var e=game.db.narrative.coreEvents[id]; var root=pages.shell(e.title); var body=UIkit.scroll_at(root,Vector2.ZERO,Vector2(1792,788)); UIkit.label(body,e.body,29)
	for option in e.options:
		UIkit.button(body,option[1]+" · "+option[2],func(): game.message(e.title,game.session.story.core_event(id,option[0]),"region-actions"),game.session.state.story.events.has("core:"+id+":"+option[0]))

func challenge(id: String):
	var c=game.db.narrative.challenges[id]; var root=pages.shell(c.name)
	UIkit.text(root,"区域挑战  /  推荐等级 %d" % c.level,Vector2(24,36),Vector2(1660,64),32,UIkit.GOLD)
	UIkit.text(root,c.line,Vector2(24,150),Vector2(1660,160),30)
	var rows=[]
	for foe in game.db.encounters[id].enemies:
		var weaknesses=[]
		for element in foe.weakness: weaknesses.append(GameContent.ELEMENT_NAMES[element])
		rows.append(foe.name+" · "+GameContent.ELEMENT_NAMES[foe.get("affinity","physical")]+" · 弱点 "+" / ".join(weaknesses))
	UIkit.text(root,"\n".join(rows),Vector2(24,478),Vector2(1660,150),23,UIkit.MUTED)
	var text="半血进入第二阶段；首次胜利保证获得 "+game.db.raw.items[c.item].name if c.get("boss",false) else "招式每三回合轮换，观察预告再行动。"
	UIkit.text(root,text,Vector2(24,360),Vector2(1660,100),26)
	UIkit.action(root,"准备交战",Vector2(24,662),Vector2(1700,64),func(): game.load_encounter(id),true,game.session.state.battle!=null or game.session.state.training)

func local_service(id: String):
	var info=game.session.story.service_info(id)
	if info.is_empty(): return
	var root=pages.shell(info.name)
	UIkit.text(root,game.db.location_title(game.session.story.place())+" / 居民服务",Vector2(32,28),Vector2(1700,50),27,UIkit.GOLD)
	UIkit.text(root,info.description,Vector2(32,146),Vector2(1700,120),33)
	var costs=[]
	for key in info.cost:
		if info.cost[key]>0: costs.append({"gold":"金币","supplies":"旅行补给","herb":"草药","ore":"矿石","shard":"星屑"}.get(key,key)+" "+str(info.cost[key]))
	UIkit.text(root,"实际消耗："+(" · ".join(costs) if not costs.is_empty() else "免费"),Vector2(32,332),Vector2(1700,60),29)
	UIkit.text(root,"仅可完成一次" if info.once else "每日一次" if info.daily else "可重复使用",Vector2(32,430),Vector2(1700,60),24,UIkit.MUTED)
	UIkit.action(root,"确认使用服务",Vector2(32,658),Vector2(1700,64),func():
		var text=game.session.service(id,info.owner) if info.owner!="" else game.session.story.service(id)
		game.toast(text); game.replace_menu("local-service",id),true,info.unavailable or game.session.state.battle!=null or game.session.state.training)
