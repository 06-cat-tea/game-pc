extends RefCounted

var verify: Callable
var db: GameContent

func fixture() -> GameSession:
	var game=GameSession.new(db); game.new_game("ranger"); game.enter_training("ranger",["mira","toren","eira"],6); game.start_battle("town-trial-2",9301)
	game.engine.battle.cursor=game.engine.battle.queue.find("hero")
	for ally in game.engine.living("ally"): ally.tp=0
	return game

func run(tree: SceneTree, check: Callable):
	verify=check; db=tree.db
	var game=fixture(); var engine=game.engine; var hero=engine.unit("hero"); var foe=engine.unit("enemy-0")
	engine.grant_shield(hero,30,2,"第一层",false,"a"); engine.grant_shield(hero,20,3,"第二层",false,"b")
	var hp=int(hero.hp); engine._hurt(hero,25,"测试")
	check.call(hero.hp==hp and BattleRules.shield_value(hero)==5 and hero.shields.size()==1,"多盾同时受损，取最高保护值而非相加")
	engine._hurt(hero,12,"持续伤害",false); check.call(hero.hp==hp-7,"护盾吸收持续伤害并只让溢出扣血")
	engine.grant_shield(hero,30,2,"第一层",false,"a"); engine.grant_shield(hero,20,3,"第二层",false,"b")
	engine.battle.token+=1; engine._finish_actor(hero)
	engine.grant_shield(hero,10,4,"第一层",false,"a")
	check.call(hero.shields[0].potency==30 and hero.shields[0].turns==4 and hero.shields[1].turns==2,"同来源取高刷新，其他来源持续时间独立")
	engine.battle.token+=1; engine._finish_actor(hero); engine.battle.token+=1; engine._finish_actor(hero)
	check.call(hero.shields.size()==1 and hero.shields[0].key=="a","不同来源护盾独立到期")
	hero.shields=[]
	for i in 6: engine.grant_shield(hero,50,2,"同袍壁垒",true,"toren:bond")
	check.call(BattleRules.shield_value(hero)==ceili(hero.max_hp*.6),"专属叠盾遵守目标最大生命60%上限")
	hero.shields=[]; engine.battle.formation="watch"; engine.grant_shield(hero,100,2,"守望测试")
	check.call(BattleRules.shield_value(hero)==115,"守望阵实际增加15%护盾")
	engine.battle.formation="balanced"; hero.shields=[]; hero.tp=0
	engine.grant_shield(hero,100,2,"受击测试"); engine._strike(foe,hero,.1,"physical",false,"攻击")
	check.call(hero.tp==0,"完全由护盾吸收的敌方攻击不获得受伤TP")
	for element in BattleRules.config().counter:
		foe.affinity=BattleRules.config().counter[element]
		check.call(is_equal_approx(BattleRules.multiplier(element,foe),1.25),"五属性克制："+element)
		check.call(is_equal_approx(BattleRules.multiplier(foe.affinity,{"team":"enemy","affinity":element}),.8),"五属性被克制："+element)
	check.call(BattleRules.multiplier("fire",hero)==1.0,"我方没有防守主属性，不改变转职承伤")
	game=fixture(); engine=game.engine; hero=engine.unit("hero"); foe=engine.unit("enemy-0")
	foe.hp=10000; foe.max_hp=10000; foe.weakness=["fire"]; foe.posture=30; foe.max_posture=30; hero.crit=0
	engine.action_context={"action":"attack","caster":"hero","skill_id":"","break_granted":false,"synergy_gain":0}
	engine._strike(hero,foe,.1,"physical",false,"非弱点")
	check.call(foe.posture==30 and foe.hp<10000,"非弱点仍造成伤害但不削韧")
	engine.action_context={"action":"ability","caster":"hero","skill_id":"starfall","break_granted":false,"synergy_gain":0}
	var estimate=engine.preview(hero,foe,"ability","starfall")
	engine._strike(hero,foe,.1,"fire",false,"弱点攻击")
	check.call(30-foe.posture==estimate.reduction,"技能预览与真实削韧一致")
	foe.posture=10; foe.charging=true; engine._strike(hero,foe,.1,"fire",false,"击破")
	check.call(engine.has_effect(foe,"broken") and engine.has_effect(foe,"burn") and not foe.charging and foe.break_skip,"击破打断蓄力、添加对应属性附效并标记跳过行动")
	check.call(int(engine.action_context.synergy_gain)<=30,"单条指令协奏收益有上限")
	engine.action_context={}; engine.battle.cursor=engine.battle.queue.find(foe.id)
	engine._prepare_turn()
	check.call(foe.break_recover and not foe.break_skip and engine.has_effect(foe,"broken"),"击破跳过下一次行动且保留输出窗口")
	engine.battle.cursor=engine.battle.queue.find(foe.id); engine._prepare_turn()
	check.call(foe.posture==foe.max_posture and not engine.has_effect(foe,"broken") and foe.control_protected,"再下一次行动恢复韧性，首领保留抗连续控制")
	foe.posture=10; engine.strike_context={"actor":"hero","element":"fire","primary":true}; engine._posture(foe,10)
	check.call(not foe.break_skip and engine.has_effect(foe,"broken"),"首领保护期仍能击破，但不能连续跳过行动")
	for element in BattleRules.config().counter:
		game=fixture(); engine=game.engine; foe=engine.unit("enemy-0"); foe.hp=10000; foe.posture=10
		engine.strike_context={"actor":"hero","element":element,"primary":true}; engine._posture(foe,10)
		var fx={"physical":"bleed","fire":"burn","astral":"vulnerable","holy":"weaken","poison":"poison"}[element]
		check.call(engine.has_effect(foe,fx),"属性击破附效："+element)
	game=fixture(); engine=game.engine; hero=engine.unit("hero"); var turn=engine.battle.token; var mp=hero.mp
	var command=BattleCommand.new("hero","formation","hero","watch",turn).to_dict()
	check.call(engine.validate(command)=="","战中变阵指令可用")
	game.combat(command)
	check.call(engine.battle.formation=="watch" and game.state.formation=="watch" and hero.mp==mp and hero.tp==0 and engine.battle.synergy==0,"变阵消耗行动、保留配置且不产生资源")
	engine.battle.cursor=engine.battle.queue.find("hero"); engine.battle.formation_round=engine.battle.round
	check.call(engine.validate(BattleCommand.new("hero","formation","hero","assault",engine.battle.token).to_dict())!="","同轮不可再次变阵")
	for id in BattleRules.config().bonds:
		game=fixture(); engine=game.engine
		if not game.state.members.has(id):
			game.exit_training(); game.enter_training("ranger",[id,"mira" if id!="mira" else "sylvi","toren" if id!="toren" else "eira"],6); game.start_battle("town-trial-2",9302); engine=game.engine
		engine.battle.cursor=engine.battle.queue.find("hero"); hero=engine.unit("hero"); var targets=engine.legal_targets(hero,"bond",id)
		var target=targets[0]; var before=hero.mp
		var result=engine.submit(BattleCommand.new("hero","bond",target.id,id,engine.battle.token).to_dict())
		var expected=mini(hero.max_mp,before-10+ceili(hero.max_mp*.1)) if id=="alchemist" else before-10
		check.call(result.error=="" and hero.mp==expected,"六种羁绊目标与消耗有效："+id)
	game=fixture(); engine=game.engine; engine.battle.synergy=100
	engine.submit(BattleCommand.new("hero","pair","enemy-0","starshield",engine.battle.token).to_dict())
	check.call(engine.battle.pair_cooldowns.starshield>0 and engine.has_effect(engine.unit("hero"),"riposte"),"星盾协奏提供护盾反击并共享冷却")
	engine.battle.synergy=100; var mira=engine.unit("mira"); engine.battle.cursor=engine.battle.queue.find("mira")
	check.call(engine.validate(BattleCommand.new("mira","pair","enemy-0","starshield",engine.battle.token).to_dict())!="","其他角色不能绕过组合冷却")
	for pair_id in ["springlight","venomshadow"]:
		var pair_game=GameSession.new(db); pair_game.new_game("ranger")
		var team=["sylvi","eira"] if pair_id=="springlight" else ["ridge-scout","alchemist"]
		pair_game.enter_training("ranger",team,6); pair_game.start_battle("town-trial-2",9303)
		var pair_engine=pair_game.engine; pair_engine.battle.cursor=pair_engine.battle.queue.find("hero"); pair_engine.battle.synergy=100
		for ally in pair_engine.living("ally"): ally.hp=ceili(ally.max_hp*.5); pair_engine.apply_effect(ally,"poison",3,5,"测试毒")
		var enemy=pair_engine.unit("enemy-0"); enemy.hp=5000; enemy.max_hp=5000; pair_engine.apply_effect(enemy,"poison",3,10,"预施毒")
		var target=pair_engine.legal_targets(pair_engine.unit("hero"),"pair",pair_id)[0]
		var pair_result=pair_engine.submit(BattleCommand.new("hero","pair",target.id,pair_id,pair_engine.battle.token).to_dict())
		check.call(pair_result.error=="" and pair_engine.battle.pair_cooldowns[pair_id]>0,"协奏发动并共享冷却："+pair_id)
		if pair_id=="springlight": check.call(not pair_engine.has_effect(pair_engine.unit("hero"),"poison") and pair_engine.has_effect(pair_engine.unit("hero"),"regen"),"回春圣歌净化并附加再生")
		else: check.call(pair_result.events.any(func(event): return event.kind=="dot" and event.text.contains("蚀毒引爆")),"蚀毒突袭引爆既有毒伤")
	var snapshot=JSON.parse_string(JSON.stringify(engine.battle)); var resumed=BattleEngine.new(db); resumed.restore(snapshot)
	check.call(JSON.parse_string(JSON.stringify(resumed.battle))==snapshot,"新护盾、韧性、组合冷却与变阵状态精确读档")
	var legacy=snapshot.duplicate(true); legacy.erase("rules_version"); legacy.erase("pair_cooldowns"); legacy.erase("formation_round")
	for actor in legacy.units:
		actor.erase("shields"); actor.posture=3; actor.max_posture=6
		if actor.team=="ally": actor.effects.append({"type":"shield","potency":12,"turns":2,"source":"旧护盾","created":legacy.token,"cover":""})
	resumed.restore(legacy)
	check.call(resumed.unit("hero").hp==engine.unit("hero").hp and BattleRules.shield_value(resumed.unit("hero"))==12 and resumed.unit("enemy-0").max_posture==60,"旧战斗迁移保留生命并转换护盾与韧性单位")
	var malformed=snapshot.duplicate(true); malformed.units[0].shields=[{"key":"bad","source":"bad","turns":2,"potency":-1,"created":1}]
	check.call(BattleRules.validate(malformed)!="","非法护盾记录被拒绝")
	var legacy_game=GameSession.new(db); legacy_game.new_game(); var old_state=legacy_game.state.duplicate(true); old_state.erase("combat_rules_version")
	var store=SaveStore.new(legacy_game,"user://tests/combat-v2-"+str(Time.get_ticks_usec()))
	store.write_json(store.path_for(1),old_state)
	check.call(store.load_slot(1)=="" and FileAccess.file_exists(store.path_for(1)+".before-combat-v2.json"),"旧档在实际升级前保存战斗v2原始备份")
	await _loading(tree,check)
	tree.results.append("战术升级：独立多源护盾、五属性克制、弱点削韧、击破窗口、首领保护、战中变阵、六羁绊、共享协奏冷却与旧档迁移")

