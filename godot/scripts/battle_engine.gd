class_name BattleEngine
extends RefCounted

signal changed(events: Array)
var db: GameContent
var battle = {}
var rng = RandomNumberGenerator.new()
var events = []
var action_context={}
var strike_context={}
const EFFECT_NAMES = {"burn":"灼烧", "poison":"中毒", "bleed":"流血", "regen":"再生", "shield":"护盾", "vulnerable":"易伤", "armorBreak":"破甲", "silence":"沉默", "blind":"烟幕", "guard":"护卫", "taunt":"嘲讽", "broken":"弱点击破", "stun":"压制", "weaken":"虚弱", "riposte":"星盾反击"}

func _init(content: GameContent): db = content

func start(state: Dictionary, encounter: String, seed_value: int, training: bool = false):
	var definition = db.encounters[encounter]
	rng.seed = seed_value
	battle = {"encounter":encounter, "title":definition.title, "training":training, "round":0, "token":0, "cursor":0, "queue":[], "units":[], "synergy":0, "result":"", "log":[], "participants":state.active.duplicate(), "items":state.items.duplicate(true), "formation":state.formation, "seed":str(seed_value), "rng_state":str(rng.state)}
	battle.instance_id=encounter+":"+str(state.seed_counter)+":"+str(seed_value); battle.event_seq=0; battle.rules_version=2; battle.formation_round=0; battle.pair_cooldowns={}
	for id in state.active:
		var member = state.members[id]
		var stats = PartyMemberState.stats(member, state, db)
		var unit = stats.duplicate(true)
		unit.merge({"id":id, "name":db.actors[id].display_name, "job":member.job, "team":"ally", "slot":member.slot, "hp":member.hp, "mp":member.mp, "effects":[], "cooldowns":{}, "skills":member.loadouts.get(member.job, []).duplicate(), "auto":member.auto, "tactic":member.tactic, "heal_threshold":member.heal_threshold, "mana_reserve":member.mana_reserve, "focus":member.focus, "bond":state.affinity.get(id, {}).get("value", 0), "art":id, "follow_round":0, "immune_until":0, "posture":3, "max_posture":3, "weakness":[], "phase":1})
		unit.shields=[]; unit.assault_round=0; BattleRules.enemy_profile(unit)
		battle.units.append(unit)
		unit.awakened=training or int(state.get("story",{}).get("awakenings",{}).get(id,{}).get("stage",0))==4
		unit.tp=int(member.get("tp",0)) if unit.awakened else 0
		unit.ultimate_auto=member.get("ultimate_auto",false); unit.tp_hit_round=0; unit.tp_hit_gain=0
	for index in definition.enemies.size(): battle.units.append(make_enemy(definition.enemies[index], "enemy-" + str(index)))
	events = []
	_begin_round()
	_prepare_turn()
	_store_rng()

func make_enemy(source: Dictionary, id: String) -> Dictionary:
	var unit = source.duplicate(true)
	unit.merge({"id":id, "team":"enemy", "max_hp":int(source.hp), "hp":int(source.hp), "max_mp":999, "mp":999, "job":"enemy", "crit":0.03, "drain":0.0, "effects":[], "cooldowns":{}, "skills":[], "phase":1, "immune_until":0, "charging":false, "summoned":false, "follow_round":0}, true)
	unit.def = int(source.get("def", 1))
	unit.speed = int(source.get("speed", 10))
	unit.slot = int(source.get("slot", 0))
	unit.max_posture = int(source.get("toughness",BattleRules.config().toughness["boss" if unit.get("boss",false) else "elite" if unit.get("elite",false) else "normal"]))
	unit.posture = unit.max_posture
	unit.weakness = source.get("weakness", ["physical"]).duplicate()
	BattleRules.enemy_profile(unit)
	unit.ranged = source.get("ranged", false) or source.get("role", "") == "caster"
	unit.intent = {"kind":"attack", "target":"hero", "label":"下回合加入行动", "power":1.0}
	return unit

func restore(saved: Dictionary):
	battle = saved.duplicate(true)
	BattleRules.migrate(battle)
	battle.instance_id=battle.get("instance_id","legacy:"+str(battle.encounter)+":"+str(battle.seed)); battle.event_seq=int(battle.get("event_seq",0))
	for key in ["round","token","cursor","synergy"]: battle[key] = int(battle[key])
	for actor in battle.units:
		if actor.team=="ally":
			actor.tp=int(actor.get("tp",0)); actor.awakened=actor.get("awakened",false); actor.ultimate_auto=actor.get("ultimate_auto",false)
			actor.tp_hit_round=int(actor.get("tp_hit_round",0)); actor.tp_hit_gain=int(actor.get("tp_hit_gain",0))
		for key in ["slot","hp","max_hp","mp","max_mp","atk","def","speed","posture","max_posture","phase","immune_until","follow_round"]: actor[key]=int(actor[key])
	rng.seed = int(battle.seed)
	rng.state = int(battle.rng_state)
	events = []

func _store_rng(): battle.rng_state = str(rng.state)

func living(team: String) -> Array:
	return battle.units.filter(func(unit): return unit.team == team and unit.hp > 0)

func unit(id: String) -> Dictionary:
	for candidate in battle.get("units", []):
		if candidate.id == id: return candidate
	return {}

func current() -> Dictionary:
	if battle.is_empty() or battle.result != "" or battle.cursor >= battle.queue.size(): return {}
	return unit(battle.queue[battle.cursor])

func has_effect(actor: Dictionary, type: String) -> bool:
	if type=="shield": return BattleRules.shield_value(actor)>0
	return actor.get("effects", []).any(func(effect): return effect.type == type)

func effect(actor: Dictionary, type: String) -> Dictionary:
	if type=="shield":
		var shields=actor.get("shields",[]).duplicate(); shields.sort_custom(func(a,b): return a.potency>b.potency)
		return shields[0] if not shields.is_empty() else {}
	for fx in actor.effects:
		if fx.type == type: return fx
	return {}

