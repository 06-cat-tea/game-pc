extends SceneTree

var db: GameContent
var checks=0
var failures=[]
var results=[]

func _initialize(): call_deferred("run")

func check(condition: bool, description: String):
	checks+=1
	if not condition: failures.append(description); push_error(description)

func run():
	db=GameContent.new()
	await load(OS.get_environment("ASHEN_QUEST_FLOW_SOURCE")).new().run(self,check)
	await load(OS.get_environment("ASHEN_QUEST_INPUT_SOURCE")).new().run(self,check)
	var file=FileAccess.open(OS.get_environment("ASHEN_QUEST_REPORT"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"results":results})); file.close()
	quit(0 if failures.is_empty() else 1)