func _loading(tree: SceneTree, check: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true; game.capture_args={}; game.new_game("warden"); game.session.state.settings.reduce_motion=true
	var config=game.loading.config
	check.call(config.images.size()==10,"加载配置恰好十张插画")
	for key in config.images: check.call(ResourceLoader.exists(config.images[key].path),"加载插画可用："+key)
	for id in ["potion","tonic","revive","herb","ore","shard","gold"]: check.call(ResourceLoader.exists(ItemIcons.path(db,id)),"物品图标可用："+id)
	game.travel_to("wood"); check.call(game.loading.busy and game.world.blocked,"区域加载期间阻止输入与移动")
	var repeated=await game.travel_to("pass"); check.call(repeated!="","加载时拒绝重复旅行")
	while game.loading.busy: await tree.process_frame
	check.call(game.world.scene_id=="wood" and game.loading.history[-1]=="wood","区域加载使用目的地图并完成场景准备")
	game.loading.run("ruins",func(): return "测试失败")
	await tree.process_frame; await tree.process_frame; await tree.process_frame
	check.call(game.loading.busy and game.loading.stage_label.text.contains("测试失败"),"加载失败保留返回与重试界面")
	var escape=InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; game._input(escape)
	check.call(not game.loading.busy,"加载失败可用Esc返回，恢复输入")
	game.queue_free(); await tree.process_frame
