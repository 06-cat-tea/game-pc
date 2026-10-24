class_name LoadingScreen
extends CanvasLayer

var busy=false
var committing=false
var failed=false
var panel: Control
var caption: Label
var stage_label: Label
var tip_label: Label
var picture_label: Label
var tip_category: Label
var progress_bar: ProgressBar
var game_ref: WeakRef
var history=[]
var retry: Callable
var selected_key=""
var config: Dictionary={}
var image_key=""
var tip_id=""
var image_queue=[]
var tip_queue=[]
var image_clock=0.0
var tip_clock=0.0
var pending_key=""
var art: TextureRect
var incoming: TextureRect
var image_tween: Tween
var finish_tween: Tween
var generation=0
static var last_image=""
static var last_tip=""

func _init():
	layer=100
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/loading.json"))
	set_process(false)

func setup(owner): game_ref=weakref(owner)

func reduced_motion() -> bool:
	var game=game_ref.get_ref() if game_ref!=null else null
	return game!=null and game.session.state.get("settings",{}).get("reduce_motion",false)

func _label(value: String, point: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label=UIkit.text(panel,value,point,dimensions,font_size,color)
	label.add_theme_font_override("font",UIkit.hud_font()); label.add_theme_color_override("font_shadow_color",Color(0,0,0,.65)); label.add_theme_constant_override("shadow_offset_y",2)
	label.autowrap_mode=TextServer.AUTOWRAP_OFF; label.clip_text=true; label.size=dimensions; label.set_deferred("size",dimensions)
	return label

func _art() -> TextureRect:
	var result=TextureRect.new(); result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; result.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; result.mouse_filter=Control.MOUSE_FILTER_IGNORE; UIkit.fill(result); panel.add_child(result)
	return result

func begin(key: String, stage: String = "准备旅程"):
	_cleanup_visuals(); generation+=1
	busy=true; failed=false; selected_key=key; history.append(key); image_clock=0; tip_clock=0; pending_key=""
	panel=Control.new(); UIkit.fill(panel); panel.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(panel)
	var backing=ColorRect.new(); backing.color=Color("101925"); UIkit.fill(backing); panel.add_child(backing)
	art=_art(); incoming=_art(); incoming.modulate.a=0
	image_queue=config.images.keys(); image_queue.shuffle()
	var first=key if config.images.has(key) else "departure"
	if first==last_image and image_queue.size()>1:
		first=image_queue.filter(func(candidate): return candidate!=last_image)[0]
	image_queue.erase(first)
	_set_first_image(first)
	var ramp=Gradient.new(); ramp.offsets=PackedFloat32Array([0,.62,1]); ramp.colors=PackedColorArray([Color(0.035,.055,.09,0),Color(.035,.055,.09,.76),Color(.035,.055,.09,.96)])
	var texture=GradientTexture2D.new(); texture.gradient=ramp; texture.fill_from=Vector2(.5,0); texture.fill_to=Vector2(.5,1)
	var wash=TextureRect.new(); wash.texture=texture; wash.position=Vector2(0,600); wash.size=Vector2(1920,480); wash.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(wash)
	var data=config.images.get(key,config.images.departure)
	picture_label=_label("画面 · "+str(config.images.get(image_key,data).title),Vector2(100,816),Vector2(1720,30),18,Color("c8b991"))
	caption=_label(str(data.title),Vector2(100,858),Vector2(1720,56),36,Color("ead7ad"))
	stage_label=_label(stage,Vector2(100,927),Vector2(1720,40),23,Color("f1ebe0"))
	progress_bar=ProgressBar.new(); progress_bar.position=Vector2(100,980); progress_bar.size=Vector2(1720,5); progress_bar.show_percentage=false; progress_bar.add_theme_font_size_override("font_size",1); progress_bar.add_theme_stylebox_override("background",UIkit.meter(Color("dbc494",.18))); progress_bar.add_theme_stylebox_override("fill",UIkit.meter(Color("dbc494"))); panel.add_child(progress_bar); progress_bar.size=Vector2(1720,5); progress_bar.set_deferred("size",Vector2(1720,5)); set_progress(-1)
	tip_category=_label("旅途提示",Vector2(100,1000),Vector2(172,36),19,Color("dbc494"))
	tip_label=_label("",Vector2(285,997),Vector2(1535,54),22,Color("eee7da"))
	var preferred=config.tips.filter(func(tip): return tip.category in data.get("tip_categories",[])); preferred.shuffle()
	var others=config.tips.filter(func(tip): return tip.category not in data.get("tip_categories",[])); others.shuffle()
	tip_queue=preferred+others; _next_tip()
	var game=game_ref.get_ref() if game_ref!=null else null
	if game!=null and game.world!=null: game.world.blocked=true; game.world.stop()
	set_process(true)

func _set_first_image(key: String):
	var choices=[key]; choices.append_array(image_queue)
	for candidate in choices:
		var path=str(config.images[candidate].path)
		if not ResourceLoader.exists(path): continue
		art.texture=load(path); image_key=candidate; last_image=candidate; image_queue.erase(candidate); return
	image_key="departure"

func _next_tip():
	if tip_queue.is_empty(): tip_queue=config.tips.duplicate(); tip_queue.shuffle()
	if tip_queue.size()>1 and tip_queue[0].id==last_tip: tip_queue.push_back(tip_queue.pop_front())
	var tip=tip_queue.pop_front(); tip_id=tip.id; last_tip=tip.id
	tip_label.text=tip.text; tip_category.text=config.categories.get(tip.category,"旅途提示")

func _prepare_image():
	if not pending_key.is_empty(): return
	if image_queue.is_empty():
		image_queue=config.images.keys(); image_queue.erase(image_key); image_queue.shuffle()
	while not image_queue.is_empty():
		var candidate=str(image_queue.pop_front()); var path=str(config.images[candidate].path)
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path)==OK: pending_key=candidate; return

