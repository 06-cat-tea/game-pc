extends RefCounted

var db: GameContent
func _init(content: GameContent): db=content

func command(engine: BattleEngine, action: String, target: String, id: String = "") -> Dictionary:
	return BattleCommand.new(engine.current().id,action,target,id,engine.battle.token).to_dict()

func tactical(engine: BattleEngine) -> Dictionary:
	var actor=engine.current()
	if actor.team=="enemy": return engine.ai_command()
	var allies=engine.living("ally"); allies.sort_custom(func(a,b): return float(a.hp)/a.max_hp<float(b.hp)/b.max_hp)
	# Rescue and protection have priority over burst; no knowledge of random results is used.
	if not engine.unit("eira").is_empty():
		for target in engine.battle.units:
			if target.team=="ally" and target.hp<=0:
				var rescue=command(engine,"bond",target.id,"eira")
				if engine.validate(rescue)=="": return rescue
	for pair in db.raw.pairs:
		if pair.id=="springlight" and float(allies[0].hp)/allies[0].max_hp>.65: continue
		var targets=engine.legal_targets(actor,"pair",pair.id)
		if not targets.is_empty():
			var pair_command=command(engine,"pair",targets[0].id,pair.id)
			if engine.validate(pair_command)=="": return pair_command
	if float(allies[0].hp)/allies[0].max_hp<.45:
		for id in ["sylvi","eira","toren"]:
			var heal=command(engine,"bond",allies[0].id,id)
			if engine.validate(heal)=="": return heal
	if actor.get("awakened",false) and actor.tp>=100:
		var targets=engine.legal_targets(actor,"ultimate",actor.id)
		if not targets.is_empty():
			var burst=command(engine,"ultimate",targets[0].id,actor.id)
			if engine.validate(burst)=="": return burst
	var danger=engine.living("enemy").any(func(foe): return foe.intent.kind in ["heavy","sweep"])
	if danger:
		for enemy in engine.living("enemy"):
			if enemy.intent.kind not in ["heavy","sweep"]: continue
			var threatened=engine.unit(enemy.intent.target)
			if threatened.get("team","")!="ally": threatened=allies[0]
			if BattleRules.shield_value(threatened)<ceili(threatened.max_hp*.2):
				var barrier=command(engine,"bond",threatened.id,"toren")
				if engine.validate(barrier)=="": return barrier
	var desired="watch" if danger else "assault" if engine.living("enemy").any(func(foe): return engine.has_effect(foe,"broken")) else "balanced"
	if desired!=engine.battle.formation and (danger or desired=="assault"):
		var formation=command(engine,"formation",actor.id,desired)
		if engine.validate(formation)=="": return formation
	var basic=engine.ai_command()
	if basic.action=="ability" and db.skills[basic.skill].target_mode in ["ally","all_allies"]: return basic
	var foes=engine.living("enemy"); foes.sort_custom(func(a,b): return (a.get("role","")=="healer") if (a.get("role","")=="healer")!=(b.get("role","")=="healer") else a.hp<b.hp)
	for id in ["ridge-scout","mira","alchemist"]:
		for foe in foes:
			var bond=command(engine,"bond",foe.id,id)
			if engine.validate(bond)=="" and (engine.has_effect(foe,"broken") or basic.action=="attack"): return bond
	return basic

