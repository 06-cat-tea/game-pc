extends SceneTree

var db: GameContent
var checks=0
var failures=[]

func _initialize(): call_deferred("run")

func check(condition: bool,text: String):
	checks+=1
	if not condition: failures.append(text); push_error(text)

func fight(game: GameSession,limit: int = 600) -> String:
	var count=0
	while game.state.battle!=null and count<limit:
		var result=game.combat(game.engine.ai_command())
		if result.error!="": check(false,result.error); break
		count+=1
	check(count<limit,"战斗在有限行动内结束")
	return game.engine.battle.result

func run():
	db=GameContent.new()
	var acceptance=load("res://tests/story_acceptance.gd").new()
	await acceptance.run(self,check); check(acceptance.completed,"剧情验收执行到末尾")
	print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
