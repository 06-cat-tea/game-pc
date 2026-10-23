class_name GameMenus
extends RefCounted

var game
var pages: RailPages
var story_pages: StoryPages
var progression_pages: ProgressionPages
var quest_pages: QuestPages
var browser_files: BrowserFileBridge
var training_team = ["mira","toren","eira"]
var training_job = "warden"
var training_level = 6
const MENU_NAMES = {"party":"队伍与战术","skills":"职业技艺","inventory":"背包与装备","craft":"旅行工坊","journal":"旅途记录","map":"晨星镇地图","saves":"设置与存档","settings":"设置","training":"公会战术训练","actions":"附近行动","encounters":"观察敌群","new":"开始新的旅程"}
const TACTIC_NAMES = ["输出优先","保护优先","资源保留"]
const TACTIC_IDS = ["damage","protect","reserve"]

func _init(owner): game=owner; pages=RailPages.new(owner,self); story_pages=StoryPages.new(owner,pages); progression_pages=ProgressionPages.new(owner); quest_pages=QuestPages.new(owner)

func frame(title: String) -> VBoxContainer:
	var root=pages.shell(title)
	return UIkit.scroll_at(root,Vector2.ZERO,Vector2(1792,788))

func open(kind: String, subject: String):
	if kind=="wheel": _wheel(); return
	if quest_pages.build(kind,subject): return
	if progression_pages.build(kind,subject): return
	if story_pages.build(kind,subject): return
	if pages.build(kind,subject): return
	if kind=="npc": _npc_dialogue(subject); return
	if kind=="topic": _topic_dialogue(subject); return
	var body=frame(MENU_NAMES.get(kind,"旅人笔记"))
	match kind:
		"new": _new(body)
		"party": _party(body,subject)
		"skills": _skills(body,subject)
		"inventory": _inventory(body,subject)
		"craft": _craft(body)
		"journal": _journal(body)
		"map": _map(body)
		"building": _building(body,subject)
		"npc": _npc(body,subject)
		"topic": _topic(body,subject)
		"training": _training(body)
		"encounters": _encounters(body,subject)
		"event": _event(body,subject)
		"actions": _actions(body)
		"saves": _saves(body)
		"settings": _settings(body)
		"items": _battle_items(body)
		"combos": _combos(body)
		"formations": _formations(body)
		"battle_log":
			for line in game.session.engine.battle.log: UIkit.label(body,line,22)
		_: UIkit.label(body,"没有找到这份记录。")

func _new(body: VBoxContainer):
	UIkit.label(body,"选择你的起始职业",34)
	UIkit.label(body,"原生首章从新旅程开始。开始新游戏会覆盖自动存档，已有手动档保留。",23,UIkit.MUTED)
	var row=UIkit.h(body)
	for job in ["ranger","arcanist","warden"]:
		var card=UIkit.v(UIkit.panel(row))
		UIkit.label(card,GameContent.JOB_NAMES[job],32,UIkit.GOLD)
		UIkit.label(card,game.db.raw.jobs[job].desc,26)
		UIkit.button(card,"以此职业出发",func(): game.load_new_game(job))

func _member_tabs(body: Node, kind: String, selected: String):
	var row=UIkit.h(body)
	for id in game.session.state.members:
		UIkit.button(row,("● " if id==selected else "")+game.db.actors[id].display_name,func(): game.open_menu(kind,id))

func _party(body: VBoxContainer, id: String):
	var s=game.session.state
	_member_tabs(body,"party",id)
	var member=s.members[id]; var stats=PartyMemberState.stats(member,s,game.db)
	var row=UIkit.h(body)
	UIkit.image(row,game.db.art("portraits",id),Vector2(230,330))
	var details=UIkit.v(row)
	UIkit.label(details,"%s  ·  %s  Lv.%d" % [game.db.actors[id].display_name,GameContent.JOB_NAMES[member.job],member.level],34,UIkit.GOLD)
	UIkit.label(details,"经验 %d / %d    技能点 %d" % [member.xp,PartyMemberState.next_xp(member.level),member.skill_points],24)
	UIkit.label(details,"生命 %d/%d   法力 %d/%d\n攻击 %d   防御 %d   速度 %d   暴击 %d%%" % [member.hp,stats.max_hp,member.mp,stats.max_mp,stats.atk,stats.def,stats.speed,int(stats.crit*100)],26)
	UIkit.label(details,"出战成员独立获得经验；后备不分经验。倒地不会永久失去角色。",22,UIkit.MUTED)
	UIkit.button(details,"配置技能",func(): game.open_menu("skills",id))
	UIkit.button(details,"配置装备",func(): game.open_menu("inventory",id))
	UIkit.button(details,"回营地待命" if id in s.active else "加入出战队伍",func(): _result(game.session.toggle_member(id),"party",id),id=="hero" or s.battle!=null)
	_tactics(body,id)

