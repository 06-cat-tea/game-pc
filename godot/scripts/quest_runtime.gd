class_name QuestRuntime
extends RefCounted

var reference: WeakRef
var game:
	get: return reference.get_ref()
var db:
	get: return game.db
var s:
	get: return game.state
var catalog:
	get: return db.quest_catalog.tasks
var ledger:
	get: return s.task_state

func _init(owner): reference=weakref(owner)

func initialize(fresh: bool = false):
	if s.has("task_state"): return
	s.task_state={"revision":1,"sequence":0,"records":{},"entrances":[],"town":{},"tokens":{},"battle_events":[]}
	if fresh: return
	# Old v1 quests were already accepted; completion means rewards already paid.
	for id in catalog:
		var q=legacy(id)
		if not q.is_empty(): _register(id)
	for e in db.world_interactions.entrances:
		if s.scene_progress.get(e.scene+":survey",false) or s.location.scene==e.scene:
			if e.id not in ledger.entrances: ledger.entrances.append(e.id)
	for id in s.story.awakenings:
		if int(s.story.awakenings[id].stage)>0 and not s.story.awakenings[id].has("order"):
			ledger.sequence+=1; s.story.awakenings[id].order=ledger.sequence

func definition(id: String) -> Dictionary:
	if not catalog.has(id): return {}
	var d=catalog[id].duplicate(true); var ref=str(d.get("ref","")); var group=ref.get_slice(":",0); var key=ref.get_slice(":",1)
	if group in ["quests","regional","expeditions"]:
		var original=db.narrative[group][key]
		for field in ["name","desc","reward","goal","steps"]:
			if original.has(field): d[field]=original[field]
	elif group=="personal":
		d.name=db.raw.personal[key].name; d.desc="调查两处传承线索，返回本人交付；完成后开放职业传承。"; d.reward={"xp":260,"gold":55}; d.goal=2
	elif group=="service":
		var site=db.progression.buildings[key]; d.name=site.name; d.desc="在"+db.building(key).name+"接取并完成这项服务。"; d.reward={"xp":site.get("xp",0),"gold":site.get("gold",0)}; d.goal=1
	if not d.has("desc"): d.desc="\n".join(d.get("steps",[]))
	return d

func legacy(id: String) -> Dictionary:
	if id=="first": return s.quests.first
	var kind=id.get_slice(":",0); var key=id.get_slice(":",1)
	if kind=="quest": return s.story.quests.get(key,{})
	if kind in ["regional","expeditions"]: return s.story[kind].get(key,{})
	if kind=="personal": return s.personal.get(key,{})
	if kind=="service" and s.story.building_services.get(key,false): return {"done":true}
	return {}

func _register(id: String):
	if ledger.records.has(id): return
	ledger.sequence+=1; ledger.records[id]={"order":ledger.sequence,"stage":0,"done":false}

func accepted(id: String) -> bool: return ledger.records.has(id)

func published(id: String) -> bool:
	if not catalog.has(id): return false
	var d=catalog[id]
	if accepted(id): return true
	if d.get("requires","")!="" and status(d.requires)!="completed": return false
	if d.get("discover","")!="" and d.discover not in ledger.entrances: return false
	if d.get("unlocked","")!="" and not entrance_unlocked(entrance_for(d.unlocked)): return false
	return true

func record(id: String) -> Dictionary:
	var q=legacy(id)
	return q if not q.is_empty() else ledger.records.get(id,{})

func stage(id: String) -> int:
	var q=record(id)
	return int(q.get("stage",q.get("progress",0)))

func goal(id: String) -> int:
	var d=definition(id)
	if id.begins_with("regional:"): return 2
	if id.begins_with("expeditions:"): return 3
	return int(d.get("goal",d.get("steps",[]).size()))

func status(id: String) -> String:
	if not accepted(id): return "available" if published(id) else "hidden"
	var d=definition(id); var q=record(id)
	if q.get("done",false) or ledger.records[id].get("done",false): return "completed"
	if not d.get("materials",{}).is_empty():
		for material in d.materials:
			if s.materials.get(material,0)<d.materials[material]: return "active"
		if id.begins_with("personal:") and stage(id)<2: return "active"
		return "ready"
	if id.begins_with("service:"):
		var site=db.progression.buildings[id.get_slice(":",1)]
		if site.type=="order": return "ready" if s.flags.get("crafted:"+site.recipe,false) else "active"
		return "ready" if ledger.records[id].get("stage",0)>=1 else "active"
	return "ready" if stage(id)>=goal(id) else "active"

