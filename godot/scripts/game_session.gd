class_name GameSession
extends RefCounted

signal changed
var db: GameContent
var state = {}
var engine: BattleEngine
var training_snapshot = {}
var last_message = ""
var story: StoryRuntime
var progression: ProgressionRuntime
var tasks: QuestRuntime
var presentation_revision=0
const FORMAT = "ashen-frontier-godot-desktop"

func _init(content: GameContent):
	db = content
	engine = BattleEngine.new(db)
	story = StoryRuntime.new(self)
	progression = ProgressionRuntime.new(self)
	tasks = QuestRuntime.new(self)

func new_game(job: String = "ranger"):
	presentation_revision+=1
	if job not in ["ranger", "arcanist", "warden"]: job = "ranger"
	state = {"combat_rules_version":2,"format":FORMAT, "version":1, "members":{}, "active":["hero"], "gear":{}, "next_uid":1, "gold":95, "items":{"potion":2, "tonic":1, "revive":1}, "materials":{"herb":0, "ore":0, "shard":0}, "supplies":3, "day":1, "phase":0, "rep":0, "knowledge":0, "light":0, "trust":0, "formation":"balanced", "unlocked_jobs":["ranger", "arcanist", "warden"], "affinity":{}, "personal":{}, "quests":{"first":{"progress":0,"done":false},"stars":{"progress":0,"done":false}}, "flags":{}, "scene_progress":{}, "encounters":{}, "dialogue":{}, "location":{"scene":"town","x":30.0,"y":27.0}, "battle":null, "training":false, "chapter_complete":false, "log":["你在晨星镇醒来。钟塔的第十三声，像在等待一个回答。"], "settings":{"reduce_motion":false, "master_volume":0.8}, "seed_counter":1}
	for id in db.raw.npcs: state.affinity[id] = {"value":0, "chat_day":0, "gift_day":0}
	for id in db.raw.companions:
		if not state.affinity.has(id): state.affinity[id] = {"value":0, "chat_day":0, "gift_day":0}
	_add_member("hero", job, 1)
	var weapon = add_gear("sword")
	var armor = add_gear("cloak")
	state.members.hero.equip.weapon = weapon
	state.members.hero.equip.armor = armor
	recover("hero", true)
	training_snapshot = {}
	story.initialize()
	progression.initialize()
	tasks.initialize(true)
	changed.emit()

func _add_member(id: String, job: String, level: int):
	var member = PartyMemberState.create(id, job, level)
	member.slot = mini(3, state.active.size()) if id != "hero" else 0
	state.members[id] = member
	var starters = {"ranger":"piercing", "arcanist":"starfall", "warden":"shieldWall", "assassin":"assassin_execution_2", "priest":"priest_redemption_2", "alchemist":"alchemist_medicine_2"}
	var skill = starters[job]
	member.learned.append(skill)
	member.loadouts[job] = [skill]
	member.skill_points = maxi(0, member.skill_points - int(db.skills[skill].data.cost))
	recover(id, true)

func recover(id: String, full: bool = false):
	var member = state.members[id]
	var stats = PartyMemberState.stats(member, state, db)
	member.hp = stats.max_hp if full or member.hp < 0 else clampi(int(member.hp), 0, stats.max_hp)
	member.mp = stats.max_mp if full or member.mp < 0 else clampi(int(member.mp), 0, stats.max_mp)

func add_gear(item: String) -> String:
	var uid = "gear-" + str(int(state.next_uid))
	state.next_uid += 1
	state.gear[uid] = {"item":item, "rank":0}
	return uid

func log_message(text: String):
	last_message = text
	state.log.append(text)
	if state.log.size() > 100: state.log.pop_front()
	changed.emit()

func advance_time():
	state.phase += 1
	if state.phase >= 4: state.phase = 0; state.day += 1

func visit(scene: String) -> String:
	if state.battle != null: return "请先结束战斗。"
	if db.regions.has(scene) and state.training: return "请先退出训练，再前往其他区域。"
	if scene != "town" and not db.raw.scenes.has(scene) and not db.regions.has(scene): return "地点不存在。"
	if scene==state.location.scene and db.raw.scenes.has(scene): return ""
	if scene == "town-drain" and not state.scene_progress.get("town-wall:survey", false): return "先调查城墙巡径的线索。"
	if scene == "town-trial" and not state.scene_progress.get("town-drain:survey", false): return "先调查旧城地下渠的线索。"
	var travel_result=story.travel(scene)
	if travel_result=="restored": changed.emit(); return ""
	if travel_result!="": return travel_result
	var spawn=db.regions[scene].spawn if db.regions.has(scene) else [30.0,27.0] if scene=="town" else [8.5,8.5]
	state.location = {"scene":scene,"x":float(spawn[0]),"y":float(spawn[1])}
	changed.emit()
	return ""

func _activity():
	if not tasks.accepted("first") or state.quests.first.done: return
	state.quests.first.progress=mini(3,int(state.quests.first.progress)+1)