func _tactics(body: VBoxContainer, id: String):
	var s=game.session.state; var member=s.members[id]
	var controls=UIkit.h(body)
	var tactic_box=UIkit.v(UIkit.panel(controls))
	UIkit.label(tactic_box,"自动控制",26,UIkit.GOLD)
	var automatic=CheckButton.new(); automatic.text="交由战术 AI"; automatic.button_pressed=member.auto; tactic_box.add_child(automatic)
	automatic.toggled.connect(func(enabled): member.auto=enabled; _sync_tactic(id))
	var ultimate=CheckButton.new(); ultimate.text="允许自动大招"; ultimate.button_pressed=member.get("ultimate_auto",false); tactic_box.add_child(ultimate)
	ultimate.toggled.connect(func(enabled): member.ultimate_auto=enabled; _sync_tactic(id))
	UIkit.label(tactic_box,"战术预设",21)
	UIkit.option(tactic_box,TACTIC_NAMES,TACTIC_IDS.find(member.tactic),func(index): member.tactic=TACTIC_IDS[index]; _sync_tactic(id))
	UIkit.label(tactic_box,"集火目标",21)
	UIkit.option(tactic_box,["优先玩家标记","优先蓄力敌人","优先残血敌人"],["marked","charging","lowest"].find(member.focus),func(index): member.focus=["marked","charging","lowest"][index]; _sync_tactic(id))
	var thresholds=UIkit.v(UIkit.panel(controls))
	UIkit.label(thresholds,"治疗与资源",26,UIkit.GOLD)
	_slider(thresholds,"治疗生命阈值",member.heal_threshold,func(value): member.heal_threshold=value; _sync_tactic(id))
	_slider(thresholds,"法力保留比例",member.mana_reserve,func(value): member.mana_reserve=value; _sync_tactic(id))
	UIkit.label(thresholds,"保护优先先治疗与苏生；资源保留仅在施法后仍满足保留比例时使用技能。",21,UIkit.MUTED)
	var formation=UIkit.v(UIkit.panel(controls))
	UIkit.label(formation,"阵型与站位",26,UIkit.GOLD)
	var formation_option=UIkit.option(formation,["均衡","突击","守望"],["balanced","assault","watch"].find(s.formation),func(index):
		if s.battle==null: s.formation=["balanced","assault","watch"][index]; game.session.changed.emit())
	formation_option.disabled=s.battle!=null
	UIkit.label(formation,game.db.raw.formations[s.formation].desc,21,UIkit.MUTED)
	if id in s.active:
		var slot_option=UIkit.option(formation,["前排 1","前排 2","后排 1","后排 2"],int(member.slot),func(index):
			if s.battle!=null: game.toast("战斗中请使用换位行动。"); return
			for other in s.active:
				if other!=id and s.members[other].slot==index: s.members[other].slot=member.slot
			member.slot=index; game.session.changed.emit())
		slot_option.disabled=s.battle!=null
	if id=="hero":
		UIkit.label(body,"营地转职：已有技能保留，仅当前职业生效。",23,UIkit.GOLD)
		var jobs=UIkit.h(body)
		for job in GameContent.JOB_ORDER: UIkit.button(jobs,GameContent.JOB_NAMES[job],func(): _result(game.session.change_job(job),"party",id),job not in s.unlocked_jobs or s.battle!=null)

func _sync_tactic(id: String):
	var s=game.session.state
	if s.battle!=null:
		var unit=game.session.engine.unit(id)
		if not unit.is_empty():
			for key in ["auto","ultimate_auto","tactic","focus","heal_threshold","mana_reserve"]: unit[key]=s.members[id].get(key,false)
	game.session.changed.emit()

func _slider(parent: Node, title: String, initial: float, callback: Callable):
	parent.set_meta("replace_on_refresh",true)
	var label=UIkit.label(parent,"%s  %d%%" % [title,roundi(initial*100)],22)
	var control=HSlider.new(); control.min_value=0; control.max_value=1; control.step=0.05; control.value=initial; control.custom_minimum_size=Vector2(330,38); parent.add_child(control)
	control.value_changed.connect(func(value): label.text="%s  %d%%" % [title,roundi(value*100)]; callback.call(value))

