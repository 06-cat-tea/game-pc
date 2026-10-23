class_name LoadingScreen
extends CanvasLayer

var busy=false
var committing=false
var failed=false
var panel: Control
var caption: Label
var stage_label: Label
var game_ref: WeakRef
var history=[]
var retry: Callable
var selected_key=""
var config: Dictionary={}

func _init():
	layer=100
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/loading.json"))

func setup(owner): game_ref=weakref(owner)

func begin(key: String, stage: String = "准备旅程"):
	busy=true; failed=false; selected_key=key; history.append(key)
	if panel!=null: panel.free()
	panel=Control.new(); UIkit.fill(panel); panel.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(panel)
	var data=config.images.get(key,config.images.departure)
	var path=str(data.path)
	if not ResourceLoader.exists(path): path="res://assets/art-v2/title.webp"
	var art=TextureRect.new(); art.texture=load(path); art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; UIkit.fill(art); panel.add_child(art)
	UIkit.card(panel,Vector2(0,840),Vector2(1920,240),Color(.035,.04,.065,.86),Color.TRANSPARENT)
	caption=UIkit.text(panel,str(data.title),Vector2(100,870),Vector2(1720,55),36,Color("ead7ad"))
	stage_label=UIkit.text(panel,stage,Vector2(100,936),Vector2(1720,40),23,Color("f1ebe0"))
	UIkit.text(panel,str(data.tip),Vector2(100,991),Vector2(1720,42),21,Color("cfc9bf"))
	var game=game_ref.get_ref() if game_ref!=null else null
	if game!=null and game.world!=null: game.world.blocked=true; game.world.stop()

func stage(value: String):
	if stage_label!=null: stage_label.text=value

func complete():
	busy=false; failed=false; retry=Callable()
	if panel!=null: panel.queue_free(); panel=null
	var game=game_ref.get_ref() if game_ref!=null else null
	if game!=null and game.world!=null: game.world.blocked=game.overlay!="" or game.paused or not game.focused or game.mode!="world"

func run(key: String, work: Callable) -> String:
	if busy: return "加载正在进行。"
	retry=work; begin(key,"正在准备资源")
	await get_tree().process_frame
	var data=config.images.get(key,config.images.departure)
	var paths=data.get("resources",[])
	for path in paths:
		if not ResourceLoader.exists(path): return fail("资源缺失："+str(path))
		var error=ResourceLoader.load_threaded_request(path)
		if error!=OK: return fail("资源请求失败："+str(path))
	for path in paths:
		while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			stage("正在载入场景素材"); await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED: return fail("资源读取失败："+str(path))
		ResourceLoader.load_threaded_get(path)
	stage("正在构建场景")
	await get_tree().process_frame
	committing=true
	var error=str(work.call())
	committing=false
	if error!="": return fail(error)
	stage("场景准备完成")
	await get_tree().process_frame
	var game=game_ref.get_ref() if game_ref!=null else null
	if game!=null and not game.session.state.get("settings",{}).get("reduce_motion",false):
		var tween=create_tween(); tween.tween_property(panel,"modulate:a",0.0,.12); await tween.finished
	complete()
	return ""

func fail(message: String) -> String:
	failed=true
	stage("未能完成加载："+message)
	stage_label.size.x=1150; stage_label.autowrap_mode=TextServer.AUTOWRAP_OFF; stage_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; stage_label.tooltip_text=message
	UIkit.action(panel,"重试",Vector2(1360,916),Vector2(180,60),func():
		if game_ref==null: get_tree().reload_current_scene(); return
		var callback=retry; busy=false; run(selected_key,callback),true)
	UIkit.action(panel,"返回",Vector2(1580,916),Vector2(180,60),func():
		if game_ref==null: get_tree().reload_current_scene()
		else: complete())
	return message
