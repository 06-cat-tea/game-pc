class_name StoryRuntime
extends RefCounted

var reference: WeakRef
var game:
	get: return reference.get_ref()
var db:
	get: return game.db
var s:
	get: return game.state
var data:
	get: return db.narrative
var progress:
	get: return s.story

func _init(session): reference=weakref(session)

func initialize():
	if not s.has("story"):
		s.story={"revision":1,"stage":0,"quests":{},"regional":{},"expeditions":{},"actions":{},"events":{},"discovered":[],"metrics":{"wins":0,"eliteWins":0,"bossWins":0},"challenges":{},"claimed":[],"returns":[]}
		for id in s.quests:
			if id not in ["first","stars"]: s.story.quests[id]=s.quests[id].duplicate(true)
	for id in db.raw.npcs:
		if not s.affinity.has(id): s.affinity[id]={"value":0,"chat_day":0,"gift_day":0}
	for key in ["shadow","danger"]:
		if not s.has(key): s[key]=0
	if not progress.has("investigation_facts"):
		progress.investigation_facts={}
	for region in data.regional:
		if not progress.investigation_facts.has(region):
			progress.investigation_facts[region]={"observed":progress.regional.get(region,{}).get("done",false),"done":progress.regional.get(region,{}).get("done",false)}

func place() -> String: return db.place_of(s.location.scene)

func can_meet(id: String) -> bool:
	if not db.raw.npcs.has(id): return false
	if db.is_outdoor(s.location.scene): return db.raw.npcs[id].get("place","")==place() and db.raw.npcs[id].has("position")
	return db.scene_npcs(s.location.scene).any(func(n): return n.id==id)

func greeting(id: String) -> String:
	var status=0
	var quest=progress.quests.get(data.oldQuest.get(id,""),{})
	if quest.is_empty(): quest=s.personal.get(id,{})
	if quest.is_empty():
		for p in data.regional:
			if data.regional[p].npc==id: quest=progress.regional.get(p,{})
	if not quest.is_empty(): status=2 if quest.get("done",false) else 1
	var stage=int(progress.stage) if id=="mira" else status
	var past=int(s.dialogue.get(id+":past",-1))
	return data.greetings[id].get("%d:%d:%d" % [s.phase,stage,past],db.raw.npcs[id].get("line",""))

func accept_quest(id: String) -> String:
	if id=="stars":
		if not progress.quests.has(id): progress.quests[id]={"progress":0,"done":false}
		return ""
	return game.tasks.accept("quest:"+id,data.oldQuest.find_key(id) if data.oldQuest.values().has(id) else "")

func npc_choice(id: String, op: String = "accept") -> String:
	if s.battle!=null or s.training: return "请先结束战斗或训练。"
	if not can_meet(id): return "请到这位居民所在的场景交谈。"
	if id=="mira" and not s.chapter_complete: return "先完成晨星镇序章，带回地下渠线索并通过公会试炼。"
	var changed=false
	if op=="accept" and data.oldQuest.has(id):
		var q=data.oldQuest[id]
		if not game.tasks.accepted("quest:"+q): game.tasks.accept("quest:"+q,id); changed=true
	for rule in data.stages:
		if rule.get("npc","")==id and (rule.get("op","")==op or op=="story") and int(progress.stage)==int(rule.from):
			progress.stage=int(rule.to); accept_quest("stars"); _star_progress()
			if int(rule.to)==8: s.rep+=3
			game.log_message(rule.text); changed=true; break
	return "对话与委托记录已更新。" if changed else "这项委托已有记录，请按线索继续。"

func _star_progress():
	accept_quest("stars"); progress.quests.stars.progress=mini(7,int(progress.stage))
	if int(progress.stage)>=8: _complete("stars")

