extends SceneTree

var failures=[]
var checks=0
func _initialize(): call_deferred("run")
func verify(passed: bool, label: String):
	checks+=1
	if not passed: failures.append(label)
func run():
	var source=OS.get_environment("ASHEN_DIALOGUE_TEST_SOURCE")
	var tests=load(source if source!="" else "res://tests/dialogue_input_acceptance.gd").new()
	await tests.run(self,verify)
	var report={"passed":failures.is_empty() and tests.completed,"checks":checks,"failures":failures,"timings":tests.timings}
	var path=OS.get_environment("ASHEN_DIALOGUE_REPORT")
	if path!="":
		var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print("DIALOGUE INPUT: "+JSON.stringify(report))
	quit(0 if report.passed else 1)