func inspect_prop(scene: String, prop: Dictionary) -> String:
	if not db.raw.scenes.has(scene): return "场景不存在。"
	if prop.has("awakening") or prop.has("building"):
		if state.training or state.battle!=null or state.location.scene!=scene: return "请在对应场景调查物件。"
		var found=progression.scene_props(scene).filter(func(p): return p.id==prop.get("id",""))
		if found.is_empty(): return "这处线索尚未出现。"
		prop=found[0]; progression.observe(scene,prop); story.observe(scene,prop); log_message(prop.detail); return prop.detail
	if state.training or state.battle!=null or state.location.scene!=scene or not db.raw.scenes[scene].props.any(func(p): return p.id==prop.get("id","")): return "请在对应场景调查物件。"
	for original in db.raw.scenes[scene].props:
		if original.id==prop.id: prop=original; break
	if scene not in db.chapter_scenes: return story.inspect(scene,prop)
	story.observe(scene,prop)
	var key = scene + ":" + str(prop.id)
	var action = prop.get("action", "service")
	if action == "survey":
		if not state.scene_progress.get(scene + ":survey", false):
			state.scene_progress[scene + ":survey"] = true; state.knowledge += 1; grant_xp(state.active, 25); _activity()
			if scene == "town-drain": state.flags.drain_clue = true
			_progress_personal(scene, "survey")
			_check_chapter()
			log_message("已记录「" + db.raw.scenes[scene].title + "」的归路线索。")
		story.observe(scene,prop); _progress_personal(scene,"survey")
		return prop.detail
	if action == "cache":
		if state.flags.get(key, false): return "储物柜已经取用过。"
		state.flags[key] = true; state.gold += 12; state.materials.herb += 2; state.materials.ore += 2; state.materials.shard += 1; state.supplies += 1; _activity()
		var herb_bonus = 0
		for id in state.active: herb_bonus += int(PartyMemberState.stats(state.members[id],state,db).herb_bonus)
		state.materials.herb += herb_bonus
		log_message("取得旅行补给：草药 %d、矿石 2、星屑 1、金币 12。" % (2 + herb_bonus))
		return last_message
	if action == "restore":
		if state.flags.get(key, 0) == state.day: return "今天已经在此休整。"
		state.flags[key] = state.day
		for id in state.active:
			var member = state.members[id]; var stats = PartyMemberState.stats(member, state, db)
			var fraction = 0.25 * (1.0 + stats.camp_bonus)
			member.hp = mini(stats.max_hp, maxi(1, int(member.hp)) + ceili(stats.max_hp * fraction)); member.mp = mini(stats.max_mp, int(member.mp) + ceili(stats.max_mp * fraction))
		log_message("整理装备，全队恢复部分生命与法力。")
		return last_message
	if action in ["event", "encounter", "portal"]: return ""
	if not state.flags.get(key, false):
		state.flags[key] = true
		if prop.id in ["star-chart", "local-record", "map-table", "ledger"]: state.knowledge += 1
		_activity()
	_progress_personal(scene, str(prop.id))
	if prop.id == "altar": state.light += 1; _quest_progress("candle", 1)
	log_message(str(prop.detail))
	return str(prop.detail)

func choose_event(scene: String, choice: int) -> String:
	if not db.raw.events.has(scene) or choice not in [0,1] or state.battle!=null or state.training: return "事件选项无效。"
	if scene not in GameContent.ROUTES:
		if state.location.scene!=scene: return "请前往事件所在路线。"
		var event_key=scene+":choice"
		if state.flags.has(event_key): return "这次抉择已经记入旅途。"
		state.flags[event_key]=choice
		if choice==0: state.trust+=1; state.materials.herb+=1; story.affinity(db.narrative.expeditions[db.place_of(scene)].npc,6)
		else: state.knowledge+=1; state.materials.ore+=2; state.gold+=20
		log_message(db.raw.events[scene].choices[choice]); return last_message
	if state.flags.has(scene + ":choice"): return "你已作出选择：" + db.raw.events[scene].choices[int(state.flags[scene + ":choice"])]
	state.flags[scene + ":choice"] = choice
	if choice == 0: state.trust += 1; state.light += 1
	else: state.knowledge += 1
	_activity()
	log_message(db.raw.events[scene].choices[choice])
	return last_message

func chat(id: String) -> String:
	var relation = state.affinity[id]
	if relation.chat_day != state.day: relation.chat_day = state.day; relation.value = mini(100, relation.value + 4)
	changed.emit()
	return db.raw.npcs[id].get("line", "旅人，愿归灯与你同在。")

func topic_completed(id: String, topic: String) -> bool:
	return state.dialogue.get(id+":"+topic+":read",false) or (topic=="past" and state.dialogue.has(id+":past"))

func topic_choice(id: String, topic: String, choice: int) -> String:
	var key = id + ":" + topic
	var content = db.raw.dialogues.get(id, {}).get(topic, {})
	if content.is_empty(): return "暂无更多话题。"
	if choice<0 or choice>=content.options.size() or state.affinity[id].value<float(content.get("min",0)): return "话题尚未解锁。"
	if topic == "past" and state.dialogue.has(key): choice = int(state.dialogue[key])
	elif topic == "past":
		state.dialogue[key] = choice
		if choice == 0: state.affinity[id].value = mini(100, state.affinity[id].value + 2)
	state.dialogue[key + ":read"] = true
	changed.emit()
	return content.options[choice].reply + "\n\n" + str(content.get("end", ""))