func _complete(id: String):
	var q=progress.quests[id]
	if q.done: return
	if id!="stars": return # Side objectives wait for explicit delivery.
	q.done=true; reward(data.quests[id].reward)
	if id=="herbs": s.quests.herbs={"progress":3,"done":true}
	var npc={"stars":"mira","herbs":"pella","roots":"sylvi","caravan":"toren","names":"eira","letters":"lian"}.get(id,"")
	if npc!="": affinity(npc,10)
	game.log_message("委托「%s」完成。%s 奖励已收入行囊。" % [data.quests[id].name,data.quests[id].desc])

func quest_progress(id: String, amount: int = 1, unlock: bool = false):
	# World actions may publish clues, but never accept a side quest.
	if not progress.quests.has(id) or progress.quests[id].done: return
	var q=progress.quests[id]; q.progress=mini(int(data.quests[id].goal),int(q.progress)+amount)
	if q.progress>=data.quests[id].goal: _complete(id)

func reward(values: Dictionary):
	for key in values:
		match key:
			"xp": game.grant_xp(["hero"],int(values[key]))
			"gold","rep","supplies","knowledge","light","trust","shadow","danger": s[key]+=values[key]
			"item": game.add_gear(values[key])
			"materials":
				for material in values[key]: s.materials[material]+=values[key][material]

func affinity(id: String, amount: int):
	if s.affinity.has(id): s.affinity[id].value=clampi(int(s.affinity[id].value)+amount,0,100)

func accept_investigation(kind: String, region: String) -> String:
	var definitions=data.regional if kind=="regional" else data.expeditions
	if not definitions.has(region): return "调查不存在。"
	return game.tasks.accept(kind+":"+region,definitions[region].npc)

func observe(scene: String, prop: Dictionary):
	var source=db.raw.scenes[scene]; var key=str(source.get("occupantKey",source.get("buildingId",scene)))+":"+str(prop.id)
	if key not in progress.discovered: progress.discovered.append(key)
	for region in data.regional:
		if key==data.regional[region].prop: progress.investigation_facts[region].observed=true
	for region in progress.regional:
		var q=progress.regional[region]; var def=data.regional[region]
		if not q.done and int(q.stage)==0 and key==def.prop: q.stage=1
	if prop.id=="survey": game.tasks.event("survey",scene,"survey")
	if key=="tower:clockwork" and progress.investigation_facts.values().all(func(q): return q.done):
		progress.events.epilogue_ready=true

func inspect(scene: String, prop: Dictionary) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	var source=db.raw.scenes[scene]; var key=scene+":"+str(prop.id); var action=prop.get("action","read")
	if action=="survey":
		if not s.scene_progress.get(scene+":survey",false):
			s.scene_progress[scene+":survey"]=true
			game.log_message("路线线索已记录，下一段入口已开放。")
	elif action=="cache":
		if s.flags.get(key,false): return "旅行箱已取用。"
		s.flags[key]=true; var sub=source.kind=="submap"
		reward({"materials":{"herb":2,"ore":1,"shard":1 if sub else 0},"supplies":1,"gold":10+int(source.get("level",1))*4 if sub else 8,"xp":40+int(source.get("level",1))*20 if sub else 15})
	elif action=="restore":
		if s.flags.get(key,0)==s.day: return "今天已在这里整理过。"
		s.flags[key]=s.day; restore(24,18)
	observe(scene,prop); game._progress_personal(scene,str(prop.id)); game.log_message(str(prop.detail))
	return str(prop.detail)

func epilogue() -> String:
	if s.training or s.battle!=null or not can_meet("mira"): return "请在晨星镇与米拉交谈。"
	if int(progress.stage)<8: return "补全星图后才会开放收尾任务。"
	if progress.events.get("epilogue",false): return "归灯已亮起。"
	if not progress.events.get("epilogue_ready",false): return "先完成五区域调查，再去钟塔调查机芯。"
	progress.events.epilogue=true; reward({"xp":220,"gold":160,"materials":{"shard":3}}); affinity("mira",10)
	game.log_message("收尾任务「归灯之后」完成。五地的名字重新写入星图，钟声终于有了归处。")
	return game.last_message

func roll() -> float:
	var rng=RandomNumberGenerator.new(); rng.seed=int(s.seed_counter)*1103515245+int(s.day)*12345; s.seed_counter+=1
	return rng.randf()