func apply_effect(actor: Dictionary, type: String, turns: int, potency: int = 0, source: String = "", cover: String = ""):
	if actor.is_empty() or actor.hp <= 0: return
	if type=="shield":
		grant_shield(actor,potency,turns,source); return
	var old = effect(actor, type)
	if old.is_empty(): actor.effects.append({"type":type, "turns":turns, "potency":potency, "source":source, "created":battle.token, "cover":cover})
	else:
		old.turns = maxi(int(old.turns), turns)
		old.potency = maxi(int(old.potency), potency)
		old.created = battle.token
		old.source = source
		old.cover = cover
	_emit("status",source+" · "+EFFECT_NAMES.get(type,type),"",actor.id,potency)
	events[-1].effect=type

func _emit(kind: String, text: String, actor: String = "", target: String = "", value: int = 0):
	battle.event_seq=int(battle.get("event_seq",0))+1
	var metadata=action_context.duplicate(true); metadata.erase("break_granted")
	metadata.merge({"event_id":str(battle.get("instance_id","legacy"))+":"+str(battle.event_seq),"turn_token":battle.token},true)
	if actor=="": actor=str(strike_context.get("actor",action_context.get("caster","")))
	metadata.element=str(strike_context.get("element",metadata.get("element","physical")))
	metadata.counter_multiplier=float(strike_context.get("counter_multiplier",1.0))
	events.append(BattleEvent.create(kind, text, actor, target, value,metadata))
	battle.log.append(text)
	if battle.log.size() > 100: battle.log.pop_front()

func _begin_round():
	battle.round += 1
	for key in battle.pair_cooldowns: battle.pair_cooldowns[key]=maxi(0,int(battle.pair_cooldowns[key])-1)
	var ordered = battle.units.filter(func(actor): return actor.hp > 0)
	ordered.sort_custom(func(a, b):
		if int(a.speed) != int(b.speed): return a.speed > b.speed
		if a.team != b.team: return a.team == "ally"
		return a.slot < b.slot if a.slot != b.slot else a.id < b.id)
	battle.queue = ordered.map(func(actor): return actor.id)
	battle.cursor = 0
	for foe in living("enemy"): foe.intent = _choose_intent(foe)
	_emit("round", "—— 第 %d 回合 ——" % battle.round)