func gift(id: String) -> String:
	var relation = state.affinity[id]
	if relation.gift_day == state.day: return "今天已经赠过礼物。"
	var material = "shard" if id in ["mira", "eira"] else "ore" if id in ["toren","forge-master"] else "herb"
	if state.materials[material] < 1: return "材料不足：需要" + {"shard":"星屑", "ore":"矿石", "herb":"草药"}[material] + " 1。"
	state.materials[material] -= 1; relation.gift_day = state.day; relation.value = mini(100, relation.value + 6)
	log_message("赠礼完成，好感 +6。")
	return last_message

func accept_personal(id: String) -> String:
	return tasks.accept("personal:"+id,id)

func _progress_personal(scene: String, prop: String):
	for id in state.personal:
		var quest = state.personal[id]; var definition = db.raw.personal[id]
		if quest.done or int(quest.stage)>=2: continue
		var stage = int(quest.stage)
		if definition.props[stage] != prop or (definition.scene if stage == 0 else definition.next) != scene: continue
		if stage == 0: quest.stage = 1; log_message("「" + definition.name + "」已找到传承记录。")
		else:
			quest.stage=2; log_message("「"+definition.name+"」目标达成，请返回委托人交付。")

func recruit(id: String) -> String:
	if not db.raw.companions.has(id): return "这位居民不参与战斗。"
	if state.members.has(id): return "这位同伴已经加入。"
	var eligible = state.personal.get(id, {}).get("done", false)
	if id == "mira": eligible = eligible or state.knowledge >= 1 or state.rep >= 2
	elif id == "toren": eligible = eligible or (db.place_of(state.location.scene)=="pass" and state.trust>=1)
	elif id == "sylvi": eligible = eligible or state.light>=1 or int(state.story.actions.get("prayer",0))>=1
	if not eligible: return db.raw.companions[id].join
	var cost = int(db.raw.companions[id].cost)
	if state.gold < cost: return "金币不足，需要 %d。" % cost
	state.gold -= cost; _add_member(id, db.raw.companions[id].job, state.members.hero.level)
	var uid = add_gear("class-" + db.raw.companions[id].job + "-weapon")
	state.members[id].equip.weapon = uid
	if state.active.size() < 4:
		state.members[id].slot = _free_slot()
		state.active.append(id)
	recover(id, true)
	log_message(db.actors[id].display_name + "加入队伍。")
	story.affinity(id,20); state.trust+=1
	return last_message

func _free_slot() -> int:
	var occupied = state.active.map(func(id): return int(state.members[id].slot))
	for slot in 4:
		if slot not in occupied: return slot
	return 3

func toggle_member(id: String) -> String:
	if state.battle != null: return "战斗中不能更换队员。"
	if id == "hero": return "主角须留在队伍中。"
	if id in state.active: state.active.erase(id)
	elif state.active.size() >= 4: return "最多出战四人。"
	else: state.members[id].slot = _free_slot(); state.active.append(id)
	changed.emit()
	return ""

func learn(id: String, skill_id: String) -> String:
	if state.battle != null: return "请先结束战斗。"
	var member = state.members[id]; var skill = db.skills[skill_id].data
	if skill_id in member.learned: return "已学习这项技能。"
	if member.job != skill.job or member.level < skill.level: return "职业或等级不满足条件。"
	for prerequisite in skill.get("requires", []):
		if prerequisite not in member.learned: return "需要前置技能。"
	if member.skill_points < skill.cost: return "技能点不足。"
	member.skill_points -= skill.cost; member.learned.append(skill_id)
	if skill.kind == "active":
		if not member.loadouts.has(member.job): member.loadouts[member.job] = []
		if member.loadouts[member.job].size() < 4: member.loadouts[member.job].append(skill_id)
	recover(id)
	changed.emit()
	return ""

func configure_skill(id: String, skill_id: String) -> String:
	if state.battle != null: return "请先结束战斗。"
	var member = state.members[id]
	if skill_id not in member.learned or db.skills[skill_id].job != member.job or db.skills[skill_id].data.kind != "active": return "请先学习当前职业的主动技能。"
	if not member.loadouts.has(member.job): member.loadouts[member.job] = []
	var list = member.loadouts[member.job]
	if skill_id in list: list.erase(skill_id)
	elif list.size() >= 4: return "最多配置四项主动技能。"
	else: list.append(skill_id)
	changed.emit()
	return ""

func respec(id: String) -> String:
	if state.battle != null or state.location.scene != "town": return "请在晨星镇营地重配。"
	var member = state.members[id]
	for skill_id in member.learned.duplicate():
		if db.skills[skill_id].job == member.job:
			member.skill_points += int(db.skills[skill_id].data.cost); member.learned.erase(skill_id)
	member.loadouts[member.job] = []
	recover(id)
	changed.emit()
	return "技能点已退回这位角色。"

