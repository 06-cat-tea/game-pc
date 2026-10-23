class_name BattleRules
extends RefCounted

static var cached: Dictionary = {}

static func config() -> Dictionary:
	if cached.is_empty(): cached=JSON.parse_string(FileAccess.get_file_as_string("res://data/battle-rules.json"))
	return cached

static func multiplier(element: String, target: Dictionary) -> float:
	if target.get("team","")!="enemy": return 1.0
	var affinity=str(target.get("affinity","physical")); var c=config()
	if c.counter.get(element,"")==affinity: return float(c.counter_multiplier)
	if c.counter.get(affinity,"")==element: return float(c.resisted_multiplier)
	return 1.0

static func enemy_profile(actor: Dictionary):
	var affinity={"wolf":"physical","treant":"poison","deer":"holy","raider":"physical","lava-beast":"fire","knight":"physical","eclipse-priest":"astral","golem":"physical","prince":"holy","smuggler":"poison","crab":"physical","pirate":"fire","sentinel":"holy","commander":"physical","sorceress":"astral","serpent":"poison"}.get(actor.get("art",""),"physical")
	actor.affinity=actor.get("affinity",affinity)
	actor.attack_element=actor.get("attack_element","poison" if actor.get("role","")=="caster" else "physical")
	actor.shields=actor.get("shields",[])
	actor.break_skip=actor.get("break_skip",false); actor.break_recover=actor.get("break_recover",false)
	actor.control_protected=actor.get("control_protected",false)
	actor.assault_round=int(actor.get("assault_round",0))

static func shield_value(actor: Dictionary) -> int:
	var value=0
	for shield in actor.get("shields",[]): value=maxi(value,int(shield.potency))
	return value

static func migrate(battle: Dictionary):
	var legacy=int(battle.get("rules_version",1))<2
	battle.rules_version=2; battle.formation_round=int(battle.get("formation_round",0)); battle.pair_cooldowns=battle.get("pair_cooldowns",{})
	for actor in battle.units:
		enemy_profile(actor)
		var kept=[]
		for fx in actor.effects:
			if fx.type=="shield":
				actor.shields.append({"key":"legacy:"+str(fx.source),"source":fx.source,"potency":int(fx.potency),"turns":int(fx.turns),"created":int(fx.created)})
			else: kept.append(fx)
		actor.effects=kept
		if legacy and actor.team=="enemy":
			actor.posture=int(actor.posture)*10; actor.max_posture=int(actor.max_posture)*10
			if actor.effects.any(func(fx): return fx.type=="broken"):
				actor.break_skip=true; actor.break_recover=false
		for key in actor.cooldowns:
			if str(key).begins_with("pair:"):
				var id=str(key).trim_prefix("pair:"); battle.pair_cooldowns[id]=maxi(int(battle.pair_cooldowns.get(id,0)),int(actor.cooldowns[key]))

static func validate(battle: Dictionary) -> String:
	if not battle.get("pair_cooldowns",{}) is Dictionary: return "协奏冷却记录无效。"
	if not _integer(battle.get("rules_version",1),1,2) or not _integer(battle.get("formation_round",0),0,int(battle.get("round",0))): return "战斗规则版本或变阵记录无效。"
	for key in battle.get("pair_cooldowns",{}):
		if key not in ["starshield","springlight","venomshadow"] or not _integer(battle.pair_cooldowns[key],0,20): return "协奏冷却记录无效。"
	for actor in battle.units:
		if not actor.get("pressure",false) is bool: return "敌方狂热配置无效。"
		if actor.get("affinity","physical") not in config().counter or actor.get("attack_element","physical") not in config().counter: return "战斗属性无效。"
		for key in ["break_skip","break_recover","control_protected"]:
			if not actor.get(key,false) is bool: return "击破恢复记录无效。"
		if not _integer(actor.get("assault_round",0),0,1000000) or not actor.get("shields",[]) is Array or actor.get("shields",[]).size()>32: return "护盾记录无效。"
		var keys=[]
		for shield in actor.get("shields",[]):
			if not shield is Dictionary or not shield.get("key") is String or shield.key in keys or not shield.get("source") is String: return "护盾来源无效。"
			keys.append(shield.key)
			if not _integer(shield.get("potency"),0,1000000) or not _integer(shield.get("turns"),1,20) or not _integer(shield.get("created"),0,1000000): return "护盾数值无效。"
	return ""

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum
