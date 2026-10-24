class_name GameContent
extends RefCounted

var raw = {}
var actors = {}
var skills = {}
var encounters = {}
var regions = {}
var narrative = {}
var chapter_scenes = []
var chapter_npcs = []
var movement = {}
var progression = {}
var quest_catalog = {}
var world_interactions = {}
var town_design = {}
const OUTDOORS = ["town","wood","pass","fen","coast","city"]
const JOB_ORDER = ["ranger", "arcanist", "warden", "assassin", "priest", "alchemist"]
const ROUTES = ["town-wall", "town-drain", "town-trial"]
const JOB_NAMES = {"ranger": "游侠", "arcanist": "星术师", "warden": "守誓者", "assassin": "刺客", "priest": "牧师", "alchemist": "炼金师"}
const ELEMENT_NAMES = {"physical": "物理", "fire": "火焰", "astral": "星辉", "holy": "圣光", "poison": "毒素"}

func _init():
	raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	movement=JSON.parse_string(FileAccess.get_file_as_string("res://data/movement.json"))
	progression=JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	progression.ultimates.toren.desc+=" 同来源可叠加，上限为目标最大生命的60%；其他护盾独立计时、同时受损，保护取最高值。"
	quest_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/quest-catalog.json"))
	world_interactions=JSON.parse_string(FileAccess.get_file_as_string("res://data/world-interactions.json"))
	chapter_scenes=raw.scenes.keys(); chapter_npcs=raw.npcs.keys()
	narrative=JSON.parse_string(FileAccess.get_file_as_string("res://data/narrative.json"))
	for id in narrative.scenes:
		if not raw.scenes.has(id): raw.scenes[id]=narrative.scenes[id]
		else:
			raw.scenes[id].title=narrative.scenes[id].title
			raw.scenes[id].description=narrative.scenes[id].get("description","")
			for p in raw.scenes[id].props:
				for source in narrative.scenes[id].props:
					if p.id==source.id: p.detail=source.detail
	for b in raw.buildings:
		for source in narrative.buildings:
			if b.id==source.id: b.name=source.name; b.description=source.description
	for id in narrative.npcs: raw.npcs[id]=narrative.npcs[id]
	raw.dialogues=narrative.dialogues
	for id in narrative.portraits:
		if not raw.art.portraits.has(id): raw.art.portraits[id]={"neutral":narrative.portraits[id],"avatar":narrative.portraits[id]}
	for id in narrative.items:
		if raw.items.has(id):
			raw.items[id].text=narrative.items[id].text
			raw.items[id].origin=narrative.items[id].get("origin","")
	for id in world_interactions.children:
		var child=world_interactions.children[id]
		raw.npcs[id]=child.duplicate(true); raw.dialogues[id]={}
		raw.art.portraits[id]={"neutral":child.portrait,"avatar":child.portrait}; raw.art.actors[id]=child.actor
		narrative.greetings[id]={}
	# Legacy building route tables are retired; all consumers use the entrance catalog.
	raw.entrances={}; narrative.entrances={}
	regions=RegionCatalog.all()
	for id in regions.city.get("npcPositions",{}):
		if raw.npcs.has(id): raw.npcs[id].position={"x":regions.city.npcPositions[id][0],"y":regions.city.npcPositions[id][1]}
	for id in raw.formations:
		raw.formations[id].desc=BattleRules.config().formations[id].desc
	for id in raw.skills: skills[id] = SkillDefinition.from_data(id, raw.skills[id])
	actors.hero = ActorDefinition.from_data("hero", {"name": "旅人", "job": "ranger", "role": "归路的见证者"})
	for id in raw.companions: actors[id] = ActorDefinition.from_data(id, raw.companions[id])
	var native = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounters.json"))
	for id in native: encounters[id] = EncounterDefinition.from_data(id, native[id])
	StoryEncounters.install(self)
	for id in progression.rooms: raw.scenes[id]=progression.rooms[id].duplicate(true)
	for site in progression.buildings.values():
		for detail in site.details: raw.scenes[site.scene].props.append(detail.duplicate(true))
	for id in progression.ultimates:
		var d=progression.ultimates[id]
		var enemy={"name":d.title+" · 回响","art":d.art,"hp":320,"atk":18,"def":5,"speed":10,"slot":0,"elite":true,"weakness":[d.element],"role":"caster" if id in ["mira","alchemist"] else "guard" if id=="toren" else "fighter"}
		encounters["awakening-"+id]=EncounterDefinition.from_data("awakening-"+id,{"title":d.title+" · 觉醒试炼","route":"town-trial","enemies":[enemy],"xp":0,"gold":0})

	_install_town_design()