func _skills(body: VBoxContainer, id: String):
	var s=game.session.state; var member=s.members[id]
	_member_tabs(body,"skills",id)
	UIkit.label(body,"%s · %s   Lv.%d   剩余技能点 %d" % [game.db.actors[id].display_name,GameContent.JOB_NAMES[member.job],member.level,member.skill_points],30,UIkit.GOLD)
	UIkit.label(body,"最多配置四项主动技能。被动仅对学习它的角色生效。",22,UIkit.MUTED)
	var top=UIkit.h(body)
	UIkit.button(top,"免费重配当前职业",func(): _confirm("重配技能","退回这位角色当前职业已花费的技能点，清空该职业配置。",func(): _result(game.session.respec(id),"skills",id)),s.battle!=null or s.location.scene!="town")
	UIkit.button(top,"前往队伍 / 转职",func(): game.open_menu("party",id))
	var branches=UIkit.h(body)
	for branch in game.db.raw.jobs[member.job].branches:
		var column=UIkit.v(branches)
		UIkit.label(column,game.db.raw.jobs[member.job].branches[branch],28,UIkit.GOLD)
		for skill_id in game.db.job_skills(member.job):
			var skill=game.db.skills[skill_id]; var definition=skill.data
			if definition.branch!=branch: continue
			var box=UIkit.v(UIkit.panel(column))
			var known=skill_id in member.learned
			var configured=skill_id in member.loadouts.get(member.job,[])
			UIkit.label(box,("✓ " if known else "")+skill.display_name,25,UIkit.GOLD if configured else Color.WHITE)
			UIkit.label(box,"Lv.%d · %d 点 · %s" % [definition.level,definition.cost,"主动" if definition.kind=="active" else "被动"],19,UIkit.MUTED)
			UIkit.label(box,game.db.describe_skill(skill_id),20)
			if known and definition.kind=="active": UIkit.button(box,"移出配置" if configured else "加入配置",func(): _result(game.session.configure_skill(id,skill_id),"skills",id),s.battle!=null)
			elif not known: UIkit.button(box,"学习",func(): _result(game.session.learn(id,skill_id),"skills",id),s.battle!=null or member.level<definition.level or member.skill_points<definition.cost)

func _inventory(body: VBoxContainer, id: String):
	var s=game.session.state
	_member_tabs(body,"inventory",id)
	UIkit.label(body,"金币 %d    草药 %d    矿石 %d    星屑 %d" % [s.gold,s.materials.herb,s.materials.ore,s.materials.shard],27,UIkit.GOLD)
	var consumables=UIkit.h(body)
	for item in ["potion","tonic","revive"]:
		UIkit.button(consumables,"%s ×%d → %s" % [{"potion":"赤松药剂","tonic":"月露灵剂","revive":"苏生药"}[item],s.items[item],game.db.actors[id].display_name],func(): _result(game.session.use_item(item,id),"inventory",id),s.battle!=null or s.items[item]<=0)
	UIkit.label(body,"每件装备有独立归属；先从原角色卸下，才能交给另一位角色。",22,UIkit.MUTED)
	var grid=GridContainer.new(); grid.columns=3; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; grid.add_theme_constant_override("h_separation",16); grid.add_theme_constant_override("v_separation",16); body.add_child(grid)
	for uid in s.gear:
		var gear=s.gear[uid]; var item=game.db.raw.items[gear.item]; var box=UIkit.v(UIkit.panel(grid)); box.custom_minimum_size.x=510
		var header=UIkit.h(box); UIkit.image(header,game.db.art("equipment",gear.item),Vector2(80,80)); UIkit.label(header,"%s +%d" % [item.name,gear.rank],25,UIkit.GOLD)
		UIkit.label(box,item.text,20,UIkit.MUTED)
		UIkit.label(box,str(item.stats),20)
		var owner_id=""
		for member in s.members.values():
			if uid in member.equip.values(): owner_id=member.id
		UIkit.label(box,"当前归属："+game.db.actors[owner_id].display_name if owner_id!="" else "当前归属：背包",20,UIkit.MUTED)
		UIkit.button(box,"卸下" if owner_id==id else "交给"+game.db.actors[id].display_name,func(): _result(game.session.equip(id,uid),"inventory",id),s.battle!=null)
		UIkit.button(box,"强化 · 矿石 / 星屑 / 金币",func(): _result(game.session.enhance(uid),"inventory",id),s.battle!=null or gear.rank>=3)

func _craft(body: VBoxContainer):
	UIkit.label(body,"旅行工坊 · 配方与材料",30,UIkit.GOLD)
	UIkit.label(body,"草药 %d  /  矿石 %d  /  星屑 %d" % [game.session.state.materials.herb,game.session.state.materials.ore,game.session.state.materials.shard],24)
	var grid=GridContainer.new(); grid.columns=3; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(grid)
	for id in game.db.raw.recipes:
		var recipe=game.db.raw.recipes[id]; var box=UIkit.v(UIkit.panel(grid)); box.custom_minimum_size.x=520
		var name=recipe.get("name",game.db.raw.items.get(recipe.get("item",""),{}).get("name",id))
		UIkit.label(box,name,25,UIkit.GOLD)
		UIkit.label(box,"材料："+_cost_text(recipe.cost),21)
		var required=recipe.get("requires",[])
		if not required.is_empty(): UIkit.label(box,"前置配方："+"、".join(required),19,UIkit.MUTED)
		UIkit.button(box,"制作",func(): _result(game.session.craft(id),"craft"),game.session.state.battle!=null)

func _cost_text(cost: Dictionary) -> String:
	var pieces=[]
	for key in cost: pieces.append("%s %d" % [{"herb":"草药","ore":"矿石","shard":"星屑","gold":"金币"}.get(key,key),cost[key]])
	return " / ".join(pieces)

func _journal(_body: VBoxContainer):
	quest_pages.journal()