func restore(hp: int, mp: int):
	for member in s.members.values():
		if member.hp<=0: continue
		var stats=PartyMemberState.stats(member,s,db); member.hp=mini(stats.max_hp,int(member.hp)+hp); member.mp=mini(stats.max_mp,int(member.mp)+mp)

func activity(id: String) -> String:
	if s.battle!=null or s.training: return "请先结束战斗或训练。"
	var available=data.places[place()].actions.any(func(a): return a[0]==id)
	for b in data.buildings:
		if b.place==place() and b.get("action","")==id: available=true
	for n in db.scene_npcs(s.location.scene):
		if n.get("service","")==id: available=true
	if id.begins_with("world:") or id.begins_with("city:"): return service(id)
	if not available: return "请到对应地区的居民或建筑使用这项行动。"
	if id in ["tavern","lighthouse","market","forge"]: return "请选择对应事件或交易入口。"
	if id=="purify" and int(s.members.hero.mp)<14: return "法力不足，需要至少 14 点。"
	var battle_id=""; var success=true
	match id:
		"guild": s.rep+=1
		"chapel": quest_progress("candle",1,true); restore(0,12); s.light+=1
		"forage":
			s.materials.herb+=1+int(PartyMemberState.stats(s.members.hero,s,db).herb_bonus); s.gold+=8+int(roll()*12)
			quest_progress("herbs"); if roll()<.35: s.items.potion+=1
		"ruins": s.materials.shard+=1; restore(0,8); quest_progress("pages",1,true); quest_progress("roots")
		"hunt": battle_id="roam-"+place()
		"well":
			if roll()<.48: game.add_gear("ring")
			else: battle_id="roam-wood"
		"escort":
			if roll()<.38: battle_id="roam-pass"; success=false
			else: s.gold+=32+int(roll()*25); s.rep+=1; quest_progress("caravan")
		"mine":
			s.materials.ore+=1; s.gold+=18+int(roll()*18)
			if roll()<.25: game.add_gear("bracer")
		"camp": battle_id="roam-pass"
		"temple": battle_id="activity-temple"; success=false
		"purify": s.members.hero.mp-=14; s.light+=1; s.rep+=2; game.grant_xp(["hero"],24); quest_progress("candle",1,true)
		"crypt":
			quest_progress("pact",1,true); quest_progress("names"); s.materials.shard+=1
			if roll()<.42: game.add_gear("crown")
			else: battle_id="roam-fen"
		"whisper":
			quest_progress("pact",1,true); s.shadow+=1; s.danger+=1
			var hero=s.members.hero; hero.permanent=hero.get("permanent",{}); hero.permanent.atk=hero.permanent.get("atk",0)+1
		"wreck":
			quest_progress("wreck",1,true); s.materials.ore+=1
			if roll()<.3: battle_id="roam-coast"
			else: s.gold+=20+int(roll()*23)
		"fish": s.materials.herb+=1; s.supplies+=1
		_: return "行动不存在。"
	if battle_id!="":
		if battle_id.begins_with("roam-"):
			battle_id=("roamelite-" if id in ["camp","crypt"] else "roam-")+place()+"-"+str(mini(data.enemies[place()].size()-1,int(roll()*data.enemies[place()].size())))
		var error=game.start_battle(battle_id)
		if error!="": return error
		if id=="escort": s.battle.story_on_win="escort"
		if success: _activity_success(id)
		return ""
	_activity_success(id)
	return game.last_message

func _activity_success(id: String):
	progress.actions[id]=int(progress.actions.get(id,0))+1
	for region in data.regional:
		if region==place() and data.regional[region].action==id and progress.investigation_facts[region].observed: progress.investigation_facts[region].done=true
	for rule in data.stages:
		if rule.get("activity","")==id and int(progress.stage)==int(rule.from) and int(progress.actions[id])>=int(rule.count): progress.stage=int(rule.to); _star_progress()
	for region in progress.regional:
		var q=progress.regional[region]; var definition=data.regional[region]
		if not q.done and int(q.stage)==1 and place()==region and definition.action==id:
			q.stage=2
			game.log_message("支线「"+definition.name+"」完成。"+definition.clue)
	game._activity(); game.advance_time()
	var texts=data.actionTexts.get(id,[])
	game.log_message(str(texts[0]) if not texts.is_empty() else "旅途行动已记入日志。")

