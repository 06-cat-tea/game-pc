class_name SaveStore
extends RefCounted

var base_path = "user://saves"
var session: GameSession
var import_in_progress = false

func _init(game: GameSession, directory: String = "user://saves"):
	session = game
	base_path = directory

func path_for(slot: int) -> String:
	return base_path.path_join("autosave.json" if slot == 0 else "slot_%d.json" % slot)

func save(slot: int = 0) -> String:
	if session.state.is_empty(): return "尚未开始游戏。"
	if session.state.training: return "训练期间不写入剧情存档。"
	if slot < 0 or slot > 3: return "存档位置无效。"
	return write_json(path_for(slot), session.state)

func write_json(destination: String, data: Dictionary) -> String:
	var absolute = ProjectSettings.globalize_path(destination)
	var error = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK: return "无法创建存档目录。"
	var temporary = absolute + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return "存档写入失败，原进度已保留。"
	file.store_string(JSON.stringify(data)); file.flush(); file.close()
	if FileAccess.file_exists(absolute):
		if FileAccess.file_exists(absolute + ".bak"): DirAccess.remove_absolute(absolute + ".bak")
		if DirAccess.rename_absolute(absolute, absolute + ".bak") != OK: return "无法备份原存档。"
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		if FileAccess.file_exists(absolute + ".bak"): DirAccess.rename_absolute(absolute + ".bak", absolute)
		return "保存未完成，原存档已恢复。"
	return ""

func read_json(source: String) -> Dictionary:
	if not FileAccess.file_exists(source): return {"error":"这里还没有存档。"}
	var file = FileAccess.open(source, FileAccess.READ)
	if file == null or file.get_length() > 2 * 1024 * 1024: return {"error":"请选择小于 2MB 的存档。"}
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {"error":"存档 JSON 已损坏，当前进度已保留。"}
	var data = parser.data
	var error = session.validate_save(data)
	if error != "": return {"error":error}
	return {"error":"", "data":data}

func load_slot(slot: int = 0) -> String:
	var result = read_json(path_for(slot))
	if result.error != "":
		var backup = read_json(path_for(slot) + ".bak")
		if backup.error != "": return result.error
		result=backup
	if not result.data.get("story",{}).has("awakenings") and not FileAccess.file_exists(path_for(slot)+".before-tp-v1.json"):
		var backup_error=write_json(path_for(slot)+".before-tp-v1.json",result.data)
		if backup_error!="": return backup_error
	if not result.data.has("story"):
		var backup_error=write_json(path_for(slot)+".before-content-v1.json",result.data)
		if backup_error!="": return backup_error
	if not result.data.has("task_state") and not FileAccess.file_exists(path_for(slot)+".before-quests-v1.json"):
		var backup_error=write_json(path_for(slot)+".before-quests-v1.json",result.data)
		if backup_error!="": return backup_error
	if int(result.data.get("combat_rules_version",1))<2 and not FileAccess.file_exists(path_for(slot)+".before-combat-v2.json"):
		var backup_error=write_json(path_for(slot)+".before-combat-v2.json",result.data)
		if backup_error!="": return backup_error
	return session.load_state(result.data)

func export_to(destination: String) -> String:
	if session.state.training: return "训练状态不能导出为剧情存档。"
	return write_json(destination, session.state)

func import_from(source: String) -> String:
	var result = read_json(source)
	if result.error != "": return result.error
	if not result.data.get("story",{}).has("awakenings") and not FileAccess.file_exists(base_path.path_join("import-before-tp-v1.json")):
		var backup_error=write_json(base_path.path_join("import-before-tp-v1.json"),result.data)
		if backup_error!="": return backup_error
	if not result.data.has("task_state") and not FileAccess.file_exists(base_path.path_join("import-before-quests-v1.json")):
		var backup_error=write_json(base_path.path_join("import-before-quests-v1.json"),result.data)
		if backup_error!="": return backup_error
	if int(result.data.get("combat_rules_version",1))<2 and not FileAccess.file_exists(base_path.path_join("import-before-combat-v2.json")):
		var backup_error=write_json(base_path.path_join("import-before-combat-v2.json"),result.data)
		if backup_error!="": return backup_error
	var previous = session.state.duplicate(true)
	if not result.data.has("story"):
		var backup_error=write_json(base_path.path_join("import-before-content-v1.json"),result.data)
		if backup_error!="": return backup_error
	# load_state emits changed synchronously. Its listener must not rotate the
	# autosave before this transaction writes it once and preserves the old .bak.
	import_in_progress = true
	var error = session.load_state(result.data)
	if error == "": error = save(0)
	if error != "": session.state = previous
	import_in_progress = false
	return error