func _map(body: VBoxContainer):
	UIkit.label(body,"晨星镇 · 路线与地点",32,UIkit.GOLD)
	UIkit.label(body,"六地与内室均可定位，路线按调查线索逐段开放。",23,UIkit.MUTED)
	var routes=UIkit.h(body)
	for route in GameContent.ROUTES: UIkit.button(routes,game.db.raw.scenes[route].title,func(): await game.travel_to(route),game.session.state.battle!=null)
	var grid=GridContainer.new(); grid.columns=3; grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL; body.add_child(grid)
	for building in game.db.raw.buildings:
		var card=UIkit.v(UIkit.panel(grid)); card.custom_minimum_size.x=510
		UIkit.label(card,building.name,26,UIkit.GOLD)
		UIkit.label(card,building.description,20,UIkit.MUTED)
		var id=building.id
		UIkit.button(card,"进入内室",func(): await game.travel_to("room-"+id),game.session.state.battle!=null)
		UIkit.button(card,"在城镇中定位",func():
			await game.travel_to("town"); game.world.navigate(game.world.entry(building),{"kind":"building","id":id}),game.session.state.battle!=null)

func _building(body: VBoxContainer, id: String):
	var building={}
	for candidate in game.db.raw.buildings:
		if candidate.id==id: building=candidate
	if building.is_empty(): return
	UIkit.label(body,building.name,34,UIkit.GOLD); UIkit.label(body,building.description,26)
	if game.db.progression.buildings.has(id): UIkit.button(body,"✧ "+game.db.progression.buildings[id].name,func(): game.open_menu("building-service",id))
	UIkit.button(body,"进入"+building.name,func(): await game.travel_to("room-"+id))
	if game.db.raw.entrances.has(id):
		var route=game.db.raw.entrances[id]
		if route in GameContent.ROUTES: UIkit.button(body,"前往"+game.db.raw.scenes[route].title,func(): await game.travel_to(route))
	if id=="guildhall": UIkit.button(body,"公会战术训练",func(): game.open_menu("training"))
	if id=="market": _shop(body)
	if id=="inn": UIkit.button(body,"旅店全队休息 · 补给 1",func(): game.rest_with_loading())
	if id in ["alchemist-lab","artisan-quarter"]: UIkit.button(body,"旅行工坊",func(): game.open_menu("craft"))
	UIkit.button(body,"地区行动与事件",func(): game.open_menu("region-actions"))
	if id=="royal-hall": UIkit.button(body,"前往归灯王城",func(): await game.travel_to("city"))

func _npc(body: VBoxContainer, id: String):
	var npc=game.db.raw.npcs[id]; var s=game.session.state
	var row=UIkit.h(body)
	var portrait=game.db.art("portraits",id)
	if portrait=="": portrait=game.db.art("actors",npc.get("type","villager"))
	UIkit.image(row,portrait,Vector2(260,330))
	var text=UIkit.v(row)
	UIkit.label(text,npc.name,36,UIkit.GOLD); UIkit.label(text,npc.get("role","晨星镇居民"),23,UIkit.MUTED)
	UIkit.label(text,npc.get("line","归灯仍亮着。"),28)
	UIkit.label(text,"好感 %d / 100" % s.affinity[id].value,22,UIkit.GOLD)
	UIkit.label(text,npc.get("task",""),22,UIkit.MUTED)
	var choices=UIkit.h(body)
	for topic in game.db.raw.dialogues.get(id,{}):
		var definition=game.db.raw.dialogues[id][topic]
		UIkit.button(choices,definition.title+(" · 已读" if s.dialogue.get(id+":"+topic+":read",false) else ""),func(): game.open_menu("topic",id+"|"+topic),s.affinity[id].value<float(definition.get("min",0)))
	var actions=UIkit.h(body)
	UIkit.button(actions,"赠礼 · 好感 +6",func(): _confirm("赠礼确认","赠礼会消耗材料；每日一次。星术师与祭司需要星屑，其余镇民需要草药。",func(): _result(game.session.gift(id),"npc",id)))
	if game.db.raw.personal.has(id):
		var quest=game.db.raw.personal[id]
		UIkit.button(actions,"同行委托 · "+quest.name,func(): _result(game.session.accept_personal(id),"npc",id),s.personal.get(id,{}).get("done",false))
	if game.db.raw.companions.has(id): UIkit.button(actions,"招募 · %d 金币" % game.db.raw.companions[id].cost,func(): _result(game.session.recruit(id),"npc",id),s.members.has(id))
	if id=="pella": UIkit.button(body,"交付银脉草 3 份",func(): _result(game.session.hand_in_herbs(),"npc",id))
	var service=npc.get("service",{"innkeeper":"rest","shopkeeper":"shop","guild-clerk":"guild"}.get(id,""))
	if service=="shop": _shop(body)
	elif service=="guild": UIkit.button(body,"公会战术训练",func(): game.open_menu("training"))
	elif service=="rest": UIkit.button(body,"全队休息 · 补给 1",func(): game.rest_with_loading())
	elif service!="": UIkit.button(body,"当地服务",func(): _result(game.session.service(service,id),"npc",id))
	if s.personal.has(id) and not s.personal[id].done:
		var quest=game.db.raw.personal[id]; var stage=int(s.personal[id].stage); var scene=quest.scene if stage==0 else quest.next
		UIkit.label(body,"下一步："+game.db.raw.scenes.get(scene,{}).get("title","对应调查地点")+" · "+quest.props[mini(stage,1)],22,UIkit.GOLD)