func change_job(job: String) -> String:
	if state.battle != null or state.location.scene != "town": return "请在晨星镇营地转职。"
	if job not in state.unlocked_jobs: return "先完成该职业的导师任务。"
	state.members.hero.job = job
	if not state.members.hero.loadouts.has(job): state.members.hero.loadouts[job] = []
	recover("hero")
	changed.emit()
	return "已转职为" + GameContent.JOB_NAMES[job] + "。"

func equip(id: String, uid: String) -> String:
	if state.battle != null: return "战斗中不能更换装备。"
	if not state.gear.has(uid): return "装备不存在。"
	var item = db.raw.items[state.gear[uid].item]
	for member in state.members.values():
		for slot in member.equip:
			if member.equip[slot] == uid and member.id != id: return "这件装备已由" + db.actors[member.id].display_name + "穿戴，请先卸下。"
	var member = state.members[id]
	member.equip[item.slot] = "" if member.equip[item.slot] == uid else uid
	recover(id); changed.emit()
	return ""

func enhance(uid: String) -> String:
	if state.battle != null: return "战斗中不能强化。"
	var gear = state.gear[uid]; var rank = int(gear.rank)
	if rank >= 3: return "已强化至 +3。"
	var cost = [{"ore":2,"shard":0,"gold":30},{"ore":4,"shard":1,"gold":60},{"ore":6,"shard":2,"gold":100}][rank]
	if state.gold < cost.gold or state.materials.ore < cost.ore or state.materials.shard < cost.shard: return "强化材料或金币不足。"
	state.gold -= cost.gold; state.materials.ore -= cost.ore; state.materials.shard -= cost.shard; gear.rank += 1
	changed.emit()
	return "强化完成。"

func craft(id: String) -> String:
	if state.battle != null: return "战斗中不能制作。"
	var recipe = db.raw.recipes[id]
	for prerequisite in recipe.get("requires", []):
		if not state.flags.get("crafted:" + prerequisite, false): return "需要先制作前置配方。"
	if recipe.get("once", false) and state.flags.get("crafted:" + id, false): return "已经完成该制作。"
	for key in recipe.cost:
		if state.materials.get(key, 0) < recipe.cost[key]: return "材料不足。"
	for key in recipe.cost: state.materials[key] -= recipe.cost[key]
	if recipe.has("item"): add_gear(recipe.item)
	else:
		var gain = recipe.get("gain", {})
		if gain.has("potions"): state.items.potion += gain.potions
		if gain.has("mana"): state.items.tonic += gain.mana
		if gain.has("atk"):
			state.members.hero.permanent = state.members.hero.get("permanent", {})
			state.members.hero.permanent.atk = state.members.hero.permanent.get("atk",0) + gain.atk
	state.flags["crafted:" + id] = true
	changed.emit()
	return "制作完成。"

func buy(id: String, shop: String = "hero") -> String:
	if state.battle != null: return "战斗中不能交易。"
	var prices = {"potion":28,"tonic":32,"revive":55,"supply":20,"bow":85,"ward":96}
	if shop=="forge":
		if db.place_of(state.location.scene)!="pass": return "请前往灰炉锻坊。"
		prices={"plate":150,"ember":165,"bracer":92}
	if state.affinity.get("forge-master" if shop=="forge" else "shopkeeper",{}).get("value",0)>=60:
		for key in prices: prices[key]=ceili(prices[key]*.9)
	if not prices.has(id) or state.gold < prices[id]: return "金币不足。"
	state.gold -= prices[id]
	if state.items.has(id): state.items[id] += 1
	elif id == "supply": state.supplies += 1
	else: add_gear(id)
	changed.emit()
	return "购买完成。"

func rest() -> String:
	if state.battle != null: return "请先结束战斗。"
	if state.location.scene not in ["town","room-inn"]: return "请回晨星镇或旅店休息。"
	if state.supplies < 1: return "需要旅行补给 1。"
	state.supplies -= 1
	for id in state.members: recover(id, true)
	advance_time()
	log_message("旅店的灯火温暖，全队生命和法力恢复，倒地成员重新站起。")
	return last_message

func use_item(id: String, target: String) -> String:
	if state.battle != null: return "请通过战斗指令使用道具。"
	if state.items.get(id, 0) <= 0: return "道具不足。"
	var member = state.members[target]; var stats = PartyMemberState.stats(member, state, db)
	if id == "revive" and member.hp > 0: return "目标并未倒地。"
	if id != "revive" and member.hp <= 0: return "请先使用苏生药。"
	state.items[id] -= 1
	if id == "potion": member.hp = mini(stats.max_hp, member.hp + 40)
	elif id == "tonic": member.mp = mini(stats.max_mp, member.mp + 30)
	else: member.hp = maxi(1, ceili(stats.max_hp * 0.3))
	changed.emit()
	return "道具已使用。"