func context_allowed(id: String, source: String) -> bool:
	var d=definition(id)
	if source=="board": return d.get("board",false) and s.location.scene=="room-guildhall"
	if source.begins_with("entrance-"):
		var e=entrance(source)
		return id=="expeditions:"+e.get("region","") and s.location.scene==e.get("region","") and Vector2(s.location.x,s.location.y).distance_to(Vector2(e.point[0],e.point[1]))<3
	if source.begins_with("service:"): return id==source and game.progression.at_site(source.get_slice(":",1))
	return source==d.giver and game.story.can_meet(source)

func accept(id: String, source: String) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	if not published(id): return "这份委托尚未发布。"
	if accepted(id): return "这份委托已经接取。"
	if not context_allowed(id,source): return "请前往委托板、委托人或已发现的入口接取。"
	_register(id)
	var kind=id.get_slice(":",0); var key=id.get_slice(":",1)
	if kind=="quest": s.story.quests[key]={"progress":0,"done":false}
	elif kind in ["regional","expeditions"]: s.story[kind][key]={"stage":0,"done":false}
	elif kind=="personal": s.personal[key]={"stage":0,"done":false}
	var d=definition(id)
	for token in d.get("grants",{}): ledger.tokens[token]=int(ledger.tokens.get(token,0))+int(d.grants[token])
	game.log_message("已接取「"+d.name+"」。完成目标后返回交付。")
	return game.last_message

func turn_in(id: String, source: String) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	if status(id)!="ready": return "目标尚未达成，或奖励已经领取。"
	var d=definition(id); var destination=d.turnin
	if source!=destination or (source=="board" and s.location.scene!="room-guildhall"): return "请返回指定委托人或委托板交付。"
	if source.begins_with("service:"):
		if not game.progression.at_site(source.get_slice(":",1)): return "请返回对应建筑交付。"
	elif source!="board" and not game.story.can_meet(source): return "请返回委托人所在场景。"
	# Commit completed state before any signal, save or reward callback can re-enter.
	ledger.records[id].done=true
	var q=legacy(id)
	if not q.is_empty(): q.done=true
	if q.has("progress"): q.progress=goal(id)
	if id=="resident:bag": ledger.tokens.bag=0
	for material in d.get("materials",{}): s.materials[material]-=d.materials[material]
	if id.begins_with("personal:"):
		var who=id.get_slice(":",1); var job=db.raw.personal[who].job
		if job not in s.unlocked_jobs: s.unlocked_jobs.append(job)
		game.add_gear("class-"+job+"-weapon")
	if id.begins_with("service:"):
		var key=id.get_slice(":",1); s.story.building_services[key]=true
		if db.progression.buildings[key].type=="research":
			var marker="building-clue:"+key
			if marker not in s.story.discovered: s.story.discovered.append(marker)
	game.story.reward(d.get("reward",{})); game.story.affinity(d.giver,10)
	game.log_message("已交付「"+d.name+"」，奖励已收入行囊。")
	return game.last_message

func event(type: String, scene: String, target: String = "", unique: String = ""):
	if s.training or game.progression.trial_actor!="": return
	if type=="battle":
		if unique=="" or unique in ledger.battle_events: return
		ledger.battle_events.append(unique)
		if ledger.battle_events.size()>256: ledger.battle_events.pop_front()
	for id in ledger.records:
		if status(id)!="active": continue
		var d=definition(id); var steps=d.get("steps",[]); var index=stage(id)
		if id.begins_with("expeditions:"):
			var routes=db.route_ids(d.region)
			if type=="survey" and index<3 and routes[index]==scene and target=="survey": s.story.expeditions[d.region].stage+=1
		elif not steps.is_empty() and steps[0] is Dictionary and index<steps.size():
			var step=steps[index]
			if step.event==type and step.scene==scene and step.get("target",target)==target: ledger.records[id].stage+=1

