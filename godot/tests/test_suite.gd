extends SceneTree

var db: GameContent
var failures = []
var checks = 0
var results = []

func _initialize():
	call_deferred("run")

func check(condition: bool, description: String):
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)

func fixture(job: String = "ranger", team: Array = ["mira","toren","eira"], level: int = 6) -> GameSession:
	var game=GameSession.new(db); game.new_game(job); game.enter_training(job,team,level); game.start_battle("town-trial-2",417)
	return game

func hero_turn(engine: BattleEngine):
	var count=0
	while not engine.current().is_empty() and engine.current().id!="hero" and count<30:
		engine.submit(engine.ai_command()); count+=1

func fight(game: GameSession, limit: int = 600) -> String:
	var count=0
	while game.state.battle!=null and count<limit:
		var command=game.engine.ai_command()
		var result=game.combat(command)
		if result.error!="": check(false,"AI 指令有效："+result.error); break
		count+=1
	check(count<limit,"战斗在有限行动内结束")
	return game.engine.battle.result

func prop(scene: String, id: String) -> Dictionary:
	for p in db.raw.scenes[scene].props:
		if p.id==id: return p
	return {}

func run():
	var watchdog=create_timer(240)
	watchdog.timeout.connect(func(): push_error("Native tests timed out"); quit(2))
	db=GameContent.new()
	check(db.skills.size()==90,"保留 90 个技能节点")
	check(db.actors.size()==7 and db.raw.jobs.size()==6,"主角、六同伴与六职业")
	check(db.chapter_scenes.size()==14 and db.raw.buildings.size()==11,"保留首章 11 建筑、14 场景子集")
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/resource-manifest.json"))
	for relative in manifest.files: check(ResourceLoader.exists("res://"+relative),"运行素材可独立读取："+relative)
	_test_growth()
	_test_personal_passives()
	_test_combat()
	await load("res://tests/strategy_acceptance.gd").new().run(self,check)
	await load("res://tests/loading_carousel_acceptance.gd").new().run(self,check)
	_test_status_and_resume()
	_test_all_skills()
	_test_saves()
	await load("res://tests/browser_platform_acceptance.gd").new().run(self,check)
	_test_chapter()
	await load("res://tests/quest_acceptance.gd").new().run(self,check)
	await load("res://tests/quest_input_acceptance.gd").new().run(self,check)
	await _test_ui()
	var dialogue_input=load("res://tests/dialogue_input_acceptance.gd").new()
	await dialogue_input.run(self,check)
	check(dialogue_input.completed,"旅行储物柜真实鼠标与键盘返回专项完整执行")
	results.append("物件对白：真实F开启，Enter、空格、正文点击、返回按钮、Esc与顶部返回恢复移动，存档及返回晨星镇")
	await load("res://tests/rail_ui_acceptance.gd").new().run(self,check)
	await load("res://tests/quick_wheel_acceptance.gd").new().run(self,check)
	await load("res://tests/native_upgrade_acceptance.gd").new().run(self,check)
	var awakening_acceptance=load("res://tests/awakening_acceptance.gd").new()
	await awakening_acceptance.run(self,check)
	check(awakening_acceptance.completed,"觉醒、TP、建筑与输入专项完整执行")
	results.append("七人觉醒全流程与专属大招、个人TP跨战保留、十二建筑与新内室、实际JSON升级、快捷键与特效事件去重")
	await load("res://tests/refined_ui_acceptance.gd").new().run(self,check)
	await load("res://tests/regions_acceptance.gd").new().run(self,check)
	await load("res://tests/royal_daylight_acceptance.gd").new().run(self,check)
	var content_acceptance=load("res://tests/story_acceptance.gd").new()
	await content_acceptance.run(self,check)
	check(content_acceptance.completed,"完整剧情验收执行到末尾，不能因脚本错误跳过")
	results.append("五地探索：71 地标可达、桥梁与水域、王城大坐标 v1 存读、缩放平移、动效与遮挡、训练隔离和缓存")
	results.append("浅色主题对比度、三层地表坐标、装饰避让、真实场景地图、旧档落点与节点缓存")
	results.append("简洁图标轮盘：八方向与边界、统一高亮及提交、取消与失焦、单次休息、焦点和移动隔离")
	results.append("星轨 UI：鼠标命中、导航状态、全页布局、对话单次结算、空物品、六敌与前后排站位")
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"results":results,"engine":Engine.get_version_info().string}
	var destination=OS.get_environment("ASHEN_REPORT")
	if destination=="": destination="user://tests/native-acceptance.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination).get_base_dir())
	var file=FileAccess.open(destination,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("NATIVE ACCEPTANCE: "+JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_growth():
	var game=GameSession.new(db); game.new_game("warden")
	check(game.validate_save(game.state)=="","新档结构有效")
	check(not game.recruit("mira").contains("加入"),"米拉保留招募门槛")
	game.state.knowledge=1
	check(game.recruit("mira").contains("加入"),"符合门槛可招募米拉")
	check(not game.state.members.has("toren") and not game.recruit("toren").contains("加入"),"不提前开放外区同伴")
	game.state.materials.herb=1
	game.visit("room-chapel"); game.accept_personal("eira")
	game.inspect_prop("room-chapel",prop("room-chapel","prayer-book"))
	game.inspect_prop("room-chapel",prop("room-chapel","altar"))
	game.tasks.turn_in("personal:eira","eira")
	check(game.state.personal.eira.done and "priest" in game.state.unlocked_jobs,"礼拜堂导师任务开放牧师")
	game.state.gold=100
	game.tasks.turn_in("personal:eira","eira"); game.recruit("eira")
	check(game.state.members.has("eira"),"艾拉沿用个人委托后招募")
	game.visit("town")
	var mira=game.state.members.mira; var before=mira.level
	game.grant_xp(["hero"],200)
	check(mira.level==before and mira.xp==0,"各角色独立经验与等级")
	var uid=game.state.members.hero.equip.weapon
	check(game.equip("mira",uid).contains("先卸下"),"装备不能被两名角色同时穿戴")
	game.equip("hero",uid); game.equip("mira",uid)
	check(game.state.members.mira.equip.weapon==uid and game.state.members.hero.equip.weapon=="","装备可卸下后转交")
	game.state.members.hero.level=6; game.state.members.hero.skill_points=10
	var refunded=game.state.members.hero.skill_points
	for id in game.state.members.hero.learned: refunded+=int(db.skills[id].data.cost)
	game.respec("hero")
	check(game.state.members.hero.skill_points==refunded and game.state.members.mira.learned.size()>0,"重配只退还对应角色技能点")
	check(game.learn("hero","bulwark")!="","学习验证前置技能")
	game.learn("hero","shieldWall")
	check(game.learn("hero","bulwark")=="","满足条件可学习技能")
	game.state.materials={"ore":30,"shard":10,"herb":10}; game.state.gold=500
	check(game.craft("trailblade")=="制作完成。","可制作现有装备")
	var equipment=game.state.gear.keys()[-1]
	game.enhance(equipment); game.enhance(equipment); game.enhance(equipment)
	check(game.state.gear[equipment].rank==3 and game.enhance(equipment).contains("+3"),"强化遵守 +3 上限")
	var stored=game.state.duplicate(true)
	game.enter_training("assassin",["sylvi","ridge-scout","alchemist"],12)
	check(game.state.members.size()==4 and game.state.members.hero.job=="assassin","训练可试用任意职业和三同伴")
	game.state.gold=0; game.state.items.potion=0; game.exit_training()
	check(game.state==stored,"退出训练完整恢复剧情、物品与金币")
	var affinity=game.state.affinity.mira.value
	game.chat("mira"); game.chat("mira")
	check(game.state.affinity.mira.value==affinity+4,"日常对话不重复发好感")
	game.state.affinity.mira.value=30
	game.topic_choice("mira","past",0); game.topic_choice("mira","past",1)
	check(game.state.affinity.mira.value==32 and game.state.dialogue["mira:past"]==0,"关系选择只奖励一次并锁定")
	results.append("角色成长、招募、唯一装备、技能重配、制作强化、训练隔离")

func _test_personal_passives():
	var game=GameSession.new(db); game.new_game("ranger")
	var hero_stats=PartyMemberState.stats(game.state.members.hero,game.state,db)
	game.state.knowledge=1; game.recruit("mira")
	check(PartyMemberState.stats(game.state.members.hero,game.state,db)==hero_stats,"招募不再给主角叠加同伴属性")
	for id in db.raw.companions:
		var companion=PartyMemberState.create(id,db.raw.companions[id].job)
		var personal=PartyMemberState.stats(companion,game.state,db)
		companion.id="hero"
		var baseline=PartyMemberState.stats(companion,game.state,db)
		for key in db.raw.companions[id].bonus:
			var stat={"hp":"max_hp","mana":"max_mp"}.get(key,key)
			check(is_equal_approx(float(personal[stat]-baseline[stat]),float(db.raw.companions[id].bonus[key])),"同伴固有加成只属于本人："+id+":"+key)
	game.state.members.hero.learned=["fieldcraft","herbalLore"]
	game.state.members.hero.hp=1; game.state.members.hero.mp=0
	var stats=PartyMemberState.stats(game.state.members.hero,game.state,db)
	game.visit("room-inn"); game.inspect_prop("room-inn",prop("room-inn","workstation"))
	check(game.state.members.hero.hp==1+ceili(stats.max_hp*0.25*1.15),"荒野本能提高本角色营火恢复")
	var herbs=game.state.materials.herb
	game.inspect_prop("room-inn",prop("room-inn","supplies-cache"))
	check(game.state.materials.herb==herbs+3,"草木识途在实际采集中额外获得草药")
	game.inspect_prop("room-inn",prop("room-inn","supplies-cache"))
	check(game.state.materials.herb==herbs+3,"已采集容器不能重复领取被动材料")
	var engine=fixture("warden").engine
	for ally in engine.living("ally"): ally.support_bonus=0.0
	var actor=engine.unit("hero"); var target=engine.living("enemy")[0]
	actor.crit=0; target.hp=10000; target.weakness=[]; target.effects=[]; actor.atk=100
	engine.rng.seed=123; engine._strike(actor,target,0.65,"physical",true,"支援",0,false)
	var ordinary=10000-target.hp
	target.hp=10000; actor.support_bonus=0.15
	engine.rng.seed=123; engine._strike(actor,target,0.65,"physical",true,"支援",0,false)
	check(10000-target.hp>ordinary,"同袍誓言提高队伍反击与追击的实际支援伤害")
	results.append("六同伴原有加成归属、营火恢复、采集被动与同袍支援")

func _test_combat():
	var game=fixture("warden",["mira","sylvi","eira"]); var engine=game.engine
	check(engine.battle.units.size()==5,"四名独立友方与一名 Boss")
	check(engine.current().id=="sylvi","速度生成稳定行动顺序")
	var rear=engine.make_enemy({"name":"后排测试","hp":100,"atk":1,"slot":3},"rear")
	engine.battle.units.append(rear)
	check(rear not in engine.legal_targets(engine.unit("hero")),"近战受前排保护限制")
	check(rear in engine.legal_targets(engine.unit("mira")),"远程可选择后排")
	check(engine.legal_targets(engine.unit("hero"),"swap").has(engine.unit("mira")),"换位可选队友")
	hero_turn(engine)
	var hero=engine.unit("hero"); var target=engine.living("enemy")[0]
	hero.skills=["shieldWall"]; hero.mp=0
	var bad=BattleCommand.new("hero","ability",target.id,"shieldWall",engine.battle.token).to_dict()
	var before=engine.battle.duplicate(true)
	check(engine.submit(bad).error!="" and engine.battle==before,"非法指令不消耗资源、不推进回合")
	hero.mp=hero.max_mp
	var command=BattleCommand.new("hero","attack",target.id,"",engine.battle.token).to_dict()
	engine.submit(command)
	var after=engine.battle.duplicate(true)
	check(engine.submit(command).error!="" and engine.battle==after,"过期指令不能重复结算")
	game=fixture(); engine=game.engine; hero=engine.unit("hero")
	engine.apply_effect(hero,"shield",2,15,"测试盾")
	var hp=hero.hp
	engine._hurt(hero,20,"测试伤害")
	check(hero.hp==hp-5,"护盾正确吸收伤害且不增加生命")
	var boss=engine.living("enemy")[0]
	engine._control(boss); engine._control(boss)
	check(engine.battle.log.any(func(line): return "抵抗连续控制" in line),"Boss 抵抗连续控制")
	boss.effects=[]; boss.posture=2; boss.charging=true
	engine._posture(boss,2)
	check(engine.has_effect(boss,"broken") and boss.posture==0,"架势降至零进入破防")
	game=fixture("arcanist",["toren","eira"]); engine=game.engine
	var guardian=engine.unit("toren"); var protected=engine.unit("hero"); boss=engine.unit("enemy-0")
	engine.apply_effect(guardian,"guard",1,0,"保护",protected.id)
	var protected_hp=protected.hp; var guard_hp=guardian.hp; var boss_hp=boss.hp
	engine._strike(boss,protected,1.0,"physical",false,"承伤测试")
	check(protected.hp==protected_hp and guardian.hp<guard_hp,"护卫替指定队友承伤")
	check(boss.hp<boss_hp,"守誓者护卫后反击")
	game=fixture("ranger",["ridge-scout"]); engine=game.engine; hero=engine.unit("hero"); boss=engine.unit("enemy-0")
	engine.apply_effect(boss,"vulnerable",3,0,"标记")
	engine._strike(hero,boss,0.1,"physical",false,"触发追击")
	var follows=engine.battle.log.filter(func(line): return "协同追击" in line).size()
	engine._strike(hero,boss,0.1,"physical",false,"再次触发")
	check(follows==1 and engine.battle.log.filter(func(line): return "协同追击" in line).size()==1,"追击每角色每回合最多一次")
	game=fixture(); engine=game.engine; boss=engine.unit("enemy-0")
	boss.phase=2; boss.intent={"kind":"summon","target":"hero","label":"召唤","power":1.0}
	for i in 8: engine._enemy_action(boss)
	check(engine.battle.units.filter(func(actor): return actor.team=="enemy").size()==6,"召唤不超过六名敌人")
	game=fixture("warden",["mira","toren"]); engine=game.engine; hero_turn(engine)
	engine.battle.synergy=100
	var combo=BattleCommand.new("hero","pair","enemy-0","starshield",engine.battle.token).to_dict()
	var combo_result=engine.submit(combo)
	check(combo_result.error=="" and combo_result.events.any(func(event): return event.kind=="pair"),"双人协奏可真实发动并产生事件")
	check(engine.battle.synergy<100 and engine.has_effect(engine.unit("hero"),"shield"),"星盾协奏消耗协奏条并提供全队护盾")
	game=fixture("ranger",["mira"]); engine=game.engine; hero_turn(engine)
	var mp_before=engine.unit("hero").mp
	var bond_result=engine.submit(BattleCommand.new("hero","bond","enemy-0","mira",engine.battle.token).to_dict())
	check(bond_result.error=="" and engine.unit("hero").mp==mp_before-10,"个人羁绊技正确使用好感、法力与冷却条件")
	game=fixture("priest",[]); engine=game.engine; hero=engine.unit("hero"); hero_turn(engine)
	hero.skills=["priest_redemption_2"]; hero.hp=20; hero.tactic="protect"
	var healing=engine.ai_command()
	check(healing.action=="ability" and healing.target=="hero","保护 AI 优先治疗低血量队员")
	hero.tactic="reserve"; hero.mp=1; hero.hp=hero.max_hp
	check(engine.ai_command().action=="attack","资源不足的 AI 回退普攻")
	game=fixture(); engine=game.engine
	engine.start(game.state,"town-wall-1",45,true); engine.battle.round=2
	var healer=engine.unit("enemy-1"); healer.hp=10; healer.intent=engine._choose_intent(healer)
	check(healer.intent.kind=="heal" and engine.unit(healer.intent.target).team=="enemy","敌方治疗意图正确显示其同伴目标")
	engine._update_phases(); engine._enemy_action(healer)
	check(healer.hp>10,"敌方按展示的目标执行治疗")
	engine.apply_effect(healer,"silence",2,0,"禁言")
	healer.intent={"kind":"heal","target":healer.id,"label":"治疗","power":1.0}; engine._update_phases()
	check(healer.intent.kind=="attack","沉默立即取消敌方已经展示的施法意图")
	# Persist the exact random stream as decimal strings, including across JSON's float parsing.
	game=fixture(); engine=game.engine
	for i in 3: engine.submit(engine.ai_command())
	var restored=BattleEngine.new(db); restored.restore(JSON.parse_string(JSON.stringify(engine.battle)))
	check(JSON.parse_string(JSON.stringify(restored.battle.units))==JSON.parse_string(JSON.stringify(engine.battle.units)),"恢复不修改已扣除的生命")
	for i in 12:
		if engine.battle.result!="": break
		engine.submit(engine.ai_command()); restored.submit(restored.ai_command())
	check(JSON.parse_string(JSON.stringify(engine.battle))==JSON.parse_string(JSON.stringify(restored.battle)),"相同种子、指令与存读档产生完全一致结果")
	results.append("行动顺序、目标限制、护卫反击、护盾、破防、控制免疫、追击、召唤、AI 与确定性读档")

func _test_all_skills():
	var tested=0
	for id in db.skills:
		var skill=db.skills[id]
		if skill.data.kind!="active": continue
		var game=fixture(skill.job,[],12); var engine=game.engine
		hero_turn(engine)
		var hero=engine.unit("hero"); hero.skills=[id]; hero.max_mp=300; hero.mp=300; hero.hp=maxi(1,int(hero.max_hp/2))
		var targets=engine.legal_targets(hero,"ability",id)
		var command=BattleCommand.new("hero","ability",targets[0].id,id,engine.battle.token).to_dict()
		var mp=hero.mp; var result=engine.submit(command)
		check(result.error=="" and hero.mp==mp-skill.mp,"主动技能可结算并正确扣蓝："+id)
		var casts=result.events.filter(func(event): return event.kind=="cast" and event.get("skill_id","")==id)
		check(casts.size()==1 and casts[0].element==skill.element and casts[0].actor=="hero" and casts[0].target==targets[0].id,"主动技能提供准确施法与目标事件："+id)
		check(result.events.any(func(event): return event.kind in ["damage","heal","status","revive","mana"]),"主动技能具有命中、治疗或状态表现："+id)
		var ids={}
		for event in result.events: ids[event.event_id]=true
		check(ids.size()==result.events.size(),"技能事件编号唯一："+id)
		tested+=1
	for job in GameContent.JOB_ORDER:
		var game=fixture(job,["mira","toren","eira"],6)
		check(fight(game)=="win","六职业训练可完成战斗："+job)
	results.append("%d 项主动技能逐项执行、施法与命中事件、六职业完整战斗" % tested)

func _test_status_and_resume():
	var game=fixture("ranger",[]); var engine=game.engine; var hero=engine.unit("hero"); var boss=engine.unit("enemy-0")
	check(engine.current().id=="hero","状态时序测试起始为主角")
	engine.apply_effect(hero,"poison",2,5,"测试毒")
	engine.submit(BattleCommand.new("hero","guard","hero","",engine.battle.token).to_dict())
	check(engine.effect(hero,"poison").turns==2,"本次行动新施加状态不提前扣持续时间")
	var hp=hero.hp
	engine.submit(engine.ai_command()) # Boss spends its first action charging.
	check(hero.hp==hp-5 and engine.effect(hero,"poison").turns==2,"持续伤害在目标下次行动开始结算")
	engine.submit(BattleCommand.new("hero","guard","hero","",engine.battle.token).to_dict())
	check(engine.effect(hero,"poison").turns==1,"持续时间在目标行动结束递减")
	game=fixture("ranger",["mira"]); engine=game.engine; hero=engine.unit("hero")
	var ally=engine.unit("mira"); ally.hp=0; hero_turn(engine)
	var supplies=engine.battle.items.revive
	var result=engine.submit(BattleCommand.new("hero","revive","mira","",engine.battle.token).to_dict())
	check(result.error=="" and ally.hp==ceili(ally.max_hp*0.3) and engine.battle.items.revive==supplies-1,"苏生消耗一次行动和一瓶道具，恢复 30% 生命")
	game=GameSession.new(db); game.new_game("arcanist"); game.state.knowledge=1; game.recruit("mira"); game.tasks.discover("entrance-town-wall"); game.visit("town-wall"); game.state.encounters["town-wall-0"]=true; game.start_battle("town-wall-1",856)
	game.combat(game.engine.ai_command())
	var saved=JSON.parse_string(JSON.stringify(game.state))
	var validation=game.validate_save(saved)
	check(validation=="","真实剧情中的战斗快照可验证："+validation)
	var other=GameSession.new(db)
	var loading=other.load_state(saved)
	check(loading=="","原生存档恢复进行中的战斗："+loading)
	if loading!="": return
	var before=game.state.members.hero.hp
	check(other.state.members.hero.hp==before and other.engine.unit("hero").hp==game.engine.unit("hero").hp,"读档不会恢复已损失生命")
	if game.state.battle!=null and other.state.battle!=null:
		var first=game.combat(game.engine.ai_command()); var second=other.combat(other.engine.ai_command())
		check(first.error==second.error and JSON.parse_string(JSON.stringify(game.state))==JSON.parse_string(JSON.stringify(other.state)),"进行中战斗读档后，下一次实际指令结果一致")
	var malformed=saved.duplicate(true)
	malformed.affinity={}
	check(other.load_state(malformed)!="","缺失关系数据的存档被安全拒绝")
	results.append("状态按目标行动计时、倒地苏生、剧情战斗中存读档与损坏快照校验")

func _test_saves():
	var game=GameSession.new(db); game.new_game("ranger")
	var directory="user://tests/"+str(Time.get_ticks_usec())
	var saves=SaveStore.new(game,directory)
	check(saves.save(0)=="" and saves.save(1)=="","自动存档与手动档可分别保存")
	game.state.gold=123; saves.save(0)
	check(saves.load_slot(1)=="" and game.state.gold==95,"手动档不受自动档覆盖")
	check(saves.load_slot(0)=="" and game.state.gold==123,"自动档恢复最新状态")
	var exported=directory.path_join("export.json")
	check(saves.export_to(exported)=="","原生 JSON 可导出")
	game.state.gold=2
	check(saves.import_from(exported)=="" and game.state.gold==123,"原生 JSON 可导入")
	var before=game.state.duplicate(true)
	var old=directory.path_join("old.json"); var file=FileAccess.open(old,FileAccess.WRITE); file.store_string('{"schema":6,"player":{}}'); file.close()
	check(saves.import_from(old)!="" and game.state==before,"拒绝网页旧档并保留当前进度")
	var invalid=game.state.duplicate(true); invalid.members.hero.hp=-50
	check(game.load_state(invalid)!="" and game.state==before,"拒绝损坏角色状态")
	game.enter_training("ranger",["mira"],6)
	check(saves.save(0)!="","训练期间禁止覆盖剧情档")
	game.exit_training()
	file=FileAccess.open(saves.path_for(0),FileAccess.WRITE); file.store_string("broken-json"); file.close()
	check(saves.load_slot(0)=="","主存档损坏时可读取备份")
	results.append("独立原生格式、三档位、备份恢复、JSON 导入导出、训练隔离")

func _test_chapter():
	var game=GameSession.new(db); game.new_game("warden")
	game.visit("room-clocktower"); game.inspect_prop("room-clocktower",prop("room-clocktower","star-chart"))
	game.visit("room-royal-hall"); game.service("world:royal-record","royal-heir")
	game.visit("room-inn"); game.inspect_prop("room-inn",prop("room-inn","supplies-cache"))
	game.recruit("mira")
	game.visit("room-chapel"); game.visit("room-chapel"); game.accept_personal("eira")
	game.inspect_prop("room-chapel",prop("room-chapel","prayer-book")); game.inspect_prop("room-chapel",prop("room-chapel","altar"))
	game.tasks.turn_in("personal:eira","eira"); game.recruit("eira")
	check(game.state.active.size()==3,"首章可按原条件组成主角、米拉、艾拉队伍")
	game.visit("room-guildhall"); game.tasks.accept("first","board")
	for route in GameContent.ROUTES:
		game.tasks.discover("entrance-"+route)
		check(game.visit(route)=="","路线按调查次序开放："+route)
		game.inspect_prop(route,prop(route,"supplies-cache"))
		game.inspect_prop(route,prop(route,"survey"))
		game.choose_event(route,0)
		if game.tasks.status("first")=="ready": game.visit("room-guildhall"); game.tasks.turn_in("first","board"); game.visit(route)
		for index in 3:
			# Rest using actual chapter resources between encounters, not a test-only heal.
			if game.state.supplies<1: check(game.buy("supply")=="购买完成。","通过实际商店补充消耗的补给")
			game.visit("town"); check(game.rest().contains("恢复"),"首章补给支持旅店休息"); game.visit(route)
			check(game.start_battle(route+"-"+str(index),700+GameContent.ROUTES.find(route)*10+index)=="","可发起首章遭遇")
			check(fight(game)=="win","按正常成长与资源完成遭遇："+route+"-"+str(index))
	check(game.state.chapter_complete and game.state.flags.drain_clue and game.state.encounters.get("town-trial-2",false),"完整探索、招募、成长、九场遭遇后完成首章")
	check(game.validate_save(JSON.parse_string(JSON.stringify(game.state)))=="","通关存档可验证与恢复")
	results.append("新游戏 → 原剧情招募 → 九场正常战斗 → 首章结束 → 存档")

func _test_ui():
	var scene=load("res://scenes/main.tscn").instantiate(); root.add_child(scene)
	await process_frame
	scene.capture_mode=true
	check(scene.mode=="title" and scene.main_view.get_child_count()>0,"原生标题页初始化")
	scene.new_game("ranger")
	await process_frame
	for kind in ["party","skills","inventory","craft","journal","map","actions","settings","saves","training"]:
		scene.open_menu(kind)
		await process_frame
		check(scene.overlay_root.get_child_count()>0,"原生功能面板可打开："+kind)
	scene.close_menu(); await process_frame
	var world=scene.world
	var previous=world.player
	Input.action_press("move_down"); world._process(0.1); Input.action_release("move_down")
	check(world.player.distance_to(previous)>0,"键盘输入可移动角色")
	Input.action_press("move_down"); world._process(0.1); world._process(0.1); Input.action_release("move_down")
	check(world.move_clock>0.2,"连续移动时行走动画不会每帧重置")
	Input.action_press("run"); scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not Input.is_action_pressed("run") and world.walking_path.is_empty(),"失焦清除跑步与路径输入")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	for building in db.raw.buildings: check(world._can_walk(world.entry(building)),"建筑入口可通行："+building.id)
	for scene_id in db.raw.scenes:
		scene.session.state.location={"scene":scene_id,"x":8.5,"y":8.5}; world.scene_id=""; world.show_location()
		for target in world.targets: check(world._can_walk(world._safe_point(target.point)),"室内/路线互动点可到达："+scene_id+":"+target.id)
		for target in world.targets:
			var projected=world.uniso(world.iso(target.point))
			check(projected.distance_to(target.point)<0.001,"场景命中坐标可往返转换："+scene_id+":"+target.id)
			world.navigate(target.point,target)
			check(not world.walking_path.is_empty() or world.player.distance_to(target.point)<2.6,"互动点可通过实际寻路接近："+scene_id+":"+target.id)
	scene.session.state.location={"scene":"town","x":30.0,"y":27.0}; world.scene_id=""; world.show_location(); world.stop()
	await process_frame
	await process_frame
	var baseline=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for iteration in 30:
		for destination in ["room-chapel","town"]:
			scene.session.state.location={"scene":destination,"x":30.0 if destination=="town" else 8.5,"y":27.0 if destination=="town" else 8.5}
			world.show_location(); world.stop(); await process_frame
	await process_frame
	check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))<=baseline+5,"连续 30 次进出场景后节点数量不持续增长")
	scene.session.enter_training("warden",["mira","eira","ridge-scout"],6); scene.session.start_battle("town-trial-2",417); scene.mode="battle"; scene.paused=true; scene.refresh()
	await process_frame
	check(scene.main_view.get_child_count()>0,"四人队伍战斗界面可渲染")
	scene.paused=false; scene.focused=false; scene.choose_action("attack"); scene.perform()
	var token=scene.session.engine.battle.token
	scene.perform()
	check(scene.session.engine.battle.token==token,"动画结算期间重复确认不会替下一位队员行动")
	scene._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(scene.paused,"战斗失焦暂停自动行动")
	scene.session.exit_training(); scene.queue_free(); await process_frame
	results.append("原生标题、十类功能页、城镇移动、全部互动点、战斗界面与输入清理")