func service(id: String, npc: String) -> String:
	if state.battle != null: return "请先结束战斗。"
	if id not in ["world:study","world:drill","world:royal-record","world:song","world:brew","world:supplies"] or db.place_of(state.location.scene)!="town": return story.service(id)
	var key = "service:" + id
	if id in ["world:study","world:drill","world:song"] and state.flags.get(key,0) == state.day: return "今天已经进行过这项行动。"
	if id == "world:royal-record" and state.flags.get(key,false): return "王室档案已记入旅途笔记。"
	match id:
		"world:study": state.knowledge += 1; grant_xp(["hero"],35)
		"world:drill": grant_xp(state.active,25)
		"world:royal-record": state.knowledge += 1; state.materials.shard += 1
		"world:song":
			for member in state.members.values():
				var stats=PartyMemberState.stats(member,state,db)
				member.mp=mini(stats.max_mp,member.mp+12)
		"world:brew":
			if state.materials.herb < 2: return "需要草药 2。"
			state.materials.herb -= 2; state.items.potion += 1
		"world:supplies":
			if state.gold < 8: return "需要金币 8。"
			state.gold -= 8; state.supplies += 2
		_: return "这项服务不可用。"
	state.flags[key] = state.day
	_activity()
	log_message("在" + db.raw.npcs[npc].name + "的帮助下完成了当地行动。")
	return last_message

func hand_in_herbs() -> String:
	return tasks.turn_in("quest:herbs","pella")

func start_battle(id: String, seed_value: int = -1) -> String:
	if state.battle != null: return "已有战斗正在进行。"
	if not db.encounters.has(id): return "遭遇不存在。"
	if state.active.all(func(member): return state.members[member].hp <= 0): return "队伍需要先休整。"
	if not state.training:
		var route = db.encounters[id].route; var index = int(id.right(1))
		if db.encounters[id].story.is_empty():
			if state.location.scene != route: return "请先前往对应路线。"
			if index > 0 and not state.encounters.get(route + "-" + str(index - 1), false): return "先完成前一场遭遇。"
		else:
			if db.place_of(state.location.scene)!=db.place_of(route): return "请先前往对应地区。"
			if db.encounters[id].story.has("scene") and state.location.scene!=route: return "请先前往对应路线。"
	if seed_value < 0: seed_value = int(Time.get_unix_time_from_system()) + int(state.seed_counter)
	state.seed_counter += 1
	engine.start(state, id, seed_value, state.training)
	state.battle = engine.battle
	if not state.training and db.encounters[id].story.has("roam"):
		for enemy in state.battle.units:
			if enemy.team=="enemy": enemy.hp+=int(state.danger)*7; enemy.max_hp+=int(state.danger)*7; enemy.atk+=int(state.danger)*2
	changed.emit()
	return ""

func combat(command: Dictionary) -> Dictionary:
	if state.battle == null: return {"error":"没有进行中的战斗。"}
	var result = engine.submit(command)
	if result.error != "": return result
	for actor in engine.battle.units:
		if actor.team != "ally": continue
		var member = state.members[actor.id]
		member.hp = actor.hp; member.mp = actor.mp; member.slot = actor.slot; member.auto = actor.auto
		member.tp=int(actor.get("tp",0)); member.ultimate_auto=actor.get("ultimate_auto",false)
	state.items = engine.battle.items.duplicate(true)
	state.formation=engine.battle.formation; state.combat_rules_version=2
	if engine.battle.result != "": _finish_battle()
	changed.emit()
	return result

func _finish_battle():
	var battle = engine.battle
	state.battle = null
	if state.training: log_message("训练结束：" + {"win":"胜利", "defeat":"战败", "flee":"撤离"}.get(battle.result, "结束") + "。剧情进度与物资未受影响。"); return
	if battle.result == "win":
		var definition = db.encounters[battle.encounter]
		var first_clear = not state.encounters.get(battle.encounter, false)
		state.encounters[battle.encounter] = true
		var gold_reward=int(definition.gold)
		if definition.story.has("gold_range"):
			var range_value=definition.story.gold_range
			gold_reward=int(range_value[0])+int(story.roll()*(int(range_value[1])-int(range_value[0])+1))
		state.gold += gold_reward
		grant_xp(battle.participants, definition.xp)
		if first_clear:
			state.materials.herb += 1; state.materials.ore += 1
			if battle.encounter.ends_with("-2"): state.materials.shard += 2
		_activity()
		_check_chapter()
		story.battle_won(definition,first_clear,battle)
		if not definition.enemies.any(func(e): return e.get("elite",false) or e.get("boss",false)): tasks.event("battle",definition.route,"",battle.get("instance_id",""))
		log_message("战斗胜利：每名参战成员获得 %d 经验，金币 +%d。" % [definition.xp, gold_reward])
	elif battle.result == "defeat":
		state.gold = maxi(0, int(state.gold) - 20)
		state.location = {"scene":"town", "x":30.0, "y":27.0}
		for id in state.active:
			var member = state.members[id]
			var stats = PartyMemberState.stats(member, state, db)
			member.hp = maxi(1, int(stats.max_hp * 0.55)); member.mp = int(stats.max_mp * 0.5)
		advance_time(); log_message("巡路人把全队带回晨星镇，损失 20 金币。")
	else: advance_time(); log_message("队伍从雾中撤回。")