func entrance(id: String) -> Dictionary:
	for e in db.world_interactions.entrances:
		if e.id==id: return e
	return {}

func entrance_for(scene: String) -> Dictionary:
	for e in db.world_interactions.entrances:
		if e.scene==scene: return e
	return {}

func entrance_unlocked(e: Dictionary) -> bool:
	return not e.is_empty() and (e.requires=="" or s.scene_progress.get(e.requires,false))

func discover(id: String):
	if id not in ledger.entrances: ledger.entrances.append(id); game.log_message("发现「"+entrance(id).name+"」。相关调查已发布，可在入口或公会接取。")

func town_action(id: String, action: String) -> String:
	if s.location.scene!="town" or s.training or s.battle!=null: return "请在晨星镇与它互动。"
	for d in db.world_interactions.resources:
		if d.id!=id: continue
		if ledger.town.get(id,false): return "这里已经采集过了，留待新的季节。"
		ledger.town[id]=true; s.materials[d.material]+=1; game._activity()
		game.log_message("采集「"+d.name+"」："+("草药" if d.material=="herb" else "矿石")+" +1。")
		return game.last_message
	var text="你静静观察了一会儿，镇上的生活仍在继续。"
	for d in db.world_interactions.animals:
		if d.id==id: text="你轻轻抚摸了"+d.name+"。它放松下来，留在熟悉的街角。" if action=="pet" else d.name+"在熟悉的街角活动，看起来很安心。"
	for d in db.world_interactions.objects:
		if d.id==id: text=d.text
	if action=="task":
		if id=="tuantuan" and status("resident:cat")=="active" and stage("resident:cat")==1:
			event("animal","town",id); text="你循着爪印找到了团团。它从旅店窗下探出头，蹭了蹭你的手。回去告诉小洛吧。"
		elif id=="amo" and status("resident:dog")=="active":
			event("animal","town",id); text="你蹲下安抚阿墨，让它熟悉马厩的声音。吠叫声渐渐停了，回去告诉小洛吧。"
		elif id=="snowball" and status("resident:rabbit")=="active" and ledger.tokens.get("leaf",0)==1:
			ledger.tokens.leaf=0; event("feed","town",id); text="雪球吃完嫩叶，轻轻碰了碰你的手。回去告诉阿芽吧。"
		elif id=="feeding-bowl" and status("resident:hen")=="active" and stage("resident:hen")==0 and ledger.tokens.get("bowl",0)==1:
			ledger.tokens.bowl=0; event("place","town",id); text="食盆已经稳稳安置，接着给咕咕喂食。"
		elif id=="gugu" and status("resident:hen")=="active" and stage("resident:hen")==1 and ledger.tokens.get("feed",0)==1:
			ledger.tokens.feed=0; event("feed","town",id); text="咕咕在新食盆前吃得很开心。回去告诉小铃吧。"
		elif id=="doudou" and status("resident:letter")=="active" and stage("resident:letter")==0:
			event("animal","town",id); ledger.tokens.letter=1; text="豆豆松开衔着的信笺。请把它送到礼拜堂信箱。"
		elif id=="chapel-mail" and status("resident:letter")=="active" and stage("resident:letter")==1 and ledger.tokens.get("letter",0)==1:
			ledger.tokens.letter=0; event("deliver","town",id); text="信笺已经送达礼拜堂。回去向小铃交付。"
		elif id=="medicine-bag" and status("resident:bag")=="active": event("inspect","town",id); ledger.tokens.bag=1; text="你收好封口完整的药包，准备交还阿芽。"
		elif id=="pawprints": event("inspect","town",id)
		else: event("animal","town",id)
	game.log_message(text); return text

