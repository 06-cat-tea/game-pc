class_name SkillDefinition
extends Resource

var id = ""
var data = {}
var display_name = ""
var effect = "damage"
var job = ""
var mp = 0
var cooldown = 0
var power = 1.0
var element = "physical"
var toughness = 20
var shield_rule = {"turns":3,"stacking":false}
var ranged = false
var target_mode = "enemy"

static func from_data(key: String, source: Dictionary) -> SkillDefinition:
	var skill = SkillDefinition.new()
	skill.id = key
	skill.data = source.duplicate(true)
	skill.display_name = source.get("name", key)
	skill.effect = source.get("effect", "damage")
	skill.job = source.get("job", "ranger")
	skill.mp = int(source.get("mp", 0))
	skill.cooldown = int(source.get("cooldown", 3 if skill.effect == "seal" else 2))
	skill.power = float(source.get("power", 1.5))
	skill.ranged = skill.job in ["ranger", "arcanist", "priest", "alchemist"]
	skill.element = {"arcanist": "astral", "priest": "holy", "alchemist": "fire"}.get(skill.job, "physical")
	if skill.effect in ["burnAll"] or key == "starfall": skill.element = "fire"
	if skill.effect in ["poisonAll", "poison"]: skill.element = "poison"
	if skill.effect in ["heal", "regen", "aegis"]:
		skill.target_mode = "all_allies" if int(source.get("tier", 1)) == 5 else "ally"
	elif skill.effect in ["area", "burnAll", "poisonAll", "markAll", "silenceAll"]:
		skill.target_mode = "all_enemies"
	skill.element=source.get("element",skill.element)
	skill.toughness=int(source.get("toughness",10 if skill.target_mode=="all_enemies" else 20))
	skill.shield_rule=source.get("shield_rule",{"turns":3,"stacking":false}).duplicate(true)
	return skill