func battle_won(definition, first: bool, battle: Dictionary):
	progress.metrics.wins+=1
	if definition.enemies.any(func(e): return e.get("elite",false)): progress.metrics.eliteWins+=1
	if definition.enemies.any(func(e): return e.get("boss",false)): progress.metrics.bossWins+=1
	var meta=definition.story
	var loot=meta.get("loot",[])
	if not loot.is_empty() and roll()<.46: game.add_gear(loot[mini(loot.size()-1,int(roll()*loot.size()))])
	if meta.has("challenge"):
		var id=meta.challenge; var c=data.challenges[id]; var initial=not progress.challenges.has(id)
		progress.challenges[id]=int(progress.challenges.get(id,0))+1
		s.materials.ore+=2 if c.get("boss",false) else 1; s.materials.shard+=1
		if initial and c.has("item"): game.add_gear(c.item)
		game.log_message("挑战完成："+c.name+"。"+("专属装备已收入背包。" if initial else "获得矿石与星屑。"))
	var on_win=battle.get("story_on_win",meta.get("on_win",""))
	if on_win!="":
		quest_progress("caravan" if on_win=="escort" else "moon",1,true); _activity_success(on_win)
	for id in battle.participants: affinity(id,2)

func choose_event(id: String, choice: int) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	if not data.events.has(id) or choice<0 or choice>=data.events[id].options.size(): return "选项不存在。"
	var event=data.events[id]
	if event.place!=place(): return "请前往事件所在地区。"
	if progress.events.has(id): return "这次抉择已经记入旅途。"
	var option=event.options[choice]
	for key in option.get("cost",{}):
		if s.materials.get(key,0)<option.cost[key]: return "材料不足。"
	if s.members.hero.mp<int(option.get("mp",0)): return "法力不足。"
	for key in option.get("cost",{}): s.materials[key]-=option.cost[key]
	s.members.hero.mp-=int(option.get("mp",0)); progress.events[id]=choice
	for key in option.get("world",{}): s[key]+=option.world[key]
	if option.has("affinity"): affinity(option.affinity[0],int(option.affinity[1]))
	reward({"gold":option.get("gold",0),"supplies":option.get("supplies",0),"materials":option.get("materials",{})})
	game.log_message(option.text); return option.text

func core_event(id: String, key: String) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	var region={"tavern":"town","prayer":"town","lighthouse":"coast"}.get(id,"")
	if region!=place() or not data.coreEvents.get(id,{}).get("options",[]).any(func(o): return o[0]==key): return "事件选项无效。"
	var flag="core:"+id+":"+key
	if progress.events.has(flag): return "这次抉择已经记入旅途。"
	if id=="prayer" and key=="donate" and s.gold<20: return "金币不足，祭司让你之后再来。"
	if id=="lighthouse" and key=="light" and s.members.hero.mp<10: return "法力不足，需要 10 点。"
	progress.events[flag]=true
	if id=="tavern":
		match key:
			"forest": s.items.potion+=1; s.knowledge+=1
			"road": s.gold+=18; s.trust+=1
			"coin": s.knowledge+=2
	elif id=="prayer":
		match key:
			"vow": restore(0,18); quest_progress("candle"); progress.actions.prayer=int(progress.actions.get("prayer",0))+1; s.light+=1
			"donate":
				s.gold-=20; s.rep+=2; s.trust+=1
				var hero=s.members.hero; hero.permanent=hero.get("permanent",{}); hero.permanent.max_hp=hero.permanent.get("max_hp",0)+10; hero.hp+=10
			"ask": game.grant_xp(["hero"],25); s.knowledge+=1
	else:
		quest_progress("letters")
		if key=="light": s.members.hero.mp-=10; s.light+=1; s.danger=maxi(0,int(s.danger)-1); game.grant_xp(["hero"],35)
		if key=="name": s.rep+=2; s.trust+=1
	var text=data.eventText[id].get(key,data.eventText[id].get("all","")); game.log_message(text); return text

