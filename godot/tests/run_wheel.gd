extends SceneTree

var failures=[]
var checks=0

func _initialize(): call_deferred("run")

func verify(passed: bool, description: String):
	checks+=1
	if not passed: failures.append(description); push_error(description)

func run():
	await load("res://tests/quick_wheel_acceptance.gd").new().run(self,verify)
	print("QUICK WHEEL: "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