func grant_xp(ids: Array, amount: int):
	for id in ids:
		if not state.members.has(id): continue
		var levels = PartyMemberState.grant_xp(state.members[id], amount)
		if levels > 0: recover(id, true)

func _quest_progress(id: String, amount: int):
	if not state.quests.has(id) or state.quests[id].done: return
	state.quests[id].progress = mini(db.raw.quests[id].goal, state.quests[id].progress + amount)

func _check_chapter():
	if state.flags.get("drain_clue", false) and state.encounters.get("town-trial-2", false) and not state.chapter_complete:
		state.chapter_complete = true
		state.quests.stars.progress = 1
		state.gold += 100; grant_xp(state.active, 120)
		log_message("序章「归路与星钟」完成。回到米拉身边接受星图委托，前往低语森林继续调查。")

func enter_training(job: String, team: Array, level: int = 6) -> String:
	if state.battle != null: return "请先结束战斗。"
	if state.training: return "已经处于训练模式。"
	training_snapshot = state.duplicate(true)
	state = state.duplicate(true)
	state.training = true; state.unlocked_jobs = GameContent.JOB_ORDER.duplicate(); state.active = ["hero"]; state.members = {}; state.gear = {}; state.next_uid = 1
	_add_member("hero", job, level)
	for id in team.slice(0, 3):
		_add_member(id, db.actors[id].job, level); state.members[id].slot = state.active.size(); state.active.append(id)
	for id in state.members:
		var member = state.members[id]
		member.learned = db.job_skills(member.job)
		member.loadouts[member.job] = member.learned.filter(func(skill): return db.skills[skill].data.kind == "active").slice(0, 4)
		member.skill_points = 20; member.auto = false
		member.tp=100
		member.equip.weapon = add_gear("class-" + member.job + "-weapon")
		member.equip.armor = add_gear("wayfarerVest")
		state.affinity[id] = {"value":100,"chat_day":0,"gift_day":0}
		recover(id, true)
	state.gold = 999; state.items = {"potion":20,"tonic":20,"revive":10}; state.materials = {"herb":30,"ore":30,"shard":30}; state.location = {"scene":"town-trial", "x":8.5, "y":8.5}
	changed.emit()
	return "训练已开启；离开时完整恢复剧情进度。"

func reset_training() -> String:
	if not state.training or state.battle != null: return "请在训练战斗结束后整理。"
	for id in state.members: recover(id,true); state.members[id].tp=100
	state.items = {"potion":20,"tonic":20,"revive":10}
	changed.emit()
	return "训练队伍与物资已恢复。"

func exit_training():
	if training_snapshot.is_empty(): return
	progression.trial_actor=""
	state = training_snapshot.duplicate(true); training_snapshot = {}; engine.battle = {}; changed.emit()

func load_state(saved: Dictionary) -> String:
	var error = validate_save(saved)
	if error != "": return error
	presentation_revision+=1
	state = saved.duplicate(true); state.combat_rules_version=2; training_snapshot = {}
	# JSON numbers are floats. Restore discrete counters before slot membership checks.
	for key in ["gold","day","phase","next_uid","supplies","seed_counter","rep","knowledge","light","trust"]: state[key]=int(state[key])
	for member in state.members.values():
		for key in ["level","xp","skill_points","hp","mp","slot"]: member[key]=int(member[key])
	for gear in state.gear.values(): gear.rank=int(gear.rank)
	story.initialize()
	progression.initialize()
	tasks.initialize()
	if state.battle != null: engine.restore(state.battle); state.battle = engine.battle
	else: engine.battle = {}
	changed.emit()
	return ""