func service_info(id: String) -> Dictionary:
	var key=id.get_slice(":",1); var city=id.begins_with("city:"); var def=data.cityServices.get(key,{}) if city else data.services.get(key,{})
	if def.is_empty(): return {}
	var cost={"gold":int(def.get("cost",0))} if city else def.get("cost",{}).duplicate()
	if city and key=="rest": cost={"supplies":1}
	var native=place()=="town" and id in ["world:study","world:drill","world:royal-record","world:song","world:brew","world:supplies"]
	var owner=""
	for npc_id in db.raw.npcs:
		var npc=db.raw.npcs[npc_id]
		if npc.get("place","")==place() and npc.get("service","")==id:
			owner=npc_id
			if not native and cost.get("gold",0)>0 and s.affinity[npc_id].value>=60: cost.gold=floori(cost.gold*.9)
	var description=str(def.get("description",""))
	if native: description={"study":"王朝知识 +1、主角经验 +35","drill":"出战成员经验 +25","royal-record":"王朝知识 +1、星屑 +1","song":"全队法力 +12","brew":"赤松药剂 +1","supplies":"旅行补给 +2"}[key]
	var once=key in ["royal-record","route","truce"]; var daily=def.get("daily",false)
	var flag=("service:"+id) if native else id+":"+place()
	var unavailable=(once and s.flags.get(flag,false)) or (daily and s.flags.get(flag,0)==s.day)
	for c in cost:
		if s.get(c,s.materials.get(c,0))<cost[c]: unavailable=true
	return {"name":def.name,"description":description,"cost":cost,"once":once,"daily":daily,"unavailable":unavailable,"owner":owner}

func service(id: String) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	var key=id.get_slice(":",1); var city=id.begins_with("city:"); var def=data.cityServices.get(key,{}) if city else data.services.get(key,{})
	if def.is_empty(): return "服务不存在。"
	if city and place()!="city": return "请先抵达王城。"
	var available=city
	for b in data.buildings:
		if b.place==place() and b.get("action","")==id: available=true
	for npc in db.raw.npcs.values():
		if npc.get("place","")==place() and npc.get("service","")==id: available=true
	for npc in db.scene_npcs(s.location.scene):
		if npc.get("service","")==id: available=true
	if not available: return "请到对应居民或建筑所在的地区。"
	var flag=id+":"+place(); var once=key in ["royal-record","route","truce"]; var daily=def.get("daily",false)
	if once and s.flags.get(flag,false) or daily and s.flags.get(flag,0)==s.day: return "这项行动已完成。"
	var cost={"gold":int(def.get("cost",0))} if city else def.get("cost",{}).duplicate()
	if city and key=="rest": cost={"supplies":1}
	if not city and cost.get("gold",0)>0:
		for npc_id in db.raw.npcs:
			var npc=db.raw.npcs[npc_id]
			if npc.get("place","")==place() and npc.get("service","")==id and s.affinity[npc_id].value>=60:
				cost.gold=floori(cost.gold*.9); break
	for c in cost:
		if s.get(c,s.materials.get(c,0))<cost[c]: return "材料或金币不足。"
	for c in cost:
		if s.has(c): s[c]-=cost[c]
		else: s.materials[c]-=cost[c]
	match key:
		"royal-record","truce": s.materials.shard+=1; s["trust" if key=="truce" else "knowledge"]+=1; game.grant_xp(["hero"],25)
		"study","archive":
			if not city: game.grant_xp(["hero"],15); restore(0,8)
		"song": restore(0,20)
		"brew":
			s.items.potion+=1
			if s.affinity.alchemist.value>=60 and s.flags.get("alchemy-bonus",0)!=s.day: s.items.potion+=1; s.flags["alchemy-bonus"]=s.day
		"supplies": s.supplies+=1 if city else 2
		"potion": s.items.potion+=1
		"rest":
			for member in s.members.values():
				var stats=PartyMemberState.stats(member,s,db); var factor=.42*(1.0+stats.camp_bonus)+(.1 if s.affinity.innkeeper.value>=60 else 0.0)
				member.hp=mini(stats.max_hp,int(member.hp)+ceili(stats.max_hp*factor)); member.mp=mini(stats.max_mp,int(member.mp)+ceili(stats.max_mp*(factor+.03)))
		"drill": game.grant_xp(["hero"],20); restore(8,0)
		"harvest","harbor-trade": s.supplies+=1; s.materials.herb+=1
		"herb-trade": s.materials.herb+=2
		"ore-trade": s.materials.ore+=2
		"route": s.rep+=1; game.grant_xp(["hero"],25)
	if once or daily: s.flags[flag]=true if once else s.day
	game.advance_time(); game.log_message(def.name+"："+str(def.get("description","行动完成，收益已收入旅途记录。")))
	return game.last_message

