class_name PartyMemberState
extends RefCounted

const BASES = {
	"ranger": [104, 65, 13, 4, 15], "arcanist": [90, 85, 15, 3, 12],
	"warden": [132, 55, 12, 7, 8], "assassin": [94, 60, 14, 3, 19],
	"priest": [100, 90, 11, 4, 10], "alchemist": [106, 80, 12, 4, 13]
}

static func create(id: String, job: String, level: int = 1) -> Dictionary:
	return {"id": id, "job": job, "level": level, "xp": 0, "skill_points": 1 + (level - 1) * 2, "learned": [], "loadouts": {}, "equip": {"weapon": "", "armor": "", "charm": ""}, "hp": -1, "mp": -1, "tp":0,"ultimate_auto":false,"auto": false, "tactic": "protect", "heal_threshold": 0.4, "mana_reserve": 0.25, "focus": "marked", "slot": 0}

static func stats(member: Dictionary, state: Dictionary, db: GameContent) -> Dictionary:
	var base = BASES.get(member.job, BASES.ranger)
	var level = int(member.level) - 1
	var result = {"max_hp": int(base[0]) + level * 14, "max_mp": int(base[1]) + level * 6, "atk": int(base[2]) + level * 3, "def": int(base[3]) + level, "speed": int(base[4]), "crit": 0.06, "drain": 0.0, "camp_bonus":0.0, "herb_bonus":0, "support_bonus":0.0}
	# Original companion bonuses now belong exclusively to that companion.
	for key in db.raw.companions.get(member.id, {}).get("bonus", {}):
		var destination = {"hp":"max_hp", "mana":"max_mp"}.get(key, key)
		if result.has(destination): result[destination] += db.raw.companions[member.id].bonus[key]
	for key in member.get("permanent", {}):
		if result.has(key): result[key] += member.permanent[key]
	for slot in member.equip:
		var uid = member.equip[slot]
		if not state.get("gear", {}).has(uid): continue
		var gear = state.gear[uid]
		var item = db.raw.items.get(gear.item, {})
		for key in item.get("stats", {}):
			var destination = {"hp": "max_hp", "mana": "max_mp"}.get(key, key)
			if result.has(destination): result[destination] += item.stats[key]
		var rank = int(gear.get("rank", 0))
		if slot == "weapon": result.atk += rank * 2
		elif slot == "armor":
			result.def += rank
			result.max_hp += rank * 4
		else: result.max_mp += rank * 4
	for id in member.learned:
		if not db.skills.has(id): continue
		var skill = db.skills[id].data
		if skill.job != member.job or skill.kind != "passive": continue
		var effect = skill.effect
		var value = float(skill.get("value", 0))
		if effect in ["atk", "def", "crit"]: result[effect] += value
		elif effect == "hp": result.max_hp += value
		elif effect == "mana": result.max_mp += value if value else 20
		elif effect == "guard":
			result.max_hp += 18
			result.def += 2
		elif effect == "windrunner":
			result.max_hp += 8
			result.crit += 0.04
		elif effect == "fateThread":
			result.atk += 2
			result.max_mp += 8
		elif effect == "guardian":
			result.def += 3
			result.max_hp += 10
		elif effect == "sharedVow": result.max_hp += 12; result.support_bonus = 0.15
		elif effect == "forage": result.camp_bonus = 0.15
		elif effect == "herbBonus": result.herb_bonus = 1
	for key in ["max_hp", "max_mp", "atk", "def", "speed"]: result[key] = int(result[key])
	result.crit = clampf(result.crit, 0.0, 0.8)
	return result

static func next_xp(level: int) -> int:
	return 65 + level * 35

static func grant_xp(member: Dictionary, amount: int) -> int:
	member.xp += amount
	var levels = 0
	while member.level < 99 and member.xp >= next_xp(member.level):
		member.xp -= next_xp(member.level)
		member.level += 1
		member.skill_points += 2
		levels += 1
	return levels