func _install_town_design():
	town_design=JSON.parse_string(FileAccess.get_file_as_string("res://data/town-design.json"))
	for geometry in town_design.buildings:
		for building in raw.buildings:
			if building.id!=geometry.id: continue
			for key in ["x","y","w","d","entry"]: building[key]=geometry[key]
			var art=raw.art.buildings[building.id]
			art.path=geometry.art; art.anchor=geometry.anchor
			art.display_width=310.0 if building.id=="clocktower" else float(building.w+building.d)*58.0
	for id in town_design.npcs:
		if raw.npcs.has(id): raw.npcs[id].position={"x":town_design.npcs[id][0],"y":town_design.npcs[id][1]}
	for group in ["animals","resources","objects","entrances"]:
		for item in world_interactions[group]:
			if town_design.points.has(item.id): item.point=town_design.points[item.id].duplicate()
	raw.terrain=town_design.terrain
	raw.layout.water=[]

func building(id: String) -> Dictionary:
	for b in narrative.buildings:
		if b.id==id: return b
	return {}

func place_of(scene: String) -> String:
	return scene if is_outdoor(scene) else str(raw.scenes.get(scene,{}).get("place","town"))

func scene_npcs(scene: String) -> Array:
	return narrative.indoor.get(scene,[])

func route_ids(place: String) -> Array:
	var result=[]
	for r in narrative.routes.get(place,[]): result.append(r[0])
	return result

func art(kind: String, id: String, mood: String = "neutral") -> String:
	var entry = raw.art.get(kind, {}).get(id, "")
	if kind=="portraits":
		if entry is Dictionary:
			for key in [mood,"neutral","fallback"]:
				var path=str(entry.get(key,""))
				if path!="" and ResourceLoader.exists(path): return path
		elif str(entry)!="" and ResourceLoader.exists(str(entry)): return str(entry)
		var npc=raw.npcs.get(id,{})
		return str(raw.art.actors.get(id,raw.art.actors.get(npc.get("type","villager"),"")))
	if entry is Dictionary: return entry.get(mood, entry.get("path", entry.get("neutral", "")))
	return str(entry)

func is_outdoor(id: String) -> bool: return id in OUTDOORS

func location_title(id: String) -> String:
	if id=="town": return "晨星镇"
	return str(regions[id].title) if regions.has(id) else str(raw.scenes.get(id,{}).get("title",id))

func job_skills(job: String) -> Array:
	var result = []
	for id in skills:
		if skills[id].job == job: result.append(id)
	result.sort_custom(func(a, b):
		var x = raw.skills[a]
		var y = raw.skills[b]
		return int(x.tier) < int(y.tier) if x.branch == y.branch else str(x.branch) < str(y.branch))
	return result

func describe_skill(id: String) -> String:
	var skill = skills[id]
	var d = skill.data
	if d.kind == "passive": return str(d.desc)
	var target = {"enemy": "单个敌人", "all_enemies": "全体敌人", "ally": "单个队友", "all_allies": "全体队友"}[skill.target_mode]
	var details = str(d.desc)
	if skill.effect in ["heal", "aegis", "regen"]: details = "恢复目标生命并净化持续伤害" + ("，附加护盾" if skill.effect == "aegis" else "，附加再生" if skill.effect == "regen" else "")
	return "%s\n目标：%s · %s\n%d 法力 · 冷却 %d 次行动" % [details, target, ELEMENT_NAMES[skill.element], skill.mp, skill.cooldown]