func _choose_intent(foe: Dictionary) -> Dictionary:
	var allies = living("ally")
	if allies.is_empty(): return {"kind":"attack", "target":"", "label":"等待", "power":1.0}
	allies.sort_custom(func(a, b): return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
	var fronts = allies.filter(func(actor): return actor.slot < 2)
	var target = allies[0] if foe.get("ranged", false) or foe.get("role", "") == "caster" else fronts[0] if not fronts.is_empty() else allies[0]
	for actor in allies:
		if has_effect(actor, "taunt"): target = actor; break
	var kind = "attack"
	var label = "普通攻击"
	var power = 1.0
	if not has_effect(foe, "silence"):
		if foe.get("summoner", false) and foe.phase == 2 and not foe.summoned:
			kind = "summon"; label = "召唤试炼守卫"
		elif foe.get("pressure",false) and not foe.get("boss",false) and int(battle.round)>=4:
			kind="heavy"; label="狂热重击 · 每轮增强"; power=minf(3.0,1.5+(int(battle.round)-4)*.25)
		elif foe.charging:
			kind = "heavy"; label = "蓄力重击"; power = 1.8 if foe.phase == 1 else 2.1
			if foe.get("boss",false) and foe.phase==2: kind="sweep"; label="蓄力横扫 · 全体"; power=1.45
		elif (foe.get("elite", false) or foe.get("boss", false)) and int(battle.round) % 3 == 1:
			kind = "charge"; label = "蓄势 · 下次行动重击"
		elif foe.get("role", "") == "healer" and int(battle.round) % 2 == 0:
			kind = "heal"; label = "治疗同伴"
		elif foe.get("role", "") == "guard" and int(battle.round) % 2 == 1:
			kind = "guard"; label = "护卫阵线"
		elif foe.get("role", "") == "caster":
			kind = "poison"; label = "毒印术"
	if kind == "heal":
		var friends = living("enemy")
		friends.sort_custom(func(a,b): return float(a.hp)/a.max_hp < float(b.hp)/b.max_hp)
		target = friends[0]
	elif kind == "guard":
		var friends = living("enemy").filter(func(friend): return friend.id != foe.id)
		friends.sort_custom(func(a,b): return a.get("role","")=="healer" if (a.get("role","")=="healer")!=(b.get("role","")=="healer") else a.slot>b.slot)
		target = friends[0] if not friends.is_empty() else foe
	elif kind in ["charge","summon"]: target = foe
	return {"kind":kind, "target":target.id, "label":label, "power":power,"element":foe.get("attack_element","physical"),"range":"all" if kind=="sweep" else "single"}

func _prepare_turn():
	var safety = 0
	while battle.result == "" and safety < 100:
		safety += 1
		if _check_result(): return
		if battle.cursor >= battle.queue.size(): _begin_round()
		battle.token += 1
		var actor = current()
		if actor.is_empty() or actor.hp <= 0:
			battle.cursor += 1
			continue
		actor.effects = actor.effects.filter(func(fx): return fx.type not in ["guard", "taunt"] or fx.get("persistent",false))
		if actor.get("break_recover",false):
			actor.break_recover=false; actor.posture=actor.max_posture
			actor.effects=actor.effects.filter(func(fx): return fx.type!="broken")
			_emit("recover",actor.name+"恢复韧性。","",actor.id)
		for key in actor.cooldowns: actor.cooldowns[key] = maxi(0, int(actor.cooldowns[key]) - 1)
		for fx in actor.effects.duplicate(true):
			if fx.type in ["burn", "poison", "bleed"]:
				strike_context={"element":{"burn":"fire","poison":"poison","bleed":"physical"}[fx.type]}; _hurt(actor, int(fx.potency), fx.source, false); strike_context={}
			elif fx.type == "regen": _heal(actor, int(fx.potency), "再生")
		if _check_result(): return
		if actor.get("break_skip",false):
			actor.break_skip=false; actor.break_recover=true
			_emit("skip",actor.name+"因弱点击破失去本次行动。","",actor.id)
			_finish_actor(actor); battle.cursor+=1; continue
		if actor.hp <= 0 or has_effect(actor, "stun"):
			_emit("skip", actor.name + "无法行动。")
			_finish_actor(actor)
			battle.cursor += 1
			continue
		return

func _finish_actor(actor: Dictionary):
	for fx in actor.effects:
		if fx.type!="broken" and int(fx.created)!=int(battle.token): fx.turns-=1
	actor.effects=actor.effects.filter(func(fx): return fx.turns>0)
	for shield in actor.get("shields",[]):
		if int(shield.created)!=int(battle.token): shield.turns-=1
	actor.shields=actor.get("shields",[]).filter(func(shield): return shield.turns>0 and shield.potency>0)
	if has_effect(actor,"broken") and not actor.get("break_skip",false) and not actor.get("break_recover",false):
		actor.break_recover=true

func _check_result() -> bool:
	if living("ally").is_empty(): battle.result = "defeat"
	elif living("enemy").is_empty(): battle.result = "win"
	return battle.result != ""

func legal_targets(actor: Dictionary, action: String = "attack", skill_id: String = "") -> Array:
	var opposite = "enemy" if actor.team == "ally" else "ally"
	if action=="formation": return [actor]
	if action=="bond" and BattleRules.config().bonds.has(skill_id):
		var mode=BattleRules.config().bonds[skill_id].target
		if mode=="ally": return living(actor.team)
		if mode=="rescue": return battle.units.filter(func(candidate): return candidate.team==actor.team)
	if action=="pair" and skill_id=="springlight": return living(actor.team)
	if action in ["guard", "swap"]: return living(actor.team)
	if action == "revive": return battle.units.filter(func(candidate): return candidate.team == actor.team and candidate.hp <= 0)
	if action in ["potion", "tonic"]: return living(actor.team)
	if action=="ultimate":
		if actor.id in ["toren","sylvi","eira"]: return living(actor.team)
		return living(opposite)
	var ranged = actor.job in ["ranger", "arcanist", "priest", "alchemist"] or actor.get("ranged", false)
	if action == "ability" and db.skills.has(skill_id):
		var skill = db.skills[skill_id]
		if skill.target_mode in ["ally", "all_allies"]: return living(actor.team)
		ranged = skill.ranged or skill.target_mode == "all_enemies"
	if action in ["bond", "pair"]: ranged = true
	var candidates = living(opposite)
	var front_size = 3 if opposite == "enemy" else 2
	var fronts = candidates.filter(func(candidate): return candidate.slot < front_size)
	return candidates if ranged or fronts.is_empty() else fronts

func validate(command: Dictionary) -> String:
	var actor = current()
	if actor.is_empty(): return "战斗已结束。"
	if int(command.get("turn", -1)) != int(battle.token): return "该行动已结算，请等待下一次行动。"
	if command.get("actor", "") != actor.id: return "尚未轮到这位角色。"
	var action = command.get("action", "")
	var id = command.get("skill", "")
	if actor.team == "enemy": return "" if action == "enemy" else "敌方回合由敌方行动。"
	if action not in ["attack", "guard", "ability", "ultimate", "swap", "potion", "tonic", "revive", "bond", "pair", "formation", "flee"]: return "无效战斗操作。"
	if action=="formation":
		if id not in db.raw.formations or id==battle.formation: return "请选择不同的阵型。"
		if int(battle.formation_round)==int(battle.round): return "本轮全队已经变阵。"
		return ""
	if action=="ultimate":
		if not actor.get("awakened",false) or not db.progression.ultimates.has(actor.id): return "完成角色觉醒剧情后解锁。"
		if id!="" and id!=actor.id: return "不能使用其他角色的大招。"
		if int(actor.get("tp",0))<100: return "需要 100 TP。"
		if has_effect(actor,"silence"): return "沉默期间不能释放大招。"
	if action == "swap":
		var other = unit(command.get("target", ""))
		return "" if not other.is_empty() and other.team == actor.team and other.id != actor.id and other.hp > 0 else "请选择另一名存活队友换位。"
	if action == "flee": return ""
	if action == "ability":
		if not db.skills.has(id) or id not in actor.skills: return "请先配置这项技能。"
		var skill = db.skills[id]
		if actor.mp < skill.mp: return "法力不足。"
		if int(actor.cooldowns.get(id, 0)) > 0: return "技能仍在冷却。"
		if has_effect(actor, "silence") and actor.job in ["arcanist", "priest", "alchemist"]: return "沉默期间不能施法。"
	if action in ["potion", "tonic", "revive"] and int(battle.items.get(action, 0)) <= 0: return "道具不足。"
	if action == "bond":
		var partner = unit(id)
		if partner.is_empty() or partner.team != "ally" or partner.id == "hero" or partner.hp <= 0 or partner.bond < 60: return "需出战同伴存活，且好感达到 60。"
		if actor.mp < 10 or int(actor.cooldowns.get("bond:" + id, 0)) > 0: return "羁绊技法力或冷却条件未满足。"
	if action == "pair":
		var pair = _pair(id)
		if pair.is_empty(): return "协奏不存在。"
		for member in pair.members:
			var partner = unit(member)
			if partner.is_empty() or partner.hp <= 0 or partner.bond < 60: return "双方须出战、存活且好感达到 60。"
		if battle.synergy < 100 or int(battle.pair_cooldowns.get(id, 0)) > 0: return "需协奏 100，且技能不在冷却中。"
	var candidates = legal_targets(actor, action, id)
	if not candidates.any(func(candidate): return candidate.id == command.get("target", "")): return "目标无效或受到前排保护。"
	return ""

func submit(command: Dictionary) -> Dictionary:
	var error = validate(command)
	if error != "": return {"error":error, "events":[]}
	events = []
	var actor = current()
	var action = command.action
	var target = unit(command.get("target", ""))
	var id = command.get("skill", "")
	var definition=db.progression.ultimates.get(actor.id,{}) if action=="ultimate" else db.raw.skills.get(id,{})
	var label=str(definition.get("name",actor.name+" · "+{"attack":"普通攻击","guard":"护卫","swap":"换位","potion":"赤松药剂","tonic":"法力药剂","revive":"苏生药","bond":"羁绊技","pair":"协奏","flee":"撤离","formation":"战中变阵","enemy":"敌方行动"}.get(action,action)))
	action_context={"action_id":str(battle.instance_id)+":"+str(battle.token),"action":action,"skill_id":id,"caster":actor.id,"element":definition.get("element","physical"),"label":label,"ranged":actor.job in ["ranger","arcanist","priest","alchemist"] or actor.get("ranged",false),"break_granted":false,"synergy_gain":0}
	if action=="ability": action_context.element=db.skills[id].element
	_emit("cast",label,actor.id,target.get("id",""))
	if action == "enemy": _enemy_action(actor)
	elif action=="ultimate": actor.tp=0; _ultimate(actor,target)
	elif action=="formation":
		battle.formation=id; battle.formation_round=battle.round
		_emit("formation","变阵 · "+db.raw.formations[id].name,actor.id,actor.id)
	elif action == "attack": _strike(actor, target, 1.0, "physical", false, actor.name + "普攻")
	elif action == "guard":
		apply_effect(actor, "guard", 1, 0, actor.name, target.id)
		if actor.job == "warden": apply_effect(actor, "taunt", 1, 0, actor.name)
		_emit("guard", actor.name + "架盾护卫" + target.name + "，承伤降低。")
	elif action == "swap":
		var position = actor.slot
		actor.slot = target.slot
		target.slot = position
		_emit("swap", actor.name + "与" + target.name + "交换站位。")
	elif action == "ability":
		var skill = db.skills[id]
		actor.mp -= skill.mp
		actor.cooldowns[id] = skill.cooldown + 1
		_use_skill(actor, target, skill)
	elif action in ["potion", "tonic", "revive"]:
		battle.items[action] -= 1
		if action == "potion": _heal(target, 40, "赤松药剂")
		elif action == "tonic": target.mp = mini(target.max_mp, target.mp + 30); _emit("item", target.name + "恢复 30 法力。")
		else: _revive(target,0.3,"苏生药")
	elif action == "bond":
		actor.mp-=10; actor.cooldowns["bond:"+id]=4
		_use_bond(actor,target,id)
	elif action == "pair":
		battle.synergy = 0
		battle.pair_cooldowns[id] = 5
		_emit("pair", _pair(id).name + "发动！")
		if id == "springlight":
			for ally in living("ally"):
				_heal(ally, ceili(ally.max_hp * 0.4), "回春圣歌"); _cleanse(ally); apply_effect(ally, "regen", 3, ceili(ally.max_hp * 0.06), "回春圣歌")
		else:
			for foe in living("enemy"):
				if id=="venomshadow" and has_effect(foe,"poison"): _hurt(foe,int(effect(foe,"poison").potency)*2,"蚀毒引爆",false)
				_strike(actor, foe, 1.6 * _support_multiplier(actor.team), "fire" if id == "starshield" else "poison", true, _pair(id).name)
				apply_effect(foe, "burn" if id == "starshield" else "poison", 3, ceili(actor.atk * 0.22), _pair(id).name)
			if id == "starshield":
				for ally in living("ally"):
					grant_shield(ally,ceili(ally.max_hp*.25),3,"星盾协奏"); apply_effect(ally,"riposte",3,0,"星盾协奏")
	elif action == "flee":
		if rng.randf() < 0.5: battle.result = "flee"; _emit("flee", "队伍找到撤离的间隙。")
		else: _emit("flee", "撤离失败，继续应战。")
	if actor.team=="ally" and action not in ["ultimate","flee","formation"]: _gain_tp(actor,20)
	if actor.team=="enemy" and action=="enemy": actor.control_protected=false
	_finish_actor(actor)
	_update_phases()
	_check_result()
	if battle.result == "":
		battle.cursor += 1
		action_context={}
		_prepare_turn()
	_store_rng()
	changed.emit(events)
	action_context={}
	return {"error":"", "events":events.duplicate(true), "result":battle.result}

func _gain_tp(actor: Dictionary, amount: int):
	if actor.get("awakened",false) and actor.hp>0: actor.tp=mini(100,int(actor.get("tp",0))+amount)

func _revive(target: Dictionary, fraction: float, source: String):
	if target.hp>0: return
	target.hp=maxi(1,ceili(target.max_hp*fraction)); target.effects=[]; target.shields=[]
	if target.team=="ally": target.tp=0
	_emit("revive",source+" · "+target.name+"重新站起。","",target.id,target.hp)

func _ultimate(actor: Dictionary, target: Dictionary):
	var definition=db.progression.ultimates[actor.id]; var label=str(definition.name)
	match actor.id:
		"hero","mira","alchemist":
			for foe in living("enemy"):
				var extra_posture=(2 if definition.element in foe.weakness else 1) if actor.id=="hero" else 0
				_strike(actor,foe,definition.power,definition.element,true,label,extra_posture)
				if actor.id=="mira": apply_effect(foe,"vulnerable",2,0,label)
				if actor.id=="alchemist": apply_effect(foe,"poison",2,maxi(1,ceili(actor.atk*.3)),label)
			if actor.id=="alchemist":
				for ally in living("ally"):
					var gained=mini(ally.max_mp-ally.mp,ceili(ally.max_mp*.1)); ally.mp+=gained; _emit("mana",label,"",ally.id,gained)
		"toren":
			for ally in living("ally"): grant_shield(ally,ceili(ally.max_hp*.25),2,label,true,"toren:ultimate")
			apply_effect(actor,"taunt",2,0,label); effect(actor,"taunt").persistent=true
		"sylvi":
			for ally in living("ally"):
				_heal(ally,ceili(ally.max_hp*.25),label); apply_effect(ally,"regen",2,ceili(ally.max_hp*.1),label)
		"ridge-scout":
			_strike(actor,target,3.5,"physical",false,label); apply_effect(target,"armorBreak",2,0,label)
		"eira":
			var fallen=battle.units.filter(func(u): return u.team=="ally" and u.hp<=0)
			fallen.sort_custom(func(a,b): return a.slot<b.slot)
			for ally in living("ally"): _heal(ally,ceili(ally.max_hp*.35),label); _cleanse(ally)
			if not fallen.is_empty(): _revive(fallen[0],.3,label)

func _support_multiplier(team: String) -> float:
	var bonus = 0.0
	for supporter in living(team): bonus = maxf(bonus, float(supporter.get("support_bonus",0.0)))
	return 1.0 + bonus

func _strike(actor: Dictionary, original: Dictionary, power: float, element: String, area: bool, label: String, break_power: int = 0, follow: bool = true):
	if original.is_empty() or original.hp <= 0: return
	var prior_context=strike_context
	strike_context={"actor":actor.id,"element":element,"primary":follow}
	if has_effect(actor,"weaken"): power*=1.0-float(BattleRules.config().break.weaken)
	var target=defended_target(original,area)
	if target.id!=original.id:
		_emit("cover",target.name+"替"+original.name+"承受攻击。",target.id,original.id); _synergy(12)
	strike_context.counter_multiplier=BattleRules.multiplier(element,target)
	var defense = target.def * (0.5 if has_effect(target, "armorBreak") else 1.0)
	var formation = db.raw.formations[battle.formation]
	var amount = maxf(1.0, actor.atk * power * rng.randf_range(0.9, 1.1) - defense)
	amount*=BattleRules.multiplier(element,target)
	if not follow: amount *= _support_multiplier(actor.team) * (float(BattleRules.config().formations[battle.formation].follow) if actor.team=="ally" else 1.0)
	if rng.randf() < actor.crit: amount *= 1.6
	if actor.team == "ally": amount *= formation.attack
	if target.team == "ally": amount *= formation.defense
	if has_effect(actor, "blind"): amount *= 0.5
	if has_effect(target, "vulnerable") or has_effect(target, "broken"): amount *= float(BattleRules.config().break.damage_taken)
	if actor.team=="ally" and battle.formation=="assault" and has_effect(target,"broken"): amount*=1.15
	if has_effect(target, "guard"): amount *= 0.4 if target.team=="ally" and battle.formation=="watch" else 0.5
	elif target.team=="ally" and target.slot>=2 and battle.formation=="watch" and living("ally").any(func(a): return a.slot<2 and has_effect(a,"guard")): amount*=0.85
	var dealt = _hurt(target, maxi(1, int(amount)), label)
	var weak = element in target.weakness
	if weak and target.hp>0 and actor.team=="ally":
		var reduction=toughness_reduction(actor,target,element,area,follow)
		if reduction>0:
			if battle.formation=="assault" and actor.slot<2: actor.assault_round=battle.round
			_posture(target,reduction); _synergy(8)
	if actor.team=="ally" and not follow and dealt>0: _synergy(8)
	if actor.drain > 0 and actor.hp > 0: _heal(actor, ceili(dealt * actor.drain), "汲取")
	if ((target.id != original.id and target.job == "warden") or has_effect(target,"riposte")) and target.hp > 0 and actor.hp > 0 and target.follow_round != battle.round:
		target.follow_round = battle.round
		_strike(target, actor, 0.65, "physical", true, "护卫反击", 0, false)
	if follow and actor.team == "ally" and (has_effect(target, "vulnerable") or has_effect(target, "armorBreak") or has_effect(target,"broken")):
		for ally in living("ally"):
			if ally.id != actor.id and ally.follow_round != battle.round and ally.job in ["ranger", "assassin"] and target.hp > 0:
				ally.follow_round = battle.round
				_strike(ally, target, 0.4, "physical", true, ally.name + "协同追击", 0, false)
				break
	strike_context=prior_context

func _hurt(target: Dictionary, amount: int, source: String, log_hit: bool = true) -> int:
	var absorbed=mini(amount,BattleRules.shield_value(target))
	for shield in target.get("shields",[]):
		var old_value=int(shield.potency); shield.potency=maxi(0,old_value-amount)
		if old_value>0 and shield.potency==0: _emit("shield_break",str(shield.source)+"护盾破裂。","",target.id)
	if absorbed>0: _emit("shield_absorb","护盾吸收 %d" % absorbed,"",target.id,absorbed)
	amount-=absorbed
	target.shields=target.get("shields",[]).filter(func(shield): return shield.potency>0)
	var dealt = mini(int(target.hp), maxi(0, amount))
	target.hp = maxi(0, target.hp - dealt)
	if target.team=="ally" and dealt>0 and log_hit:
		var source_actor=unit(strike_context.get("actor",""))
		if source_actor.get("team","")=="enemy":
			if int(target.get("tp_hit_round",0))!=int(battle.round): target.tp_hit_round=battle.round; target.tp_hit_gain=0
			var gain=mini(10,20-int(target.get("tp_hit_gain",0))); _gain_tp(target,gain); target.tp_hit_gain=int(target.get("tp_hit_gain",0))+gain
	if log_hit: _emit("damage", "%s → %s：%d 伤害%s" % [source, target.name, dealt, "（护盾吸收 %d）" % absorbed if absorbed else ""], "", target.id, dealt)
	elif dealt > 0: _emit("dot", "%s受到%s %d。" % [target.name, source, dealt],"",target.id,dealt)
	if target.hp <= 0:
		if target.team=="ally": target.tp=0
		target.effects = []; target.shields=[]
		_emit("ko", target.name + "倒地。")
	return dealt

func _heal(target: Dictionary, amount: int, source: String):
	if target.hp <= 0: return
	var factor = db.raw.formations[battle.formation].healing if target.team == "ally" else 1.0
	var gained = mini(int(target.max_hp - target.hp), ceili(amount * factor))
	target.hp += gained
	_emit("heal", "%s为%s恢复 %d 生命。" % [source, target.name, gained],"",target.id,gained)

func _cleanse(target: Dictionary): target.effects = target.effects.filter(func(fx): return fx.type not in ["burn", "poison", "bleed", "silence"])

func _posture(target: Dictionary, amount: int):
	if target.hp<=0 or target.team!="enemy" or has_effect(target,"broken"): return
	var lost=mini(int(target.posture),amount); target.posture=maxi(0,int(target.posture)-amount)
	_emit("toughness","%s韧性 -%d" % [target.name,lost],"",target.id,lost)
	if target.posture>0: return
	var source_actor=unit(strike_context.get("actor",action_context.get("caster","")))
	if not action_context.is_empty() and not action_context.get("break_granted",false) and action_context.action!="ultimate" and strike_context.get("primary",false):
		_gain_tp(source_actor,10); action_context.break_granted=true
	apply_effect(target,"broken",2,0,"弱点击破")
	target.break_skip=not target.get("control_protected",false); target.break_recover=not target.break_skip
	if target.get("boss",false): target.control_protected=true
	target.charging=false
	target.intent={"kind":"attack","target":"","label":"击破 · 蓄力已打断","power":1.0}
	_synergy(16)
	var element=str(strike_context.get("element","physical")); var cfg=BattleRules.config().break
	if not source_actor.is_empty():
		_hurt(target,maxi(1,ceili(source_actor.atk*float(cfg.power)*BattleRules.multiplier(element,target))),"弱点击破")
		var fx={"physical":"bleed","fire":"burn","astral":"vulnerable","holy":"weaken","poison":"poison"}[element]
		apply_effect(target,fx,2,maxi(2,ceili(source_actor.atk*float(cfg.dot_fraction))),"弱点击破 · "+GameContent.ELEMENT_NAMES[element])
	_emit("break",target.name+"韧性击破！后续伤害 +25%。","",target.id)

func _control(target: Dictionary):
	if target.hp <= 0: return
	if target.get("boss", false) and (battle.round < target.immune_until or target.get("control_protected",false)): _emit("immune", target.name + "抵抗连续控制。"); return
	apply_effect(target, "stun", 1, 0, "封印")
	if target.get("boss", false): target.immune_until = battle.round + 2

func _use_skill(actor: Dictionary, target: Dictionary, skill: SkillDefinition):
	var targets = living(actor.team) if skill.target_mode == "all_allies" else living("enemy" if actor.team == "ally" else "ally") if skill.target_mode == "all_enemies" else [target]
	for recipient in targets:
		if skill.effect in ["heal", "regen", "aegis"]:
			var fraction = 0.28 if skill.effect == "heal" else minf(skill.power, 0.45)
			_heal(recipient, ceili(recipient.max_hp * fraction), skill.display_name)
			_cleanse(recipient)
			if skill.effect == "regen": apply_effect(recipient, "regen", 3, ceili(recipient.max_hp * 0.06), skill.display_name)
			if skill.effect == "aegis": grant_shield(recipient,ceili(recipient.max_hp*fraction),int(skill.shield_rule.turns),skill.display_name,bool(skill.shield_rule.stacking),"skill:"+actor.id+":"+skill.id)
			continue
		_strike(actor, recipient, skill.power, skill.element, skill.target_mode == "all_enemies", skill.display_name, skill.toughness)
		var effect_type = {"burnAll":"burn", "poisonAll":"poison", "markAll":"vulnerable", "silenceAll":"silence", "bleed":"bleed", "poison":"poison", "armorBreak":"armorBreak", "blind":"blind"}.get(skill.effect, "")
		if skill.id == "starfall": effect_type = "burn"
		if skill.id == "predatorMark": effect_type = "vulnerable"
		if effect_type != "": apply_effect(recipient, effect_type, 2 if effect_type == "silence" else 3, maxi(3, ceili(actor.atk * 0.18)), skill.display_name)
		if skill.effect == "seal": _control(recipient)
	if skill.effect in ["wall", "evasive"]:
		apply_effect(actor, "shield", 2, ceili(actor.max_hp * 0.12), skill.display_name)
		apply_effect(actor, "guard", 1, 0, skill.display_name, actor.id)
		if actor.job == "warden": apply_effect(actor, "taunt", 1, 0, skill.display_name)
	if skill.effect == "healStrike": _heal(actor, ceili(actor.max_hp * 0.18), skill.display_name); _cleanse(actor)

func _enemy_action(actor: Dictionary):
	var intent = actor.get("intent", _choose_intent(actor))
	var targets = legal_targets(actor)
	if targets.is_empty(): return
	var target = unit(intent.target)
	if target.is_empty() or target.hp <= 0 or not targets.has(target): target = targets[0]
	for ally in targets:
		if has_effect(ally, "taunt"): target = ally; break
	match intent.kind:
		"charge": actor.charging = true; _emit("charge", actor.name + "正在蓄力！下次行动将重击。")
		"guard":
			var friends = living("enemy").filter(func(friend): return friend.id != actor.id)
			var intended = unit(intent.target)
			if intended.is_empty() or intended.hp <= 0 or intended.team != "enemy": intended = friends[0] if not friends.is_empty() else actor
			apply_effect(actor, "guard", 1, 0, actor.name, intended.id)
			apply_effect(actor, "shield", 2, ceili(actor.max_hp * 0.1), actor.name)
			_emit("guard", actor.name + "建立护卫阵线。")
		"heal":
			var friends = living("enemy")
			friends.sort_custom(func(a, b): return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
			var intended = unit(intent.target)
			if intended.is_empty() or intended.hp <= 0 or intended.team != "enemy": intended = friends[0]
			_heal(intended, ceili(intended.max_hp * 0.22), actor.name)
		"summon":
			actor.summoned = true
			var count = battle.units.filter(func(foe): return foe.team == "enemy").size()
			for index in 2:
				if count >= 6: break
				var occupied = living("enemy").map(func(foe): return foe.slot)
				var slot = 0
				while slot in occupied: slot += 1
				battle.units.append(make_enemy({"name":"试炼召卫", "art":"sentinel", "hp":65, "atk":12, "def":3, "speed":7, "weakness":["astral", "holy"], "slot":slot}, "summon-" + str(count)))
				count += 1
			_emit("summon", actor.name + "召来两名试炼守卫，下回合加入行动。")
		"sweep":
			actor.charging=false
			for ally in living("ally"): _strike(actor,ally,float(intent.power),str(intent.get("element",actor.attack_element)),true,actor.name+" · 蓄力横扫")
		_:
			actor.charging = false
			_strike(actor, target, float(intent.power), str(intent.get("element","poison" if intent.kind=="poison" else actor.attack_element)), false, actor.name + " · " + intent.label)
			if intent.kind == "poison": apply_effect(target, "poison", 3, maxi(3, ceili(actor.atk * 0.18)), actor.name)

func _update_phases():
	for foe in living("enemy"):
		if foe.get("boss", false) and foe.phase == 1 and foe.hp <= foe.max_hp / 2:
			foe.phase = 2
			foe.intent = _choose_intent(foe)
			_emit("phase", foe.name + "进入第二阶段，意图已更新。")
		if has_effect(foe,"silence") and foe.intent.kind != "attack":
			foe.intent = {"kind":"attack", "target":"", "label":"沉默 · 普通攻击", "power":0.8}
		var kind = foe.intent.kind
		if kind in ["charge","summon"]: continue
		var legal = living("enemy") if kind in ["heal","guard"] else legal_targets(foe)
		if not legal.is_empty() and foe.has("intent"):
			var selected = unit(foe.intent.get("target", ""))
			if selected.is_empty() or selected.hp <= 0 or not legal.has(selected): foe.intent.target = legal[0].id
			if kind not in ["heal","guard"]:
				for ally in legal:
					if has_effect(ally, "taunt"): foe.intent.target = ally.id; break

func _pair(id: String) -> Dictionary:
	for pair in db.raw.pairs:
		if pair.id == id: return pair
	return {}

func ai_command() -> Dictionary:
	var actor = current()
	if actor.is_empty(): return {}
	if actor.team == "enemy": return BattleCommand.new(actor.id, "enemy", "", "", battle.token).to_dict()
	var friends = living("ally")
	friends.sort_custom(func(a, b): return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
	var wounded = friends[0]
	if actor.get("ultimate_auto",false) and actor.get("awakened",false) and actor.get("tp",0)>=100:
		var choices=legal_targets(actor,"ultimate",actor.id)
		if not choices.is_empty():
			var command=BattleCommand.new(actor.id,"ultimate",choices[0].id,actor.id,battle.token).to_dict()
			if validate(command)=="": return command
	var reserve = actor.max_mp * actor.mana_reserve if actor.tactic == "reserve" else 0
	if float(wounded.hp) / wounded.max_hp < actor.heal_threshold:
		for id in actor.skills:
			var skill = db.skills[id]
			if skill.target_mode in ["ally", "all_allies"] and actor.mp - skill.mp >= reserve:
				var command = BattleCommand.new(actor.id, "ability", wounded.id, id, battle.token).to_dict()
				if validate(command) == "": return command
		if actor.tactic == "protect" and actor.job == "warden": return BattleCommand.new(actor.id, "guard", wounded.id, "", battle.token).to_dict()
	var knocked_out = legal_targets(actor, "revive")
	if not knocked_out.is_empty() and battle.items.revive > 0 and actor.tactic == "protect": return BattleCommand.new(actor.id, "revive", knocked_out[0].id, "", battle.token).to_dict()
	var targets = legal_targets(actor)
	if targets.is_empty(): return BattleCommand.new(actor.id, "guard", actor.id, "", battle.token).to_dict()
	targets.sort_custom(func(a, b):
		if actor.focus == "marked" and has_effect(a, "vulnerable") != has_effect(b, "vulnerable"): return has_effect(a, "vulnerable")
		if actor.focus == "charging" and a.charging != b.charging: return a.charging
		return float(a.hp) / a.max_hp < float(b.hp) / b.max_hp)
	var target = targets[0]
	var options = []
	for id in actor.skills:
		var skill = db.skills[id]
		if skill.target_mode in ["ally", "all_allies"] or actor.mp - skill.mp < reserve: continue
		var legal = legal_targets(actor, "ability", id)
		if legal.is_empty(): continue
		legal.sort_custom(func(a,b): return ai_score(actor,a,skill)>ai_score(actor,b,skill))
		var chosen=legal[0]
		var command = BattleCommand.new(actor.id, "ability", chosen.id, id, battle.token).to_dict()
		if validate(command) != "": continue
		var score=ai_score(actor,chosen,skill)+(0.8 if skill.target_mode=="all_enemies" and legal.size()>1 else 0.0)
		options.append({"command":command, "score":score})
	options.sort_custom(func(a, b): return a.score > b.score)
	if not options.is_empty(): return options[0].command
	return BattleCommand.new(actor.id, "attack", target.id, "", battle.token).to_dict()

func grant_shield(actor: Dictionary, amount: int, turns: int, source: String, stacking: bool = false, source_key: String = ""):
	if actor.is_empty() or actor.hp<=0: return
	var factor=float(BattleRules.config().formations[battle.formation].shield) if actor.team=="ally" else 1.0
	amount=maxi(1,ceili(amount*factor))
	var key=source_key if source_key!="" else str(action_context.get("caster",""))+":"+source
	if not actor.has("shields"): actor.shields=[]
	var found={}
	for shield in actor.shields:
		if shield.key==key: found=shield; break
	if found.is_empty():
		found={"key":key,"source":source,"potency":0,"turns":turns,"created":battle.token}; actor.shields.append(found)
	found.potency=mini(ceili(actor.max_hp*.6),int(found.potency)+amount) if stacking else maxi(int(found.potency),amount)
	found.turns=turns; found.created=battle.token
	_emit("status",source+" · 护盾 %d" % found.potency,"",actor.id,int(found.potency)); events[-1].effect="shield"

func _synergy(amount: int):
	if action_context.is_empty(): return
	var actor=unit(str(action_context.get("caster","")))
	# Cover is earned during enemy commands; its value is still bounded per command.
	if actor.get("team","")!="ally" and not events.any(func(e): return e.kind=="cover" and unit(e.actor).get("team","")=="ally"): return
	var factor=float(BattleRules.config().formations[battle.formation].synergy)
	var gain=mini(30-int(action_context.get("synergy_gain",0)),ceili(amount*factor))
	if gain>0: battle.synergy=mini(100,battle.synergy+gain); action_context.synergy_gain=int(action_context.get("synergy_gain",0))+gain

func toughness_reduction(actor: Dictionary, target: Dictionary, element: String, area: bool = false, primary: bool = true) -> int:
	if not primary or target.get("team","")!="enemy" or element not in target.weakness or has_effect(target,"broken"): return 0
	var action=str(action_context.get("action","attack")); var cfg=BattleRules.config().reduction
	var value=int(cfg.get(action,cfg.area if area else cfg.single))
	if action=="ability": value=int(db.skills[str(action_context.skill_id)].toughness)
	if action=="bond" and action_context.get("skill_id","")=="mira": value=30
	if actor.team=="ally" and battle.formation=="assault" and actor.slot<2 and int(actor.get("assault_round",0))!=int(battle.round): value+=10
	return mini(value,int(target.posture))

func preview(actor: Dictionary, target: Dictionary, action: String, id: String = "") -> Dictionary:
	var element="physical"; var area=false
	if action=="ability" and db.skills.has(id): element=db.skills[id].element; area=db.skills[id].target_mode=="all_enemies"
	elif action=="ultimate": element=db.progression.ultimates[actor.id].element; area=true
	elif action=="bond" and BattleRules.config().bonds.has(id): element=BattleRules.config().bonds[id].element
	elif action=="pair": element="fire" if id=="starshield" else "poison"; area=true
	target=defended_target(target,area)
	var prior=action_context; action_context={"action":action,"skill_id":id}
	var reduction=toughness_reduction(actor,target,element,area) if action in ["attack","ability","ultimate","bond","pair"] and target.team=="enemy" else 0
	action_context=prior
	return {"element":element,"target":target.id,"multiplier":BattleRules.multiplier(element,target),"reduction":reduction,"breaks":target.get("posture",0)>0 and reduction>=int(target.get("posture",0))}

func defended_target(original: Dictionary, area: bool = false) -> Dictionary:
	if not area:
		for guard in living(original.team):
			var cover=effect(guard,"guard")
			if guard.id!=original.id and not cover.is_empty() and cover.cover==original.id: return guard
	return original

func _use_bond(actor: Dictionary, target: Dictionary, id: String):
	var label=BattleRules.config().bonds[id].name
	match id:
		"toren":
			grant_shield(target,ceili(target.max_hp*.25),2,label,true,"toren:bond")
			var protector=unit(id); apply_effect(protector,"guard",2,0,label,target.id); effect(protector,"guard").persistent=true
		"sylvi":
			_heal(target,ceili(target.max_hp*.3),label); _cleanse(target); apply_effect(target,"regen",3,ceili(target.max_hp*.06),label)
		"eira":
			if target.hp<=0: _revive(target,.3,label)
			else: _heal(target,ceili(target.max_hp*.3),label); grant_shield(target,ceili(target.max_hp*.15),2,label)
		"mira":
			_strike(actor,target,1.5,"astral",false,label)
			if has_effect(target,"broken"): _control(target)
		"ridge-scout":
			var power=2.4 if has_effect(target,"vulnerable") or has_effect(target,"broken") else 1.5
			_strike(actor,target,power,"physical",false,label); apply_effect(target,"vulnerable",2,0,label)
		"alchemist":
			_strike(actor,target,1.4,"poison",false,label); apply_effect(target,"poison",3,maxi(3,ceili(actor.atk*.25)),label)
			for ally in living("ally"):
				var gain=mini(ally.max_mp-ally.mp,ceili(ally.max_mp*.1)); ally.mp+=gain; _emit("mana",label,"",ally.id,gain)

func ai_score(actor: Dictionary, target: Dictionary, skill: SkillDefinition) -> float:
	var estimate=preview(actor,target,"ability",skill.id)
	return skill.power*float(estimate.multiplier)+(1.2 if estimate.reduction>0 else 0.0)+(2.0 if estimate.breaks and target.get("charging",false) else 0.0)+(0.6 if actor.focus=="charging" and target.get("charging",false) else 0.0)+(0.4 if actor.focus=="marked" and has_effect(target,"vulnerable") else 0.0)+(1.0-float(target.hp)/target.max_hp)*.4
