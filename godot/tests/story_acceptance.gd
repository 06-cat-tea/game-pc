extends RefCounted

var suite
var verify: Callable
var db
var flow=[]
var completed=false

func p(scene,id) -> Dictionary:
	for prop in db.raw.scenes[scene].props:
		if prop.id==id: return prop
	return {}

func inspect(g,scene,id):
	var e=g.tasks.entrance_for(scene)
	if not e.is_empty(): g.tasks.discover(e.id)
	var result=g.visit(scene); verify.call(result=="","剧情前往："+scene+" "+result)
	g.inspect_prop(scene,p(scene,id))

func battle(g,id):
	if g.state.supplies<1: g.buy("supply")
	var previous=g.state.location.scene
	g.visit("town"); g.rest(); g.visit(previous)
	var result=g.start_battle(id,912+flow.size()); verify.call(result=="","剧情战斗可发起："+id+" "+result)
	if result!="": return
	if db.encounters[id].story.has("challenge"):
		var policy=load("res://tests/strategy_policy.gd").new(db); var count=0
		while g.state.battle!=null and count<600:
			var resolved=g.combat(policy.tactical(g.engine)); verify.call(resolved.error=="","剧情针对性指令有效："+id); count+=1
		verify.call(count<600 and g.engine.battle.result=="win","正常成长以针对性策略完成挑战："+id)
	else: verify.call(suite.fight(g)=="win","正常成长完成剧情战斗："+id)
	flow.append(id)

