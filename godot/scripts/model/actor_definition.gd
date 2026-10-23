class_name ActorDefinition
extends Resource

var id = ""
var display_name = ""
var job = "ranger"
var role = ""
var portrait = ""
var data = {}

static func from_data(key: String, source: Dictionary) -> ActorDefinition:
	var definition = ActorDefinition.new()
	definition.id = key
	definition.display_name = source.get("name", key)
	definition.job = source.get("job", "ranger")
	definition.role = source.get("role", "旅人")
	definition.data = source.duplicate(true)
	return definition
