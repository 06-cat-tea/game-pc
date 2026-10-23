class_name ProgressionRuntime
extends RefCounted

var reference: WeakRef
var trial_actor=""
var game:
	get: return reference.get_ref()
var db:
	get: return game.db
var s:
	get: return game.state

func _init(session): reference=weakref(session)

func initialize():
	if not s.story.has("awakenings"): s.story.awakenings={}
	if not s.story.has("building_services"): s.story.building_services={}
	for entry in s.story.awakenings.values():
		entry.stage=int(entry.stage); entry.clues=entry.clues.map(func(index): return int(index))
	for member in s.members.values():
		member.tp=int(member.get("tp",0)); member.ultimate_auto=member.get("ultimate_auto",false)

func available(id: String) -> bool:
	if not s.members.has(id): return false
	return s.chapter_complete if id=="hero" else s.personal.get(id,{}).get("done",false)

func record(id: String) -> Dictionary: return s.story.awakenings.get(id,{"stage":0,"clues":[]})
func unlocked(id: String) -> bool: return int(record(id).stage)==4

func status(id: String) -> String:
	if unlocked(id): return "已觉醒 · "+db.progression.ultimates[id].name
	if not available(id): return "完成序章后开放" if id=="hero" else "入队并完成同行委托后开放"
	return ["可接取觉醒故事","调查两处线索（%d / 2）" % record(id).clues.size(),"线索齐备 · 准备试炼","回到故事地点完成交谈"][int(record(id).stage)]

func begin(id: String) -> String:
	if s.training or s.battle!=null or not available(id): return "觉醒前置尚未满足。"
	if s.location.scene!=db.progression.ultimates[id].scene: return "请先前往故事发生的建筑。"
	if int(record(id).stage)>0: return "故事已记录，继续调查即可。"
	s.story.awakenings[id]={"stage":1,"clues":[]}
	game.tasks.ledger.sequence+=1; s.story.awakenings[id].order=game.tasks.ledger.sequence
	game.log_message("觉醒故事「"+db.progression.ultimates[id].title+"」开始。")
	return game.last_message

func scene_props(scene: String) -> Array:
	var props=db.raw.scenes[scene].props.duplicate(true)
	for id in db.progression.ultimates:
		var definition=db.progression.ultimates[id]
		if definition.scene==scene and int(record(id).stage) in [1,2]:
			for clue in definition.clues: props.append(clue)
	return props

func observe(scene: String, prop: Dictionary):
	if s.training or not prop.has("awakening"): return
	var id=str(prop.awakening); var progress=record(id)
	if int(progress.stage)!=1 or scene!=db.progression.ultimates[id].scene: return
	if int(prop.clue) not in progress.clues: progress.clues.append(int(prop.clue))
	if progress.clues.size()==2: progress.stage=2
	game.changed.emit()

func begin_trial(id: String) -> String:
	if int(record(id).stage)!=2 or s.battle!=null or s.training: return "请先完成两处线索调查。"
	if s.location.scene!=db.progression.ultimates[id].scene: return "请回到故事发生的建筑。"
	var team=s.active.filter(func(who): return who!="hero" and who!=id)
	if id!="hero": team.push_front(id)
	for who in ["mira","toren","eira","sylvi","ridge-scout","alchemist"]:
		if team.size()>=3: break
		if who not in team: team.append(who)
	var error=game.enter_training(s.members.hero.job,team.slice(0,3),6)
	if error.begins_with("请") or error.begins_with("已经"): return error
	trial_actor=id
	for who in s.members:
		s.story.awakenings[who]={"stage":4,"clues":[0,1]}
		s.members[who].tp=100
	return game.start_battle("awakening-"+id,7300+db.progression.ultimates.keys().find(id))

func finish_trial() -> String:
	if trial_actor=="": return ""
	if s.battle!=null: return "请完成试炼，或选择退出训练。"
	var id=trial_actor; var won=game.engine.battle.get("result","")=="win"
	trial_actor=""; game.exit_training()
	if won: s.story.awakenings[id].stage=3; game.log_message("试炼回响已平息。回到「"+db.progression.ultimates[id].title+"」完成最后的交谈。")
	return "试炼完成，剧情队伍与 TP 已恢复。" if won else "试炼结束，原队伍与 TP 已恢复，可以重新挑战。"