func run(owner,check: Callable):
	suite=owner; verify=check; db=owner.db
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative-manifest.json"))
	verify.call(db.raw.npcs.size()==69 and db.raw.scenes.size()==66,"保留原 66 人物，新增 3 名儿童与 66 场景")
	verify.call(manifest.counts.topics==204 and manifest.counts.props==242 and db.narrative.lore.size()==15,"204 话题、242 物件、15 篇世界观")
	for file in manifest.resources: verify.call(ResourceLoader.exists("res://"+file),"完整迁入原有资源："+file)
	for id in db.narrative.npcs:
		verify.call(db.raw.dialogues.has(id) and db.art("portraits",id)!="","人物有完整对话与头像："+id)
		verify.call(db.narrative.indoor.values().any(func(list): return list.any(func(n): return n.id==id)) or db.raw.npcs[id].has("position"),"人物有实际场景入口："+id)
	var dialogue_game=GameSession.new(db); dialogue_game.new_game()
	for id in db.raw.dialogues:
		dialogue_game.state.affinity[id].value=100
		for topic in db.raw.dialogues[id]:
			var d=db.raw.dialogues[id][topic]
			verify.call(dialogue_game.topic_choice(id,topic,0)==d.options[0].reply+"\n\n"+d.end,"原文话题与结束语："+id+":"+topic)
	var g=GameSession.new(db); g.new_game("warden")
	var old=g.state.duplicate(true); old.erase("story"); old.erase("shadow"); old.erase("danger")
	for id in old.affinity.keys():
		if id not in db.chapter_npcs and not db.raw.companions.has(id): old.affinity.erase(id)
	verify.call(g.validate_save(old)=="" and g.load_state(old)=="","旧 v1 缺省新增人物与剧情记录可读取")
	verify.call(g.state.story.stage==0 and not g.state.chapter_complete,"旧档不推断未发生的主线选择")
	var migration_store=SaveStore.new(g,"user://tests/story-migration")
	migration_store.write_json(migration_store.path_for(2),old)
	verify.call(migration_store.load_slot(2)=="" and FileAccess.file_exists(migration_store.path_for(2)+".before-content-v1.json"),"旧 v1 实际读取前保留独立迁入备份")
	inspect(g,"room-clocktower","star-chart"); g.visit("room-royal-hall"); g.service("world:royal-record","royal-heir")
	inspect(g,"room-inn","supplies-cache"); g.recruit("mira"); g.visit("room-chapel"); g.accept_personal("eira")
	g.inspect_prop("room-chapel",p("room-chapel","prayer-book")); g.inspect_prop("room-chapel",p("room-chapel","altar")); g.tasks.turn_in("personal:eira","eira"); g.recruit("eira")
	g.visit("room-guildhall"); g.tasks.accept("first","board")
	for route in GameContent.ROUTES:
		inspect(g,route,"supplies-cache"); inspect(g,route,"survey"); g.choose_event(route,0)
		for i in 3: battle(g,route+"-"+str(i))
	verify.call(g.state.chapter_complete and g.state.story.stage==0,"保留原生序章，主线独立等待接受")
	g.visit("room-clocktower"); g.story.npc_choice("mira","begin"); verify.call(g.state.story.stage==1,"与米拉正式开启完整主线")
	g.visit("town"); g.story.accept_investigation("expeditions","town"); g.story.accept_investigation("regional","town"); inspect(g,"room-clocktower","star-chart")
	g.visit("town"); g.story.activity("guild"); inspect(g,"town-wall","survey"); inspect(g,"town-drain","survey"); inspect(g,"town-trial","survey")
	g.visit("town"); g.tasks.turn_in("regional:town","pella"); g.tasks.turn_in("expeditions:town","mira")
	verify.call(g.state.story.regional.town.done and g.state.story.expeditions.town.done,"重复核验已读物件完成新接取的调查，不重领容器")
	g.visit("wood"); verify.call(g.recruit("sylvi").contains("加入"),"按圣光条件招募希薇")
	g.tasks.accept("quest:pages","sylvi"); g.tasks.discover("entrance-wood-trail"); g.story.npc_choice("sylvi"); g.story.accept_investigation("regional","wood"); g.story.accept_investigation("expeditions","wood"); g.accept_personal("sylvi")
	inspect(g,"room-forest-hut","field-notes"); g.visit("wood"); g.story.activity("ruins"); g.story.activity("ruins")
	g.tasks.turn_in("quest:pages","sylvi")
	verify.call(g.state.story.stage==2 and g.state.story.quests.pages.done,"两次碑文调查推进原主线并发放任务奖励")
	g.visit("room-clocktower"); g.story.npc_choice("mira","route"); g.visit("pass"); g.story.npc_choice("toren")
	verify.call(g.state.story.stage==4 and g.recruit("toren").contains("加入"),"托伦确认运星车并满足原招募条件")
	g.tasks.discover("entrance-pass-path"); g.story.accept_investigation("regional","pass"); g.story.accept_investigation("expeditions","pass"); g.accept_personal("toren")
	inspect(g,"room-grayforge","anvil"); inspect(g,"room-waystation","route-board"); g.visit("pass"); g.story.activity("mine")
	for attempt in 8:
		if g.state.story.stage>=5: break
		g.story.activity("escort")
		if g.state.battle!=null: verify.call(suite.fight(g)=="win","护送遇袭通过真实战斗结算")
	verify.call(g.state.story.stage==5,"护送成功后推进至月沼线索")
	g.visit("fen"); g.story.npc_choice("eira"); g.tasks.accept("quest:moon","eira"); g.tasks.discover("entrance-fen-temple"); g.story.accept_investigation("regional","fen"); g.story.accept_investigation("expeditions","fen")
	inspect(g,"room-chapel","prayer-book"); g.visit("fen"); g.story.activity("purify"); g.story.activity("temple")
	verify.call(g.state.battle!=null,"神殿行动发起守门人战斗")
	if g.state.battle!=null: verify.call(suite.fight(g)=="win","神殿战斗正常完成")
	verify.call(g.state.story.stage==7,"守门人战胜后保留完整主线阶段")
	g.visit("room-clocktower"); g.story.npc_choice("mira","finish")
	verify.call(g.state.story.stage==8 and g.state.story.quests.stars.done,"补全星图并完成原版主线奖励")
	var gold=g.state.gold; g.story.npc_choice("mira","finish"); verify.call(g.state.gold==gold,"主线完成奖励不可重复领取")
	g.visit("coast"); g.story.npc_choice("lian"); g.tasks.discover("entrance-coast-reef"); g.story.accept_investigation("regional","coast"); g.story.accept_investigation("expeditions","coast")
	inspect(g,"room-lighthouse","captain-letter"); g.visit("coast"); g.story.activity("fish"); g.story.core_event("lighthouse","name")
	for region in ["wood","pass","fen","coast"]:
		for route in db.route_ids(region):
			inspect(g,route,"supplies-cache"); inspect(g,route,"survey"); g.choose_event(route,0)
			battle(g,route+"-0")
		g.visit(region); g.tasks.turn_in("expeditions:"+region,db.narrative.expeditions[region].npc); g.tasks.turn_in("regional:"+region,db.narrative.regional[region].npc)
		verify.call(g.state.story.expeditions[region].done,"完整三段路线调查："+region)
		g.visit(region); battle(g,"boss-"+region)
	g.visit("wood"); g.tasks.turn_in("personal:sylvi","sylvi"); g.visit("pass"); g.tasks.turn_in("personal:toren","toren")
	verify.call(g.state.personal.sylvi.done and g.state.personal.toren.done,"森林与峡道个人任务正常衔接")
	g.visit("room-ridge-barracks"); g.accept_personal("ridge-scout"); g.inspect_prop("room-ridge-barracks",p("room-ridge-barracks","local-record")); inspect(g,"pass-path","survey")
	g.visit("pass"); g.tasks.turn_in("personal:ridge-scout","ridge-scout"); verify.call(g.recruit("ridge-scout").contains("加入"),"个人任务完成后招募夜岚")
	g.visit("room-alchemist-lab"); g.accept_personal("alchemist"); g.inspect_prop("room-alchemist-lab",p("room-alchemist-lab","local-record"))
	while g.state.materials.herb<3: g.visit("wood"); g.story.activity("forage")
	inspect(g,"wood-trail","survey"); g.visit("room-alchemist-lab"); g.tasks.turn_in("personal:alchemist","alchemist"); verify.call(g.recruit("alchemist").contains("加入"),"个人任务完成后招募瑟琳")
	verify.call(g.state.members.size()==7,"全部六位同伴通过正常条件加入")
	inspect(g,"room-clocktower","clockwork"); g.story.epilogue()
	verify.call(g.state.story.events.get("epilogue",false),"新游戏完整走到归灯之后")
	gold=g.state.gold; g.story.epilogue(); verify.call(g.state.gold==gold,"归灯收尾只结算一次")
	g.visit("town"); g.rest(); g.story.npc_choice("pella"); g.visit("wood")
	for i in 3: g.story.activity("forage")
	g.visit("pass")
	for i in 5:
		if g.state.story.quests.caravan.done: break
		g.story.activity("escort")
		if g.state.battle!=null: verify.call(suite.fight(g)=="win","居民矿车委托中的遇袭可继续完成")
	g.visit("fen"); g.story.npc_choice("eira")
	for id in ["candle","moon","pact"]: g.tasks.accept("quest:"+id,"eira")
	for i in 3: g.story.activity("purify")
	g.story.activity("temple")
	if g.state.battle!=null: verify.call(suite.fight(g)=="win","重复神殿行动完成沉星回声委托")
	for i in 2:
		g.story.activity("crypt")
		if g.state.battle!=null: verify.call(suite.fight(g)=="win","王陵调查遇敌可继续完成")
	g.story.activity("whisper"); g.visit("coast"); g.tasks.accept("quest:wreck","lian")
	for i in 3:
		g.story.activity("wreck")
		if g.state.battle!=null: verify.call(suite.fight(g)=="win","沉船调查遇敌可继续完成")
	for task in g.tasks.ledger.records:
		if g.tasks.status(task)!="ready": continue
		var d=g.tasks.definition(task); var target=g.tasks.target(task)
		g.visit(target.scene); g.tasks.turn_in(task,d.turnin)
	for id in db.narrative.quests:
		verify.call(g.state.quests.first.done if id=="first" else g.state.story.quests.get(id,{}).get("done",false),"全部原版委托可正常完成："+id)
	var save_error=g.validate_save(JSON.parse_string(JSON.stringify(g.state)))
	verify.call(save_error=="","完整结局存档结构合法："+save_error+str(g.state.active.map(func(id): return [id,g.state.members[id].slot])))
	var resumed=GameSession.new(db); resumed.new_game(); resumed.load_state(JSON.parse_string(JSON.stringify(g.state)))
	verify.call(JSON.parse_string(JSON.stringify(resumed.state))==JSON.parse_string(JSON.stringify(g.state)),"全部剧情、人物与调查状态存读一致")
	var snapshot=g.state.duplicate(true); g.enter_training("warden",["mira"],6); g.story.activity("forage"); g.story.claim("quest3"); g.exit_training()
	verify.call(snapshot==g.state,"训练隔离新增故事与成就记录")
	for event_id in db.narrative.events:
		for choice in 2:
			var e=GameSession.new(db); e.new_game(); e.state.materials={"herb":5,"ore":5,"shard":5}; e.visit(db.narrative.events[event_id].place)
			verify.call(e.story.choose_event(event_id,choice)==db.narrative.events[event_id].options[choice].text,"地区事件分支保留原文："+event_id+":"+str(choice))
			var after=e.state.duplicate(true); e.story.choose_event(event_id,choice); verify.call(after==e.state,"地区事件分支防重复："+event_id)
	for event_id in db.narrative.coreEvents:
		for option in db.narrative.coreEvents[event_id].options:
			var e=GameSession.new(db); e.new_game(); e.visit("coast" if event_id=="lighthouse" else "town")
			var reply=e.story.core_event(event_id,option[0]); verify.call(reply!="" and e.state.story.events.has("core:"+event_id+":"+option[0]),"完整旅途插曲可结算："+event_id+":"+option[0])
			var after=e.state.duplicate(true); e.story.core_event(event_id,option[0]); verify.call(after==e.state,"旅途插曲重复点击不再结算："+event_id+":"+option[0])
	for key in db.narrative.services:
		var e=GameSession.new(db); e.new_game(); e.state.materials={"herb":9,"ore":9,"shard":9}
		var place=""
		for b in db.narrative.buildings:
			if b.get("action","")=="world:"+key: place=b.place; break
		if place=="":
			for npc in db.raw.npcs.values():
				if npc.get("service","")=="world:"+key: place=npc.get("place",""); break
		e.visit(place); var reply=e.story.service("world:"+key)
		verify.call(reply.contains("行动完成") or reply.contains(db.narrative.services[key].name),"全部地区服务可从所属地区执行："+key+" "+reply)
	for id in db.narrative.challenges:
		var c=GameSession.new(db); c.new_game(); c.enter_training("warden",["mira","eira","toren"],16)
		verify.call(c.start_battle(id,871)=="" and suite.fight(c)=="win","全部普通、区域与进阶挑战可完成："+id)
	for id in db.encounters:
		if not id.begins_with("roam-") and not id.begins_with("roamelite-"): continue
		var c=GameSession.new(db); c.new_game(); c.enter_training("warden",["mira","eira","toren"],12)
		verify.call(c.start_battle(id,873)=="" and suite.fight(c)=="win","全部原版野外敌人与掉落配置可战斗："+id)
	for scene in db.raw.scenes:
		var c=GameSession.new(db); c.new_game(); c.state.location={"scene":scene,"x":8.5,"y":8.5}
		for prop in db.raw.scenes[scene].props:
			if prop.action in ["event","portal","encounter"]: continue
			verify.call(c.inspect_prop(scene,prop)!="","全量调查物件可实际读取："+scene+":"+prop.id)
	for place in GameContent.OUTDOORS:
		var c=GameSession.new(db); c.new_game(); c.visit(place)
		var gold_before=c.state.gold; var shadow_before=c.state.shadow
		c.story.claim("quest3"); verify.call(c.state.gold==gold_before and c.state.shadow==shadow_before,"未达成成就不发奖："+place)
	var broken=g.state.duplicate(true); broken.story.metrics={}
	verify.call(g.validate_save(broken)!="","损坏的新增战斗履历会被拒绝")
	broken=g.state.duplicate(true); broken.story.returns=[{"scene":"unknown","x":0,"y":0}]
	verify.call(g.validate_save(broken)!="","损坏的场景返回记录会被拒绝")
	var before_event=g.state.duplicate(true); g.visit("wood"); g.state.materials.herb=0
	verify.call(g.story.choose_event("wood-deer",0)=="材料不足。" and not g.state.story.events.has("wood-deer"),"事件材料不足不提交选择")
	g.state=before_event
	var checkpoint=g.state.duplicate(true); g.visit("wood"); g.start_battle("roam-wood-0",422)
	var restored=GameSession.new(db); restored.new_game(); var error=restored.load_state(JSON.parse_string(JSON.stringify(g.state)))
	verify.call(error=="" and restored.state.battle!=null and restored.state.battle.encounter=="roam-wood-0","新增遭遇支持战斗中存读档："+error)
	if error=="": verify.call(suite.fight(restored)=="win","读档后的新增遭遇继续完成")
	g.state=checkpoint; g.engine.battle={}
	var danger_test=GameSession.new(db); danger_test.new_game(); danger_test.visit("wood"); danger_test.state.danger=2; danger_test.start_battle("roam-wood-0",412)
	verify.call(danger_test.engine.unit("enemy-0").max_hp==db.encounters["roam-wood-0"].enemies[0].hp+14,"世界危险度实际增加野外敌人强度")
	for id in ["quest1","quest2","quest3","battle1","bond1"]:
		if g.story.achievement_complete(id):
			g.story.claim(id); gold=g.state.gold; g.story.claim(id); verify.call(g.state.gold==gold,"成就奖励只发放一次："+id)
	await ui_acceptance(owner)
	var report={"passed":suite.failures.is_empty(),"normal_flow":flow,"final_stage":g.state.story.stage,"epilogue":g.state.story.events.get("epilogue",false),"members":g.state.members.keys(),"counts":manifest.counts}
	var destination=OS.get_environment("ASHEN_REPORT").get_base_dir().path_join("content-flow.json")
	var file=FileAccess.open(destination,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report,"  ")); file.close()
	completed=true

