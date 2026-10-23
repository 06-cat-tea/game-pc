class_name EncounterDefinition
extends Resource

var id = ""
var title = ""
var route = ""
var enemies = []
var xp = 0
var gold = 0
var lesson = ""
var story = {}

static func from_data(key: String, source: Dictionary) -> EncounterDefinition:
	var encounter = EncounterDefinition.new()
	encounter.id = key
	encounter.title = source.get("title", key)
	encounter.route = source.get("route", "town-wall")
	encounter.enemies = source.get("enemies", []).duplicate(true)
	encounter.xp = int(source.get("xp", 35))
	encounter.gold = int(source.get("gold", 18))
	encounter.lesson = source.get("lesson", "观察敌方意图，选择行动。")
	return encounter
