extends SceneTree

func _initialize():
	call_deferred("run")

func fail(message: String):
	push_error(message)
	quit(1)

func run():
	var args=OS.get_cmdline_user_args()
	var report_path=args[0]
	var operation=args[1]
	var expected="AshenFrontierDesktopGodotDemo"
	if OS.get_user_data_dir().get_file()!=expected:
		fail("试玩存档目录必须独立"); return
	var content=load("res://scripts/content_db.gd").new()
	var game=load("res://scripts/game_session.gd").new(content)
	var store=load("res://scripts/save_store.gd").new(game)
	if operation=="write":
		game.new_game("warden")
		game.state.gold=731017
		if store.save(1)!="":
			fail("写入试玩档"); return
	if store.load_slot(1)!="" or game.state.gold!=731017:
		fail("重装及卸载后存档内容一致"); return
	var snapshot=game.state.duplicate(true)
	game.enter_training("warden",["mira","toren","eira"],6)
	if store.save(0)=="":
		fail("训练不得写入剧情档"); return
	game.exit_training()
	if game.state!=snapshot:
		fail("训练退出完整恢复进度"); return
	var report={"passed":true,"user_data_dir":OS.get_user_data_dir(),"save":ProjectSettings.globalize_path(store.path_for(1)),"gold":snapshot.gold,"format":snapshot.format,"operation":operation,"editor_binary":OS.has_feature("editor")}
	var file=FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report)); file.close()
	quit()