func _topic(body: VBoxContainer, subject: String):
	var parts=subject.split("|"); var id=parts[0]; var topic=parts[1]; var definition=game.db.raw.dialogues[id][topic]
	UIkit.label(body,game.db.raw.npcs[id].name+" · "+definition.title,32,UIkit.GOLD)
	for line in definition.intro: UIkit.label(body,line,29)
	UIkit.space(body,20)
	for choice in definition.options.size():
		UIkit.button(body,definition.options[choice].text,func():
			var reply=game.session.topic_choice(id,topic,choice)
			game.message(definition.title,reply,"npc",id))
	UIkit.button(body,"返回交谈",func(): game.open_menu("npc",id))

func _shop(body: VBoxContainer):
	UIkit.button(body,"打开行省杂货 · 交易",func(): game.open_menu("shop"))

func _actions(body: VBoxContainer):
	var current=game.session.state.location.scene
	UIkit.button(body,"地区行动、事件与挑战",func(): game.open_menu("region-actions"))
	if game.db.regions.has(current):
		UIkit.label(body,game.db.location_title(current),32,UIkit.GOLD)
		UIkit.label(body,game.db.regions[current].description,24,UIkit.MUTED)
		var actions=UIkit.h(body)
		UIkit.button(actions,"查看本地地图",func(): game.menus.pages.state("map").region=current; game.menus.pages.state("map").category="region"; game.open_menu("map"))
		UIkit.button(actions,"返回晨星镇",func(): await game.travel_to("town"))
		var nearby=game.db.regions[current].buildings.duplicate()
		nearby.sort_custom(func(a,b): return game.world.entry(a).distance_squared_to(game.world.player)<game.world.entry(b).distance_squared_to(game.world.player))
		for landmark in nearby.slice(0,6):
			var id=landmark.id; UIkit.button(body,landmark.name,func(): game._interact("landmark",id))
		return
	if game.session.state.location.scene!="town":
		var scene_id=game.session.state.location.scene
		UIkit.label(body,game.db.raw.scenes[scene_id].title,30,UIkit.GOLD)
		for prop in game.db.raw.scenes[scene_id].props:
			var id=prop.id; UIkit.button(body,prop.name,func(): game.close_menu(); game._interact("prop",id))
		for npc in game.db.raw.indoorNPCs.get(scene_id.trim_prefix("room-"),[]):
			var id=npc.id; UIkit.button(body,"与"+npc.name+"交谈",func(): game._interact("npc",id))
		if scene_id=="room-guildhall": UIkit.button(body,"公会战术训练",func(): game.open_menu("training"))
		if scene_id=="room-market": _shop(body)
		if scene_id=="room-inn": UIkit.button(body,"全队休息 · 补给 1",func(): game.rest_with_loading())
		UIkit.button(body,"返回晨星镇",func(): await game.travel_to("town"))
	else:
		UIkit.button(body,"地图与附近地点",func(): game.open_menu("map"))
		UIkit.button(body,"营地：队伍与转职",func(): game.open_menu("party"))
		UIkit.button(body,"旅行工坊",func(): game.open_menu("craft"))
		UIkit.button(body,"公会战术训练",func(): game.open_menu("training"))
		UIkit.button(body,"全队休息 · 补给 1",func(): game.rest_with_loading())

func _encounters(body: VBoxContainer, route: String):
	UIkit.label(body,"观察敌方，再决定是否交战。",30,UIkit.GOLD)
	for index in (3 if route in GameContent.ROUTES else 1):
		var id=route+"-"+str(index); var definition=game.db.encounters[id]
		var box=UIkit.v(UIkit.panel(body)); var row=UIkit.h(box)
		UIkit.label(row,definition.title+(" · 已战胜" if game.session.state.encounters.get(id,false) else ""),28,UIkit.GOLD)
		UIkit.label(box,definition.lesson,23)
		for enemy in definition.enemies:
			var weakness=[]
			for element in enemy.weakness: weakness.append(GameContent.ELEMENT_NAMES[element])
			UIkit.label(box,"%s  HP %d  弱点：%s" % [enemy.name,enemy.hp," / ".join(weakness)],21,UIkit.MUTED)
		var blocked=not game.session.state.training and index>0 and not game.session.state.encounters.get(route+"-"+str(index-1),false)
		UIkit.button(row,"准备交战",func(): game.load_encounter(id),blocked)
	if route not in GameContent.ROUTES and int(game.db.raw.scenes[route].get("index",0))==2:
		var place=game.db.place_of(route)
		for prefix in ["elite-","boss-","advanced-"]:
			var id=prefix+place; UIkit.button(body,game.db.encounters[id].title,func(): game.open_menu("challenge",id))