func achievement_complete(id: String) -> bool:
	var completed=progress.quests.values().filter(func(q): return q.done).size()+progress.regional.values().filter(func(q): return q.done).size()+progress.expeditions.values().filter(func(q): return q.done).size()+s.personal.values().filter(func(q): return q.done).size()+int(s.quests.first.done)
	match id:
		"explore1": return progress.discovered.filter(func(k): return k.begins_with("region:")).size()>=2
		"explore2": return progress.discovered.filter(func(k): return k.begins_with("building:")).size()>=5
		"explore3": return progress.discovered.filter(func(k): return k.begins_with("region:")).size()>=5 and progress.discovered.filter(func(k): return not k.begins_with("region:") and not k.begins_with("building:")).size()>=10
		"quest1": return completed>=1
		"quest2": return completed>=5
		"quest3": return int(progress.stage)>=8
		"battle1": return int(progress.metrics.wins)>=1
		"battle2": return int(progress.metrics.eliteWins)>=5
		"battle3": return progress.challenges.keys().filter(func(k): return k.begins_with("boss-")).size()>=5
		"growth1": return s.members.hero.learned.size()>=1
		"growth2": return s.flags.keys().filter(func(k): return k.begins_with("crafted:")).size()>=3
		"growth3": return s.gear.values().any(func(g): return g.rank>=3)
		"bond1": return s.affinity.values().any(func(r): return r.value>=20)
		"bond2": return s.affinity.values().any(func(r): return r.value>=60)
		"bond3": return s.affinity.values().filter(func(r): return r.value>=80).size()>=3
	return false

func claim(id: String) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	if id in progress.claimed or not achievement_complete(id): return "尚未达成或已经领取。"
	for a in data.achievements:
		if a.id==id:
			progress.claimed.append(id); s.gold+=int(a.gold); s.materials.shard+=1; game.log_message("成就「"+a.name+"」奖励已领取。"); return game.last_message
	return "成就不存在。"

func return_scene() -> String:
	var e=game.tasks.entrance_for(s.location.scene)
	if not e.is_empty(): return e.region
	if not progress.returns.is_empty(): return progress.returns[-1].scene
	return db.place_of(s.location.scene)