func target(id: String) -> Dictionary:
	var d=definition(id); var current=status(id)
	if current=="completed": return {}
	if current=="ready":
		if d.turnin=="board": return {"scene":"room-guildhall","kind":"prop","id":"noticeboard"}
		if str(d.turnin).begins_with("service:"): return {"scene":db.progression.buildings[id.get_slice(":",1)].scene,"kind":"prop","id":"detail-"+id.get_slice(":",1)+"-0"}
		return npc_target(d.turnin)
	if not d.get("materials",{}).is_empty() and (not id.begins_with("personal:") or stage(id)>=2):
		for material in d.materials:
			if s.materials[material]>=d.materials[material]: continue
			for resource in db.world_interactions.resources:
				if resource.material==material and not ledger.town.get(resource.id,false): return {"scene":resource.scene,"kind":"town-life","id":resource.id}
			return {"scene":"wood" if material=="herb" else "pass","kind":"","id":""}
	if id.begins_with("expeditions:"):
		var route=db.route_ids(d.region)[mini(stage(id),2)]; var e=entrance_for(route)
		return {"scene":e.region,"kind":"entrance","id":e.id,"unknown":e.id not in ledger.entrances}
	if d.get("steps",[]).size()>0 and d.steps[0] is Dictionary:
		var step=d.steps[mini(stage(id),d.steps.size()-1)]
		if step.event=="battle":
			var e=entrance_for(step.scene); return {"scene":e.region,"kind":"entrance","id":e.id}
		return {"scene":step.scene,"kind":"town-life","id":step.target}
	if id.begins_with("personal:"):
		var p=db.raw.personal[id.get_slice(":",1)]; var index=mini(stage(id),1)
		return scene_target(p.scene if index==0 else p.next,"prop",p.props[index])
	if id.begins_with("regional:"):
		if stage(id)==0:
			var ref=db.narrative.regional[d.region].prop
			for scene in db.raw.scenes:
				var data=db.raw.scenes[scene]
				for p in data.props:
					if str(data.get("occupantKey",data.get("buildingId",scene)))+":"+p.id==ref: return scene_target(scene,"prop",p.id)
		return {"scene":d.region,"kind":"","id":""}
	if id.begins_with("service:"): return scene_target(db.progression.buildings[id.get_slice(":",1)].scene,"prop","detail-"+id.get_slice(":",1)+"-0")
	return npc_target(d.giver)

func scene_target(scene: String,kind: String,id: String) -> Dictionary:
	var e=entrance_for(scene)
	if not e.is_empty() and s.location.scene!=scene: return {"scene":e.region,"kind":"entrance","id":e.id,"unknown":e.id not in ledger.entrances}
	return {"scene":scene,"kind":kind,"id":id}

func npc_target(id: String) -> Dictionary:
	var n=db.raw.npcs.get(id,{})
	if n.has("place"): return {"scene":n.place,"kind":"npc","id":id}
	for scene in db.narrative.indoor:
		if db.scene_npcs(scene).any(func(npc): return npc.id==id): return {"scene":scene,"kind":"npc","id":id}
	return {"scene":"room-guildhall","kind":"prop","id":"noticeboard"}

func validate(saved: Dictionary) -> String:
	if not saved.has("task_state"): return ""
	var t=saved.task_state
	if not t is Dictionary: return "任务生命周期无效。"
	if t.get("revision")!=1: return "任务生命周期版本无效。"
	for key in ["records","town","tokens"]:
		if not t.get(key) is Dictionary: return "任务记录无效。"
	if not game._number(t.get("sequence"),0,1000000) or t.sequence!=floor(float(t.sequence)): return "接取顺序无效。"
	for key in ["entrances","battle_events"]:
		if not t.get(key) is Array: return "入口或战斗记录无效。"
	for id in t.entrances:
		if not id is String or entrance(id).is_empty() or t.entrances.count(id)!=1: return "入口发现记录无效。"
	for id in t.records:
		var q=t.records[id]
		if not catalog.has(id) or not q is Dictionary or not game._number(q.get("order"),1,t.sequence) or not game._number(q.get("stage"),0,100) or not q.get("done") is bool: return "任务阶段无效。"
		if float(q.order)!=floor(float(q.order)) or float(q.stage)!=floor(float(q.stage)): return "任务阶段必须为整数。"
	if t.has("tracked") and (not t.tracked is String or not t.records.has(t.tracked)): return "追踪任务无效。"
	for token in t.tokens:
		if token not in ["leaf","bowl","feed","letter","bag"] or not game._number(t.tokens[token],0,1): return "任务专用物品无效。"
	for value in t.town.values():
		if not value is bool: return "镇内互动记录无效。"
	for value in t.battle_events:
		if not value is String: return "战斗任务事件无效。"
	return ""