func complete(id: String) -> String:
	if s.training or s.battle!=null or int(record(id).stage)!=3: return "请先完成觉醒试炼。"
	if s.location.scene!=db.progression.ultimates[id].scene: return "请回到故事发生的建筑。"
	s.story.awakenings[id].stage=4; s.members[id].tp=0
	game.log_message(db.actors[id].display_name+"觉醒「"+db.progression.ultimates[id].name+"」。")
	return game.last_message

func at_site(id: String) -> bool:
	var site=db.progression.buildings.get(id,{})
	return not site.is_empty() and s.location.scene==site.scene

func use_service(id: String) -> String:
	if s.training or s.battle!=null: return "请先结束战斗或训练。"
	if not at_site(id): return "请先进入对应建筑或调查地点。"
	var site=db.progression.buildings[id]
	if site.type in ["commission","research","order"]:
		var task="service:"+id
		if not game.tasks.accepted(task): return "请先明确接取这项委托。"
		if game.tasks.status(task)=="completed": return "这项记录已经完成。"
		if site.type=="commission": return game.tasks.turn_in(task,"board" if id=="guildhall" else task)
		if game.tasks.status(task)=="ready": return game.tasks.turn_in(task,task)
		if site.type=="order":
			var result=game.craft(site.recipe)
			if not s.flags.get("crafted:"+site.recipe,false): return result
		game.tasks.ledger.records[task].stage=1
		game.log_message("目标已达成，请交付「"+site.name+"」领取奖励。")
		return game.last_message
	if s.story.building_services.get(id,false): return "这项记录已经完成。"
	match site.type:
		"commission":
			if s.materials[site.material]<site.amount: return "材料不足，需要"+("草药" if site.material=="herb" else "矿石")+" %d。" % site.amount
			s.materials[site.material]-=site.amount; s.gold+=site.gold; game.grant_xp(["hero"],site.xp)
		"order":
			if not s.flags.get("crafted:"+site.recipe,false):
				var text=game.craft(site.recipe)
				if not s.flags.get("crafted:"+site.recipe,false): return text
			game.grant_xp(["hero"],site.xp)
		"research":
			game.grant_xp(["hero"],site.xp)
			var marker="building-clue:"+id
			if marker not in s.story.discovered: s.story.discovered.append(marker)
		"clue":
			var marker="building-clue:"+id
			if marker not in s.story.discovered: s.story.discovered.append(marker)
		_: return "请使用故事、档案或演练入口。"
	s.story.building_services[id]=true
	game.log_message("完成「"+site.name+"」。记录已写入旅途档案。")
	return game.last_message

func validate(saved: Dictionary) -> String:
	if not saved.get("story",{}) is Dictionary: return "剧情记录无效。"
	var data=saved.get("story",{})
	if not data.get("awakenings",{}) is Dictionary or not data.get("building_services",{}) is Dictionary: return "觉醒与建筑记录无效。"
	for id in data.get("awakenings",{}):
		var entry=data.awakenings[id]
		if not db.progression.ultimates.has(id) or not entry is Dictionary or not game._number(entry.get("stage"),0,4) or entry.stage!=floor(float(entry.stage)) or not entry.get("clues") is Array: return "觉醒阶段无效。"
		if entry.clues.size()>2: return "觉醒线索无效。"
		var observed={}
		for clue in entry.clues:
			if not game._number(clue,0,1) or float(clue)!=floor(float(clue)) or observed.has(int(clue)): return "觉醒线索无效。"
			observed[int(clue)]=true
		if entry.stage>=2 and entry.clues.size()!=2: return "觉醒线索不完整。"
	for id in data.get("building_services",{}):
		if not db.progression.buildings.has(id) or not data.building_services[id] is bool: return "建筑服务记录无效。"
	return ""