func ui_acceptance(owner):
	var game=load("res://scenes/main.tscn").instantiate(); owner.root.add_child(game); await owner.process_frame; game.capture_mode=true; game.new_game("warden")
	for kind in ["people","lore","achievements","journal","region-actions","terminal"]:
		game.open_menu(kind); await owner.process_frame
		verify.call(RailAudit.inspect(game.overlay_root).passed,"新增内容页布局无裁切："+kind)
		verify.call(game.world.blocked,"新增内容页阻断场景输入："+kind)
	game.navigate("coast"); game.open_menu("local-service","world:harbor-trade"); await owner.process_frame
	verify.call(RailAudit.inspect(game.overlay_root).passed,"居民服务显示真实消耗与确认按钮")
	game.navigate("city"); game.open_menu("building","city-palace-0"); await owner.process_frame
	verify.call(game.overlay_root.get_child_count()>0,"王城建筑可进入详情及内室")
	for scene in ["room-city-palace-0","room-forest-hut","fen-temple","room-lighthouse"]:
		var e=game.session.tasks.entrance_for(scene)
		if not e.is_empty():
			verify.call(game.session.visit(scene)!="","未发现的路线拒绝直接定位")
			game.session.tasks.discover(e.id)
		game.navigate(scene); await owner.process_frame
		verify.call(game.world.targets.any(func(t): return t.kind=="exit"),"新增内室与路线提供返回入口："+scene)
		verify.call(game.session.story.return_scene()==game.db.place_of(scene),"跨区域直接定位内室后返回所属区域："+scene)
	game.navigate("town"); game.queue_free(); await owner.process_frame
