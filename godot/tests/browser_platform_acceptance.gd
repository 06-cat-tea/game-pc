extends RefCounted

func run(tree: SceneTree, verify: Callable):
	var session = GameSession.new(tree.db)
	verify.call(BrowserFileBridge.export_text(session).error != "","浏览器导出拒绝尚未开始的旅程")
	session.new_game("ranger")
	var directory = "user://tests/browser-platform-" + str(Time.get_ticks_usec())
	var store = SaveStore.new(session,directory)
	verify.call(store.save(0) == "" and store.save(1) == "","浏览器导入验收使用独立的自动档与手动档")
	var automatic_writes = [0]
	var autosave_listener = func():
		if not store.import_in_progress and not session.state.is_empty() and not session.state.training:
			automatic_writes[0] += 1; store.save(0)
	session.changed.connect(autosave_listener)
	session.state.gold = 321
	var exported = BrowserFileBridge.export_text(session)
	verify.call(exported.error == "" and JSON.parse_string(exported.text).gold == 321,"浏览器下载内容使用完整 Godot JSON 存档")
	session.state.gold = 1
	verify.call(BrowserFileBridge.import_text(store,exported.text) == "" and session.state.gold == 321,"浏览器选中文件经现有校验与存档流程恢复旅程")
	verify.call(not FileAccess.file_exists(directory.path_join("browser-import.pending.json")),"导入成功后删除文件暂存副本")
	verify.call(FileAccess.file_exists(store.path_for(0)+".bak"),"浏览器导入沿用自动存档的原进度备份")
	verify.call(store.read_json(store.path_for(0)+".bak").data.gold == 95,"导入触发 changed 监听时仍保留导入前自动档内容")
	verify.call(automatic_writes[0] == 0 and not store.import_in_progress,"导入事务只写一次自动档并解除自动保存抑制")
	verify.call(store.read_json(store.path_for(1)).data.gold == 95,"浏览器导入不覆盖其他手动档")
	var before = session.state.duplicate(true)
	var autosave = FileAccess.get_file_as_string(store.path_for(0))
	for contents in ["{broken",'{"schema":6,"player":{}}',"[]"]:
		verify.call(BrowserFileBridge.import_text(store,contents) != "" and session.state == before,"损坏或退役网页格式不改变浏览器当前进度")
		verify.call(FileAccess.get_file_as_string(store.path_for(0)) == autosave,"导入无效文件不覆盖自动档")
		verify.call(not FileAccess.file_exists(directory.path_join("browser-import.pending.json")),"导入失败后也删除文件暂存副本")
	for key in ["formation","battle"]:
		var malformed = before.duplicate(true); malformed.erase(key)
		verify.call(BrowserFileBridge.import_text(store,JSON.stringify(malformed)) != "" and session.state == before,"缺少必要字段时干净拒绝导入："+key)
	var battle_session = GameSession.new(tree.db); battle_session.new_game("ranger"); battle_session.state.location.scene = "town-trial"
	var battle_error = battle_session.start_battle("town-trial-0",417)
	var valid_battle = battle_error == "" and battle_session.state.battle is Dictionary and battle_session.validate_save(battle_session.state) == ""
	verify.call(valid_battle,"战斗导入校验使用可恢复的真实剧情战斗："+battle_error)
	if valid_battle:
		for key in ["id","team","phase"]:
			var malformed = battle_session.state.duplicate(true); malformed.battle.units[0].erase(key)
			verify.call(BrowserFileBridge.import_text(store,JSON.stringify(malformed)) != "" and session.state == before,"战斗单位缺少字段时不触发脚本错误："+key)
		var invalid_phase = battle_session.state.duplicate(true); invalid_phase.battle.units[-1].phase = []
		verify.call(BrowserFileBridge.import_text(store,JSON.stringify(invalid_phase)) != "" and session.state == before,"错误类型的战斗阶段不触发类型转换错误")
	var invalid_equipment = before.duplicate(true); invalid_equipment.gear["invalid"] = {"item":"potion","rank":0}; invalid_equipment.members.hero.equip.weapon = "invalid"
	verify.call(BrowserFileBridge.import_text(store,JSON.stringify(invalid_equipment)) != "" and session.state == before,"将消耗品篡改为装备时干净拒绝导入")
	var padded = exported.text + " ".repeat(BrowserFileBridge.MAX_IMPORT_BYTES-exported.text.to_utf8_buffer().size())
	verify.call(BrowserFileBridge.import_text(store,padded) == "","浏览器存档大小上限与现有 2MiB 文件校验一致")
	before = session.state.duplicate(true)
	verify.call(BrowserFileBridge.import_text(store,padded+" ") != "" and session.state == before,"超过 2MiB 的浏览器存档不覆盖进度")
	verify.call(BrowserFileBridge.import_text(store,"界".repeat(700000)) != "" and session.state == before,"浏览器存档限制计算 UTF-8 字节数")
	var previous_version = session.state.duplicate(true)
	previous_version.erase("task_state")
	verify.call(BrowserFileBridge.import_text(store,JSON.stringify(previous_version)) == "" and FileAccess.file_exists(directory.path_join("import-before-quests-v1.json")),"浏览器导入保留现有旧版 Godot 存档迁移备份")
	session.enter_training("ranger",["mira"],6)
	verify.call(BrowserFileBridge.export_text(session).error != "","训练状态不能从浏览器导出为剧情存档")
	session.exit_training()
	session.changed.disconnect(autosave_listener)
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