func _event(body: VBoxContainer, scene_id: String):
	var definition=game.db.raw.events[scene_id]
	UIkit.label(body,definition.title,32,UIkit.GOLD); UIkit.label(body,definition.body,28)
	for choice in 2: UIkit.button(body,definition.choices[choice],func(): game.message(definition.title,game.session.choose_event(scene_id,choice)))

func _training(body: VBoxContainer):
	UIkit.label(body,"战术训练 · 独立演练",34,UIkit.GOLD)
	UIkit.label(body,"试用六职业与全部同伴。训练不保存、不发放奖励；退出后恢复进入前的完整剧情状态。",24,UIkit.MUTED)
	if game.session.state.training:
		var row=UIkit.h(body)
		UIkit.button(row,"调整技能",func(): game.open_menu("skills"))
		UIkit.button(row,"调整战术",func(): game.open_menu("party"))
		UIkit.button(row,"训练全恢复",func(): _result(game.session.reset_training(),"training"))
		UIkit.button(row,"退出训练",game.exit_training)
		for route in GameContent.ROUTES:
			UIkit.label(body,game.db.raw.scenes[route].title,28,UIkit.GOLD); _encounters(body,route)
		return
	UIkit.label(body,"主角职业",25)
	UIkit.option(body,GameContent.JOB_ORDER.map(func(job): return GameContent.JOB_NAMES[job]),GameContent.JOB_ORDER.find(training_job),func(index): training_job=GameContent.JOB_ORDER[index])
	UIkit.label(body,"训练等级（技能全部开放，可在配置中调整）",25)
	UIkit.option(body,["2 级","6 级","12 级"],[2,6,12].find(training_level),func(index): training_level=[2,6,12][index])
	UIkit.label(body,"同伴：最多三人",25)
	var members=UIkit.h(body)
	for id in game.db.raw.companions:
		var check=CheckButton.new(); check.text=game.db.actors[id].display_name; check.button_pressed=id in training_team; check.set_meta("replace_on_refresh",true); members.add_child(check)
		check.toggled.connect(func(enabled):
			if enabled and id not in training_team:
				if training_team.size()>=3: check.set_pressed_no_signal(false); game.toast("最多选择三名同伴。")
				else: training_team.append(id)
			elif not enabled: training_team.erase(id))
	UIkit.button(body,"进入训练营",func():
		game.session.enter_training(training_job,training_team,training_level); game.world.scene_id=""; game.close_menu(); game.refresh(); game.open_menu("training"))

func _saves(body: VBoxContainer):
	UIkit.label(body,"浏览器存档管理" if BrowserFileBridge.is_browser() else "原生电脑版存档 v1",32,UIkit.GOLD)
	UIkit.label(body,BrowserFileBridge.save_notice() if BrowserFileBridge.is_browser() else "自动存档与三个手动档相互独立。此版本从新旅程开始，网页旧存档不兼容。",23,UIkit.MUTED)
	for slot in 4:
		var row=UIkit.h(UIkit.panel(body)); UIkit.label(row,"自动存档" if slot==0 else "手动档 %d" % slot,26)
		UIkit.button(row,"读取",func(): game.load_continue(slot),not FileAccess.file_exists(game.store.path_for(slot)) and not FileAccess.file_exists(game.store.path_for(slot)+".bak"))
		if slot>0: UIkit.button(row,"保存到此处",func(): _confirm("保存确认","将覆盖这个手动档；其他档位保留。",func(): _result(game.store.save(slot),"saves")),game.session.state.is_empty() or game.session.state.training)
	var row=UIkit.h(body)
	UIkit.button(row,"导出 JSON",func(): _file_dialog(true),game.session.state.is_empty() or game.session.state.training)
	UIkit.button(row,"导入 JSON",func(): _file_dialog(false))
	if not BrowserFileBridge.is_browser(): UIkit.button(row,"打开存档目录",func(): OS.shell_open(ProjectSettings.globalize_path(game.store.base_path)))

func _file_dialog(exporting: bool):
	if BrowserFileBridge.is_browser():
		if not is_instance_valid(browser_files):
			browser_files=BrowserFileBridge.new(); game.add_child(browser_files); browser_files.setup(game)
		if exporting: browser_files.export_save()
		else: browser_files.import_save()
		return
	var dialog=FileDialog.new(); dialog.access=FileDialog.ACCESS_FILESYSTEM; dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE if exporting else FileDialog.FILE_MODE_OPEN_FILE; dialog.use_native_dialog=true; dialog.filters=PackedStringArray(["*.json ; 灰烬边境存档"])
	if exporting: dialog.current_file="ashen-frontier-native-desktop.json"
	game.add_child(dialog)
	dialog.file_selected.connect(func(path):
		var error=game.store.export_to(path) if exporting else game.store.import_from(path)
		if error!="": game.toast(error)
		else:
			game.toast("导出完成。" if exporting else "导入成功。")
			if not exporting: game.mode="world"; game.world.scene_id=""; game.close_menu(); game.refresh()
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.7)

