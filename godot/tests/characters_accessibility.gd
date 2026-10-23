extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game); await process_frame; game.capture_mode=true; game.new_game("warden")
	var results=[]
	for scene in GameContent.OUTDOORS:
		game.navigate(scene); await process_frame
		var from=game.world._walkable_cell(Vector2i(game.world.player.round()))
		for target in game.world.targets:
			if target.kind!="npc": continue
			var to=game.world._walkable_cell(Vector2i(target.point.round())); var path=game.world.grid.get_id_path(from,to)
			var passed=not path.is_empty() or game.world.player.distance_to(target.point)<2.6
			results.append({"scene":scene,"npc":target.id,"passed":passed})
	var report={"passed":results.all(func(r): return r.passed),"checks":results.size(),"results":results}
	var file=FileAccess.open(OS.get_environment("ASHEN_ACCESS_REPORT"),FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
	print(JSON.stringify({"passed":report.passed,"checks":results.size(),"failures":results.filter(func(r): return not r.passed)}))
	game.queue_free(); await process_frame; quit(0 if report.passed else 1)