func _advance_image():
	if pending_key.is_empty() or image_tween!=null and image_tween.is_running(): return
	var path=str(config.images[pending_key].path); var status=ResourceLoader.load_threaded_get_status(path)
	if status==ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
	if status!=ResourceLoader.THREAD_LOAD_LOADED: pending_key=""; image_clock=0; return
	incoming.texture=ResourceLoader.load_threaded_get(path); incoming.modulate.a=0
	image_key=pending_key; last_image=image_key; pending_key=""; image_clock=0
	picture_label.text="画面 · "+str(config.images[image_key].title)
	var token=generation
	image_tween=create_tween(); image_tween.tween_property(incoming,"modulate:a",1.0,float(config.rotation.fade_seconds))
	image_tween.tween_callback(func():
		if token!=generation or panel==null: return
		art.texture=incoming.texture; incoming.modulate.a=0)

func _process(delta: float):
	if not busy or failed or panel==null: return
	tip_clock+=delta
	if tip_clock>=float(config.rotation.tip_seconds): tip_clock=0; _next_tip()
	if reduced_motion(): return
	image_clock+=delta
	if image_clock>=float(config.rotation.image_seconds)-1.0: _prepare_image()
	if image_clock>=float(config.rotation.image_seconds): _advance_image()

func set_progress(value: float):
	if progress_bar==null: return
	progress_bar.indeterminate=value<0 and not reduced_motion()
	progress_bar.value=clampf(value,0,1)*100

func stage(value: String):
	if stage_label!=null: stage_label.text=value

func _cleanup_visuals():
	set_process(false)
	if image_tween!=null: image_tween.kill(); image_tween=null
	if finish_tween!=null: finish_tween.kill(); finish_tween=null
	if panel!=null: panel.free(); panel=null
	caption=null; stage_label=null; tip_label=null; picture_label=null; tip_category=null; art=null; incoming=null; progress_bar=null; pending_key=""

func _exit_tree(): _cleanup_visuals()

func complete():
	generation+=1; busy=false; failed=false; retry=Callable(); _cleanup_visuals()
	var game=game_ref.get_ref() if game_ref!=null else null
	if game!=null and game.world!=null: game.world.blocked=game.overlay!="" or game.paused or not game.focused or game.mode!="world"

func run(key: String, work: Callable) -> String:
	if busy: return "加载正在进行。"
	retry=work; begin(key,"正在准备资源"); var token=generation
	await get_tree().process_frame
	if token!=generation: return "加载已结束。"
	var data=config.images.get(key,config.images.departure); var paths=data.get("resources",[])
	for path in paths:
		if not ResourceLoader.exists(path): return fail("资源缺失："+str(path))
		if ResourceLoader.load_threaded_request(path)!=OK: return fail("资源请求失败："+str(path))
	for path in paths:
		while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var amount=[]; ResourceLoader.load_threaded_get_status(path,amount)
			if not amount.is_empty(): set_progress(float(amount[0]))
			stage("正在载入场景素材"); await get_tree().process_frame
			if token!=generation: return "加载已结束。"
		if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED: return fail("资源读取失败："+str(path))
		ResourceLoader.load_threaded_get(path)
	set_progress(-1); stage("正在构建场景"); await get_tree().process_frame
	if token!=generation: return "加载已结束。"
	committing=true; var error=str(work.call()); committing=false
	if error!="": return fail(error)
	set_progress(1); stage("场景准备完成"); await get_tree().process_frame
	if token!=generation: return "加载已结束。"
	if not reduced_motion():
		finish_tween=create_tween(); finish_tween.tween_property(panel,"modulate:a",0.0,.12); await finish_tween.finished
	if token==generation: complete()
	return ""

func fail(message: String) -> String:
	failed=true; set_process(false)
	if image_tween!=null: image_tween.kill(); image_tween=null
	stage("未能完成加载："+message)
	stage_label.size.x=1150; stage_label.autowrap_mode=TextServer.AUTOWRAP_OFF; stage_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; stage_label.tooltip_text=message
	UIkit.action(panel,"重试",Vector2(1360,916),Vector2(180,60),func():
		if game_ref==null: get_tree().reload_current_scene(); return
		var callback=retry; busy=false; run(selected_key,callback),true)
	UIkit.action(panel,"返回",Vector2(1580,916),Vector2(180,60),func():
		if game_ref==null: get_tree().reload_current_scene()
		else: complete())
	return message