func _settings(body: VBoxContainer):
	UIkit.label(body,"显示与操作",32,UIkit.GOLD)
	UIkit.button(body,"切换全屏 / 窗口",func(): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN))
	var check=CheckButton.new(); check.text="减少动效 / 加快自动回合"; check.button_pressed=game.session.state.settings.reduce_motion; body.add_child(check)
	check.toggled.connect(func(enabled): game.session.state.settings.reduce_motion=enabled; game.session.changed.emit())
	_slider(body,"总音量",game.session.state.settings.master_volume,func(value): game.session.state.settings.master_volume=value; AudioServer.set_bus_volume_db(0,linear_to_db(maxf(value,0.001))); game.session.changed.emit())
	UIkit.label(body,"WASD / 方向键：移动    Shift：跑步    E：交互\n探索时按住 Tab：快捷轮盘    Esc：返回 / 战斗暂停\n战斗按 1–4：选择技能    Enter：确认行动",25,UIkit.MUTED)
	UIkit.button(body,"存档与 JSON 导入导出",func(): game.open_menu("saves"))
	UIkit.button(body,"返回标题",func():
		if game.session.state.training: game.session.exit_training()
		game.mode="title"; game.close_menu(); game.refresh())

func _battle_items(body: VBoxContainer):
	for item in ["potion","tonic","revive"]:
		var item_button=UIkit.button(body,"%s ×%d" % [{"potion":"赤松药剂 · 恢复 40 生命","tonic":"月露灵剂 · 恢复 30 法力","revive":"苏生药 · 恢复倒地队员"}[item],game.session.engine.battle.items[item]],func(): game.close_menu(); game.choose_action(item),game.session.engine.battle.items[item]<=0)
		item_button.icon=load(ItemIcons.path(game.db,item)); item_button.expand_icon=true; item_button.add_theme_constant_override("icon_max_width",32)

func _combos(body: VBoxContainer):
	var actor=game.session.engine.current()
	for id in game.session.state.active:
		if id=="hero": continue
		var partner=game.session.engine.unit(id)
		UIkit.button(body,game.db.actors[id].display_name+" · "+BattleRules.config().bonds[id].name+"（10 MP / 好感 60）",func(): game.close_menu(); game.choose_action("bond",id),partner.get("bond",0)<60 or partner.hp<=0 or actor.mp<10 or int(actor.cooldowns.get("bond:"+id,0))>0)
		UIkit.label(body,BattleRules.config().bonds[id].desc,20,UIkit.MUTED)
	for pair in game.db.raw.pairs: UIkit.button(body,pair.name+" · 双方存活 / 好感 60 / 协奏 100",func(): game.close_menu(); game.choose_action("pair",pair.id),not _pair_ready(pair.id))

func _confirm(title: String, detail: String, callback: Callable):
	game.push_current_menu(); game.clear(game.overlay_root); game.overlay="confirm"
	var root=game.overlay_root
	UIkit.card(root,Vector2.ZERO,Vector2(1920,1080),Color(0.25,0.28,0.30,0.25),Color.TRANSPARENT)
	var panel=UIkit.card(root,Vector2(500,300),Vector2(920,460),UIkit.PAPER)
	UIkit.text(panel,title,Vector2(46,38),Vector2(828,65),36,UIkit.GOLD)
	UIkit.text(panel,detail,Vector2(46,135),Vector2(828,150),28)
	var used=[false]
	UIkit.action(panel,"确认",Vector2(470,350),Vector2(404,60),func():
		if used[0]: return
		used[0]=true; callback.call(),true)
	UIkit.action(panel,"取消",Vector2(46,350),Vector2(404,60),game.back_menu).set_meta("default_focus",true)
	game._focus_menu.call_deferred()

func _result(text: String, kind: String, subject: String = "hero"):
	if text!="": game.toast(text)
	game.replace_menu(kind,subject)

func _wheel():
	var wheel=QuickWheel.new(); UIkit.fill(wheel); game.overlay_root.add_child(wheel)
	game.quick_wheel=wheel

func wheel_action(index: int):
	if index<0 or index>=QuickWheel.ENTRIES.size(): return
	var id=QuickWheel.ENTRIES[index].id
	if id=="rest": game.rest_with_loading()
	else: game.open_menu(id)