func travel(scene: String) -> String:
	var old=s.location.duplicate(true); var region=db.place_of(scene)
	var leaving=game.tasks.entrance_for(old.scene)
	if not leaving.is_empty() and scene==leaving.region:
		progress.returns=[]; s.location={"scene":scene,"x":float(leaving.point[0]),"y":float(leaving.point[1])}; return "restored"
	var entering=game.tasks.entrance_for(scene)
	if not entering.is_empty():
		if not game.tasks.entrance_unlocked(entering): return "先调查上一段路线的线索。"
		var routes=db.route_ids(entering.region); var index=routes.find(old.scene)
		var through_passage=index>=0 and index+1==int(entering.index) and s.scene_progress.get(old.scene+":survey",false)
		if entering.id not in game.tasks.ledger.entrances and not through_passage: return "先在所属地区发现实际入口，再进入探索路线。"
	if not progress.returns.is_empty() and scene==progress.returns[-1].scene:
		s.location=progress.returns.pop_back(); return "restored"
	if db.raw.scenes.has(scene):
		var def=db.raw.scenes[scene]
		if def.kind=="submap" and int(def.get("index",0))>0:
			var previous=db.route_ids(region)[int(def.index)-1]
			if not s.scene_progress.get(previous+":survey",false) and not def.has("buildingId"): return "先调查上一段路线的线索。"
		if scene not in db.chapter_scenes and db.place_of(old.scene)!=region:
			progress.returns=[]
			var point=db.regions[region].spawn if db.regions.has(region) else [30,27]
			var building_id=str(def.get("buildingId",""))
			for id in data.entrances:
				if data.entrances[id]==scene: building_id=id; break
			for b in db.regions.get(region,{}).get("buildings",[]):
				if b.id==building_id: point=b.entry; break
			old={"scene":region,"x":float(point[0]),"y":float(point[1])}
		progress.returns.append(old)
		if progress.returns.size()>20: progress.returns.pop_front()
	else: progress.returns=[]
	var discovered="region:"+region
	if discovered not in progress.discovered: progress.discovered.append(discovered)
	return ""

func validate(saved: Dictionary) -> String:
	if not saved.has("story"): return ""
	var st=saved.story
	if not st is Dictionary or st.get("revision")!=1 or not game._number(st.get("stage"),0,8): return "剧情记录无效。"
	if st.has("investigation_facts"):
		if not st.investigation_facts is Dictionary: return "调查剧情事实无效。"
		for region in st.investigation_facts:
			var fact=st.investigation_facts[region]
			if not data.regional.has(region) or not fact is Dictionary or not fact.get("observed") is bool or not fact.get("done") is bool: return "调查剧情事实无效。"
	if st.stage!=floor(float(st.stage)): return "剧情阶段无效。"
	for key in ["quests","regional","expeditions","actions","events","metrics","challenges"]:
		if not st.get(key) is Dictionary: return "剧情记录缺少："+key
	for pair in [["quests",data.quests,"progress"],["regional",data.regional,"stage"],["expeditions",data.expeditions,"stage"]]:
		for id in st[pair[0]]:
			var q=st[pair[0]][id]
			if not pair[1].has(id) or not q is Dictionary or not q.get("done") is bool or not game._number(q.get(pair[2]),0,100): return "任务进度无效。"
			var limit=int(pair[1][id].goal) if pair[0]=="quests" else 2 if pair[0]=="regional" else 3
			if float(q[pair[2]])!=floor(float(q[pair[2]])) or q[pair[2]]>limit: return "任务阶段超出范围。"
	for key in ["discovered","claimed","returns"]:
		if not st.get(key) is Array: return "探索记录无效。"
	for key in ["discovered","claimed"]:
		if st[key].any(func(value): return not value is String): return "探索记录条目无效。"
	for key in ["wins","eliteWins","bossWins"]:
		if not game._number(st.metrics.get(key),0,100000000): return "战斗履历无效。"
	for table in [st.actions,st.challenges]:
		for key in table:
			if not key is String or not game._number(table[key],0,100000000): return "行动履历无效。"
	for key in st.events:
		if not key is String or (not st.events[key] is bool and not game._number(st.events[key],0,10)): return "事件选择无效。"
	if st.returns.size()>20: return "返回记录过长。"
	for position in st.returns:
		if not position is Dictionary or not (db.is_outdoor(position.get("scene","")) or db.raw.scenes.has(position.get("scene",""))) or not game._number(position.get("x"),0,96) or not game._number(position.get("y"),0,72): return "场景返回记录无效。"
	for key in ["shadow","danger"]:
		if not game._number(saved.get(key,0),0,1000000): return "世界倾向记录无效。"
	return ""
