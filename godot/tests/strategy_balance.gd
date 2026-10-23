extends SceneTree

var db: GameContent

func _initialize(): call_deferred("run")

func tactical(engine: BattleEngine) -> Dictionary:
	return load("res://tests/strategy_policy.gd").new(db).tactical(engine)

func battle(id: String, level: int, job: String, team: Array, seed_value: int, policy: String) -> Dictionary:
	var game=GameSession.new(db); game.new_game(job); game.enter_training(job,team,level)
	# Both policies receive the same ordinary gear, learned skills, consumables and zero initial TP.
	for member in game.state.members.values():
		member.tp=0; member.ultimate_auto=false
		member.learned=db.job_skills(member.job).filter(func(id): return int(db.skills[id].data.level)<=level)
		member.loadouts[member.job]=member.learned.filter(func(id): return db.skills[id].data.kind=="active").slice(0,4)
		game.recover(member.id,true)
	game.state.items={"potion":2,"tonic":1,"revive":1}
	game.start_battle(id,seed_value)
	var engine=game.engine; var turns=0; var actions={}
	while engine.battle.result=="" and turns<500:
		var c=tactical(engine) if policy=="tactical" else engine.ai_command()
		var result=engine.submit(c)
		if result.error!="": return {"result":"error","error":result.error}
		actions[c.action]=int(actions.get(c.action,0))+1; turns+=1
	return {"result":engine.battle.result,"rounds":engine.battle.round,"actions":actions,"survivors":engine.living("ally").size()}

func run():
	db=GameContent.new()
	var reports=[]; var seeds=50
	for setup in [{"job":"ranger","team":["mira","toren","eira"]},{"job":"assassin","team":["alchemist","sylvi","eira"]}]:
		for encounter in [{"id":"town-wall-1","level":2,"normal":true},{"id":"elite-wood","level":2,"normal":false},{"id":"boss-wood","level":3,"normal":false},{"id":"advanced-pass","level":10,"normal":false}]:
			for policy in (["auto"] if encounter.normal else ["auto","tactical"]):
				var wins=0; var rounds=0; var actions={}; var errors=[]
				for i in seeds:
					var result=battle(encounter.id,encounter.level,setup.job,setup.team,17000+i,policy)
					if result.result=="win": wins+=1
					if result.has("error"): errors.append(result.error)
					rounds+=int(result.get("rounds",0))
					for key in result.get("actions",{}): actions[key]=int(actions.get(key,0))+int(result.actions[key])
				var row={"encounter":encounter.id,"level":encounter.level,"hero_job":setup.job,"team":setup.team,"policy":policy,"wins":wins,"samples":seeds,"win_rate":float(wins)/seeds,"average_rounds":float(rounds)/seeds,"actions":actions,"errors":errors}
				reports.append(row); print(JSON.stringify(row))
	var tiers={}
	for row in reports:
		var tier="normal" if row.encounter.begins_with("town-wall") else "elite" if row.encounter.begins_with("elite") else "boss"
		var key=tier+":"+row.policy
		if not tiers.has(key): tiers[key]={"wins":0,"samples":0}
		tiers[key].wins+=row.wins; tiers[key].samples+=row.samples
	for key in tiers: tiers[key].win_rate=float(tiers[key].wins)/tiers[key].samples
	var passed=tiers["normal:auto"].win_rate>=.85
	for tier in ["elite","boss"]: passed=passed and tiers[tier+":tactical"].win_rate>=.8 and tiers[tier+":tactical"].win_rate-tiers[tier+":auto"].win_rate>=.25
	var report={"passed":passed,"acceptance":"Across the two party compositions, normal auto >=85%; elite and boss tactical >=80%, improving >=25 percentage points over the same built-in auto policy. Advanced encounters are included in boss aggregates and also reported individually.","seed_start":17000,"samples_per_case":seeds,"initial_tp":0,"equipment":"职业基础武器、行旅皮甲，无强化；仅学习推荐等级内技能","tiers":tiers,"reports":reports}
	var file=FileAccess.open("res://../artifacts/godot/strategy-balance.json",FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(report,"\t"))
	print("BALANCE SUMMARY: "+JSON.stringify(tiers)+" passed="+str(passed))
	quit(0 if passed else 1)