func _npc_dialogue(id: String):
	var npc=game.db.raw.npcs[id]; var s=game.session.state; var options=[]; var callbacks=[]
	for topic in game.db.raw.dialogues.get(id,{}):
		if game.session.topic_completed(id,topic): continue
		var definition=game.db.raw.dialogues[id][topic]
		options.append({"text":definition.title,"disabled":s.affinity[id].value<float(definition.get("min",0))})
		callbacks.append(func(): game.open_menu("topic",id+"|"+topic))
	var main_stage=int(s.story.stage)
	if id=="mira" and main_stage in [0,2,7]:
		var op={0:"begin",2:"route",7:"finish"}[main_stage]
		options.append({"text":{0:"接受星图委托",2:"共同解读碑文",7:"补全最后一笔星图"}[main_stage],"disabled":not s.chapter_complete})
		callbacks.append(func(): _result(game.session.story.npc_choice(id,op),"npc",id))
	quest_pages.npc_options(id,options,callbacks)
	if id!="mira":
		for rule in game.db.narrative.stages:
			if rule.get("npc","")==id and int(rule.from)==main_stage:
				options.push_front({"text":"主线 · 核对星钟线索"}); callbacks.push_front(func(): _result(game.session.story.npc_choice(id,"story"),"npc",id))
	if id=="mira" and not s.story.events.get("epilogue",false): options.append({"text":"收尾 · 归灯之后","disabled":s.story.stage<8}); callbacks.append(func(): _result(game.session.story.epilogue(),"npc",id))
	options.append({"text":"赠礼 · 好感 +6"}); callbacks.append(func(): _confirm("赠礼确认","消耗一份赠礼材料，每日一次；米拉与艾拉需要星屑，其他镇民依偏好收取材料。",func():
		var text=game.session.gift(id); game.message(npc.name,text,"npc",id,"smile" if "好感" in text else "neutral")))
	if game.db.raw.companions.has(id) and not s.members.has(id):
		options.append({"text":"招募 · %d 金币" % game.db.raw.companions[id].cost})
		callbacks.append(func(): _result(game.session.recruit(id),"npc",id))
	if game.db.progression.ultimates.has(id) and game.session.progression.available(id) and not game.session.progression.unlocked(id):
		options.append({"text":"觉醒 · "+game.db.progression.ultimates[id].title}); callbacks.append(func(): game.open_menu("awakening",id))
	var service=npc.get("service",{"innkeeper":"rest","shopkeeper":"shop","guild-clerk":"guild"}.get(id,""))
	if service in ["shop","market","forge"]: options.append({"text":"旅行补给 · 交易"}); callbacks.append(func(): game.open_menu("shop","forge" if service=="forge" else "hero"))
	elif service in ["tavern","lighthouse"]: options.append({"text":"听取旅途插曲"}); callbacks.append(func(): game.open_menu("core-event",service))
	elif service=="guild":
		options.append({"text":"公会委托板"}); callbacks.append(func(): game.open_menu("commission-board"))
		options.append({"text":"公会战术训练"}); callbacks.append(func(): game.open_menu("training"))
	elif service=="rest": options.append({"text":"全队休息 · 补给 1"}); callbacks.append(func(): game.rest_with_loading())
	elif service!="": options.append({"text":"当地服务"}); callbacks.append(func():
		if service in ["city:guide","city:archive","city:music"]: game.menus.story_pages.perform_activity(service)
		elif service.begins_with("world:") or service.begins_with("city:"): game.open_menu("local-service",service)
		else: game.menus.story_pages.perform_activity(service))
	var portrait=game.db.art("portraits",id)
	if portrait=="": portrait=game.db.art("actors",npc.get("type","villager"))
	options.append({"text":"当地行动与服务"}); callbacks.append(func(): game.open_menu("region-actions"))
	var line=game.session.story.greeting(id)
	game.show_dialogue(npc.name+"  /  好感 %d" % s.affinity[id].value,portrait,[line],options,func(index): callbacks[index].call())

func _topic_dialogue(subject: String):
	var parts=subject.split("|"); var id=parts[0]; var topic=parts[1]; var definition=game.db.raw.dialogues[id][topic]
	var mood="serious" if topic in ["past","deep","secret","duty"] else "neutral"
	var options=[]
	for option in definition.options: options.append({"text":option.text})
	game.show_dialogue(game.db.raw.npcs[id].name,game.db.art("portraits",id,mood),definition.intro,options,func(index):
		var reply=game.session.topic_choice(id,topic,index)
		game.message(game.db.raw.npcs[id].name,reply,"npc",id,mood))

func _pair_ready(id: String) -> bool:
	var engine=game.session.engine; var actor=engine.current()
	if actor.is_empty(): return false
	var targets=engine.legal_targets(actor,"pair",id)
	return not targets.is_empty() and engine.validate(BattleCommand.new(actor.id,"pair",targets[0].id,id,engine.battle.token).to_dict())==""

func _formations(body: VBoxContainer):
	var engine=game.session.engine; var actor=engine.current()
	UIkit.label(body,"变阵消耗当前角色一次行动；全队每轮最多一次，不获得 TP 或协奏。",24)
	for id in game.db.raw.formations:
		var command=BattleCommand.new(actor.id,"formation",actor.id,id,engine.battle.token).to_dict()
		var error=engine.validate(command)
		var node=UIkit.button(body,game.db.raw.formations[id].name+(" · 当前阵型" if id==engine.battle.formation else ""),func(): game.close_menu(); game.choose_action("formation",id),error!="")
		node.icon=load(ItemIcons.path(game.db,id)); node.expand_icon=true; node.add_theme_constant_override("icon_max_width",30)
		UIkit.label(body,game.db.raw.formations[id].desc+("\n"+error if error!="" else ""),21,UIkit.MUTED)
	UIkit.label(body,"属性克制：火焰 → 物理 → 星辉 → 圣光 → 毒素 → 火焰；克制 ×1.25，受克 ×0.8。弱点独立决定能否削韧。",23)
