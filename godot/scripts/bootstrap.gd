extends Control

func _ready():
	var loading=LoadingScreen.new(); add_child(loading)
	loading.begin("departure","正在读取旅程资源")
	await get_tree().process_frame
	var path="res://scenes/main.tscn"
	var error=ResourceLoader.load_threaded_request(path)
	if error!=OK: loading.fail("无法准备主场景。"); return
	while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:
		loading.fail("主场景资源读取失败。"); return
	loading.stage("正在初始化旅程与界面")
	await get_tree().process_frame
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(path))
