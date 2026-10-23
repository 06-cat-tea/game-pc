class_name BrowserFileBridge
extends Node

signal transfer_finished(operation: String, status: String, message: String)

const MAX_IMPORT_BYTES = 2 * 1024 * 1024
const DOWNLOAD_NAME = "ashen-frontier-godot-desktop.json"
const PICKER_SCRIPT = """
(() => {
  if (window.AshenFrontierSaveFiles) return;
  window.AshenFrontierSaveFiles = {
    lastResult: null,
    report(operation, status, message) {
      const result = {operation, status, message};
      this.lastResult = result;
      window.dispatchEvent(new CustomEvent('ashen-save-transfer', {detail: result}));
    },
    pick(callback, limit) {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = '.json,application/json';
      input.setAttribute('aria-label', '导入灰烬边境 JSON 存档');
      input.style.display = 'none';
      document.body.appendChild(input);
      let active = true;
      let reader = null;
      let focusTimer = null;
      const dispose = () => {
        active = false;
        clearTimeout(focusTimer);
        window.removeEventListener('focus', onFocus);
        input.remove();
        if (reader && reader.readyState === FileReader.LOADING) reader.abort();
        callback = null;
      };
      const finish = (status, value) => {
        if (!active) return;
        const notify = callback;
        dispose();
        notify(status, value);
      };
      const onFocus = () => {
        // Older browsers lack the file input's cancel event.
        focusTimer = setTimeout(() => {
          if (active && !reader && input.files.length === 0) finish('canceled', '');
        }, 300);
      };
      input.addEventListener('cancel', () => finish('canceled', ''));
      input.addEventListener('change', () => {
        const file = input.files[0];
        if (!file) return finish('canceled', '');
        if (file.size > limit) return finish('error', '请选择小于 2MB 的存档。');
        reader = new FileReader();
        reader.onerror = () => finish('error', '无法读取所选文件，当前进度已保留。');
        reader.onload = () => finish('selected', String(reader.result));
        reader.readAsText(file, 'UTF-8');
      });
      window.addEventListener('focus', onFocus);
      try { input.click(); }
      catch (_) { setTimeout(() => finish('error', '浏览器未能打开文件选择器，请重试。'), 0); }
      return {dispose};
    }
  };
})();
"""

var last_result: Dictionary = {}
var _game_ref: WeakRef
var _api: JavaScriptObject
var _picker: JavaScriptObject
var _file_callback: JavaScriptObject
var _import_pending = false

func setup(owner: Node):
	_game_ref = weakref(owner)

static func is_browser() -> bool:
	return OS.has_feature("web")

static func save_notice() -> String:
	if not OS.is_userfs_persistent():
		return "浏览器未提供持久存储，本次进度可能在关闭页面后丢失。请导出 JSON 备份。"
	return "进度保存在当前浏览器；清除网站数据会删除存档。可导出 JSON 备份，与 Godot 电脑版手动互导；旧网页版存档不兼容。"

static func export_text(session: GameSession) -> Dictionary:
	if session.state.is_empty(): return {"error":"尚未开始游戏。", "text":""}
	if session.state.get("training",false): return {"error":"训练状态不能导出为剧情存档。", "text":""}
	return {"error":"", "text":JSON.stringify(session.state)}

static func import_text(store: SaveStore, contents: String) -> String:
	if contents.to_utf8_buffer().size() > MAX_IMPORT_BYTES: return "请选择小于 2MB 的存档。"
	var destination = store.base_path.path_join("browser-import.pending.json")
	var absolute = ProjectSettings.globalize_path(destination)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return "无法创建存档目录。"
	var file = FileAccess.open(destination,FileAccess.WRITE)
	if file == null: return "无法准备导入文件，当前进度已保留。"
	file.store_string(contents); file.flush()
	var write_error = file.get_error()
	file.close()
	var error = "无法准备导入文件，当前进度已保留。" if write_error != OK else store.import_from(destination)
	DirAccess.remove_absolute(absolute)
	return error

func export_save():
	var game = _game_ref.get_ref() if _game_ref != null else null
	if game == null or not _ensure_api("export"): return
	var result = export_text(game.session)
	if result.error != "": _report("export","error",result.error); return
	JavaScriptBridge.download_buffer(result.text.to_utf8_buffer(),DOWNLOAD_NAME,"application/json")
	_report("export","complete","已请求下载，请查看浏览器下载列表。")

func import_save():
	var game = _game_ref.get_ref() if _game_ref != null else null
	if game == null or not _ensure_api("import"): return
	if _import_pending:
		game.toast("文件选择正在进行。")
		return
	_import_pending = true
	_file_callback = JavaScriptBridge.create_callback(_receive_file)
	_picker = _api.pick(_file_callback,MAX_IMPORT_BYTES)
	_report("import","pending","")

func _ensure_api(operation: String) -> bool:
	if not is_browser(): return false
	if _api == null:
		JavaScriptBridge.eval(PICKER_SCRIPT,true)
		_api = JavaScriptBridge.get_interface("AshenFrontierSaveFiles")
	if _api == null:
		_report(operation,"error","浏览器文件功能不可用，请重新载入页面。")
		return false
	return true

func _receive_file(arguments: Array):
	_import_pending = false
	_picker = null
	_file_callback = null
	var game = _game_ref.get_ref() if _game_ref != null else null
	if game == null: return
	if arguments.size() != 2:
		_report("import","error","无法读取所选文件，当前进度已保留。")
		return
	var status = str(arguments[0])
	if status == "canceled": _report("import","canceled","已取消导入，当前进度已保留。"); return
	if status != "selected": _report("import","error",str(arguments[1])); return
	var error = import_text(game.store,str(arguments[1]))
	if error != "": _report("import","error",error); return
	game.mode = "world"; game.world.scene_id = ""; game.close_menu(); game.refresh()
	_report("import","complete","导入成功。")

func _report(operation: String, status: String, message: String):
	last_result = {"operation":operation, "status":status, "message":message}
	if _api != null: _api.report(operation,status,message)
	var game = _game_ref.get_ref() if _game_ref != null else null
	if game != null and message != "": game.toast(message)
	transfer_finished.emit(operation,status,message)

func _exit_tree():
	if _picker != null: _picker.dispose()
	_picker = null
	_file_callback = null
	_api = null
	_import_pending = false