func validate_save(saved: Variant) -> String:
	if not saved is Dictionary or saved.get("format", "") != FORMAT or saved.get("version", 0) != 1: return "请选择原生电脑版 v1 存档；网页旧档不兼容，当前进度已保留。"
	if not saved.has("battle"): return "存档缺少战斗记录。"
	if not BattleRules._integer(saved.get("combat_rules_version",1),1,2): return "战斗规则版本无效。"
	var task_error=tasks.validate(saved)
	if task_error!="": return task_error
	for key in ["members","gear","items","materials","affinity","personal","quests","flags","scene_progress","encounters","dialogue","location","settings"]:
		if not saved.get(key) is Dictionary: return "存档结构不完整：" + key
	if not saved.get("active") is Array or saved.active.is_empty() or saved.active.size() > 4 or "hero" not in saved.active or saved.members.size() > 7: return "队伍数据无效。"
	for id in saved.active:
		if saved.active.count(id) > 1: return "队员不能重复出战。"
	if not saved.get("unlocked_jobs") is Array or not saved.get("log") is Array: return "成长记录无效。"
	if saved.get("training", true): return "训练状态不能作为剧情存档导入。"
	if not saved.get("chapter_complete") is bool or not saved.settings.get("reduce_motion") is bool or not _number(saved.settings.get("master_volume"),0,1): return "设置数据无效。"
	for key in ["gold", "day", "phase", "next_uid", "supplies", "seed_counter", "rep", "knowledge", "light", "trust"]:
		if not _number(saved.get(key), 0, 1000000000): return "存档数值无效：" + key
	if saved.get("formation", "") not in db.raw.formations: return "阵型数据无效。"
	if saved.phase > 3 or saved.day < 1 or saved.next_uid < 1: return "日期或装备序号无效。"
	for job in saved.unlocked_jobs:
		if job not in GameContent.JOB_ORDER: return "含有未知职业。"
	for id in db.chapter_npcs + db.raw.companions.keys() + saved.affinity.keys():
		if not db.raw.npcs.has(id) and not db.raw.companions.has(id): return "含有未知人物。"
		var relation = saved.affinity.get(id)
		if not relation is Dictionary or not _number(relation.get("value"),0,100) or not _number(relation.get("chat_day"),0,1000000000) or not _number(relation.get("gift_day"),0,1000000000): return "关系数据无效。"
	for id in saved.personal:
		var quest = saved.personal[id]
		if not db.raw.personal.has(id) or not quest is Dictionary or not _number(quest.get("stage"),0,2) or not quest.get("done") is bool: return "个人委托无效。"
		if quest.stage == 2 and not quest.done and not saved.has("task_state"): return "个人委托阶段无效。"
	for id in ["first","stars"]:
		if not saved.quests.has(id): return "缺少主线记录。"
	for id in saved.quests:
		var quest = saved.quests[id]
		if not db.raw.quests.has(id) or not quest is Dictionary or not _number(quest.get("progress"),0,db.raw.quests[id].goal) or not quest.get("done") is bool: return "任务记录无效。"
	var used_gear = []; var used_slots = []
	for id in saved.members:
		var member = saved.members[id]
		if not db.actors.has(id) or not member is Dictionary or member.get("id") != id or member.get("job") not in GameContent.JOB_ORDER: return "角色数据无效。"
		if not _number(member.get("tp",0),0,100) or float(member.get("tp",0))!=floor(float(member.get("tp",0))) or not member.get("ultimate_auto",false) is bool: return "角色 TP 或大招设置无效。"
		if id != "hero" and member.job != db.actors[id].job: return "同伴职业不能改变。"
		for key in ["level","xp","skill_points","hp","mp","slot"]:
			if not _number(member.get(key), 0, 1000000): return "角色成长数值无效。"
		if member.level < 1 or member.level > 99 or member.slot > 3 or member.slot!=floor(float(member.slot)) or not member.get("learned") is Array or not member.get("loadouts") is Dictionary or not member.get("equip") is Dictionary: return "角色配置无效。"
		if member.get("tactic") not in ["damage","protect","reserve"] or member.get("focus") not in ["marked","charging","lowest"] or not _number(member.get("heal_threshold"),0,1) or not _number(member.get("mana_reserve"),0,1): return "战术配置无效。"
		if not member.get("auto") is bool: return "控制方式无效。"
		if not member.get("permanent",{}) is Dictionary: return "永久成长无效。"
		for key in member.get("permanent",{}):
			if key not in ["atk","max_hp"] or not _number(member.permanent[key],0,100000): return "永久成长无效。"
		for skill in member.learned:
			if not db.skills.has(skill): return "含有未知技能。"
		for job in member.loadouts:
			if job not in GameContent.JOB_ORDER or not member.loadouts[job] is Array or member.loadouts[job].size() > 4: return "技能配置无效。"
			for skill in member.loadouts[job]:
				if skill not in member.learned or db.skills[skill].job != job or db.skills[skill].data.kind != "active": return "技能配置与角色不匹配。"
		for slot in ["weapon","armor","charm"]:
			var uid = member.equip.get(slot, "")
			if uid == "": continue
			if uid in used_gear or not saved.gear.has(uid): return "装备出现重复归属或缺失。"
			used_gear.append(uid)
		if id in saved.active:
			if member.slot in used_slots: return "出战站位重复。"
			used_slots.append(member.slot)
	for id in saved.active:
		if not saved.members.has(id): return "队员不存在。"
	for uid in saved.gear:
		var gear = saved.gear[uid]
		if not gear is Dictionary or not db.raw.items.has(gear.get("item", "")) or not _number(gear.get("rank"),0,3): return "装备数据无效。"
	for member in saved.members.values():
		for slot in ["weapon","armor","charm"]:
			var uid = member.equip.get(slot, "")
			if uid != "" and db.raw.items[saved.gear[uid].item].get("slot", "") != slot: return "装备槽位不匹配。"
		var stats = PartyMemberState.stats(member, saved, db)
		if member.hp > stats.max_hp or member.mp > stats.max_mp: return "角色生命或法力超出上限。"
	for key in ["potion","tonic","revive"]:
		if not _number(saved.items.get(key),0,100000): return "道具数量无效。"
	for key in ["herb","ore","shard"]:
		if not _number(saved.materials.get(key),0,100000): return "材料数量无效。"
	var location = saved.location
	var scene_id=str(location.get("scene",""))
	if scene_id!="town" and not db.raw.scenes.has(scene_id) and not db.regions.has(scene_id): return "场景不存在。"
	var columns=db.regions[scene_id].columns if db.regions.has(scene_id) else 64
	var rows=db.regions[scene_id].rows if db.regions.has(scene_id) else 48
	if not _number(location.get("x"),0,columns) or not _number(location.get("y"),0,rows): return "位置数据无效。"
	if saved.get("battle") != null:
		var battle = saved.battle
		if not battle is Dictionary or not battle.get("units") is Array or battle.units.size() > 10 or not battle.get("queue") is Array or not battle.get("items") is Dictionary: return "战斗结构无效。"
		if not _number(battle.get("event_seq",0),0,1000000000) or float(battle.get("event_seq",0))!=floor(float(battle.get("event_seq",0))) or not battle.get("instance_id","") is String: return "战斗事件记录无效。"
		if not db.encounters.has(battle.get("encounter", "")) or not str(battle.get("rng_state", "")).is_valid_int() or not str(battle.get("seed", "")).is_valid_int(): return "战斗随机状态无效。"
		if not battle.get("log") is Array or not battle.get("participants") is Array or battle.participants != saved.active or battle.get("formation", "") not in db.raw.formations or not _number(battle.get("synergy"),0,100): return "战斗队伍记录无效。"
		for key in ["potion","tonic","revive"]:
			if not _number(battle.items.get(key),0,100000): return "战斗道具无效。"
		if battle.get("result", "invalid") != "" or battle.get("training", true): return "战斗状态无效。"
		if not _number(battle.get("cursor"),0,battle.queue.size()-1) or not _number(battle.get("token"),1,1000000) or not _number(battle.get("round"),1,1000000): return "战斗回合无效。"
		var ids = []; var ally_ids = []; var enemy_count = 0
		for actor in battle.units:
			if not actor is Dictionary or not actor.get("id") is String or actor.id == "" or actor.id in ids or not actor.get("effects") is Array or not actor.get("cooldowns") is Dictionary: return "战斗单位无效。"
			ids.append(actor.id)
			for key in ["max_hp","hp","max_mp","mp","atk","def","speed","posture","max_posture","slot","immune_until","follow_round"]:
				if not _number(actor.get(key),0,1000000): return "战斗属性无效。"
			if actor.hp > actor.max_hp or actor.mp > actor.max_mp or actor.get("team") not in ["ally","enemy"]: return "战斗生命数据无效。"
			if not BattleRules._integer(actor.get("phase"),1,2): return "战斗阶段无效。"
			if actor.team == "ally" and actor.id not in saved.active: return "战斗队员不匹配。"
			if not actor.get("name") is String or not actor.get("art") is String or not actor.get("skills") is Array or not actor.get("weakness") is Array or not _number(actor.get("crit"),0,1) or not _number(actor.get("drain"),0,1): return "战斗单位内容无效。"
			for skill in actor.skills:
				if not db.skills.has(skill): return "战斗含未知技能。"
			for element in actor.weakness:
				if element not in GameContent.ELEMENT_NAMES: return "战斗弱点无效。"
			for cd in actor.cooldowns.values():
				if not _number(cd,0,50): return "技能冷却无效。"
			if actor.team == "ally":
				if not _number(actor.get("tp",0),0,100) or float(actor.get("tp",0))!=floor(float(actor.get("tp",0))) or not actor.get("ultimate_auto",false) is bool or not actor.get("awakened",false) is bool or not _number(actor.get("tp_hit_gain",0),0,20) or not _number(actor.get("tp_hit_round",0),0,1000000): return "战斗 TP 记录无效。"
				ally_ids.append(actor.id)
				if actor.get("job", "") != saved.members[actor.id].job or not actor.get("auto") is bool or not _number(actor.get("bond"),0,100) or actor.get("tactic") not in ["damage","protect","reserve"] or actor.get("focus") not in ["marked","charging","lowest"] or not _number(actor.get("heal_threshold"),0,1) or not _number(actor.get("mana_reserve"),0,1): return "战斗角色配置无效。"
			else:
				enemy_count += 1
				if not actor.get("charging") is bool or not actor.get("summoned") is bool or not actor.get("ranged") is bool or not actor.get("intent") is Dictionary: return "敌方状态字段无效。"
				var intent = actor.intent
				if intent.get("kind") not in ["attack","charge","heavy","heal","guard","poison","summon","sweep"] or not intent.get("target") is String or not intent.get("label") is String or not _number(intent.get("power"),0,10): return "敌方意图无效。"
			for fx in actor.effects:
				if not fx is Dictionary or fx.get("type", "") not in BattleEngine.EFFECT_NAMES or not _number(fx.get("turns"),1,20) or not _number(fx.get("potency"),0,1000000): return "战斗状态效果无效。"
				if not _number(fx.get("created"),0,1000000) or not fx.get("source") is String or not fx.get("cover") is String: return "战斗状态来源无效。"
		if enemy_count > 6 or ally_ids.size() != saved.active.size(): return "战斗单位数量无效。"
		for id in battle.queue:
			if id not in ids: return "行动队列含有不存在的单位。"
	if saved.battle!=null:
		var rules_error=BattleRules.validate(saved.battle)
		if rules_error!="": return rules_error
	var progression_error=progression.validate(saved)
	return progression_error if progression_error!="" else story.validate(saved)

func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum
