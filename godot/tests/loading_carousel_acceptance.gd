extends RefCounted

func run(tree: SceneTree, verify: Callable):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame; game.new_game("warden"); var screen=game.loading
	var before=game.session.state.duplicate(true); var config=screen.config
	verify.call(config.tips.size()==30 and config.categories.size()==6,"加载页30条提示覆盖6个分类")
	var unique={}
	for tip in config.tips: unique[tip.id]=true
	verify.call(unique.size()==30,"提示ID唯一")
	for category in config.categories: verify.call(config.tips.filter(func(t): return t.category==category).size()==5,"提示分类各有5条："+category)
	LoadingScreen.last_image=""; game.session.state.settings.reduce_motion=false
	screen.begin("wood"); var image=screen.image_key; var tip=screen.tip_id
	verify.call(image=="wood" and screen.caption.text==config.images.wood.title,"优先目的地插画，标题保持实际目的地")
	screen._process(6.1); verify.call(screen.tip_id!=tip,"6秒切换不重复提示")
	screen._process(2.0)
	for i in 90:
		await tree.process_frame; screen._process(.01)
		if screen.image_key!=image: break
	verify.call(screen.image_key!=image,"8秒切换下一张已准备的插画")
	await tree.create_timer(.65).timeout
	verify.call(screen.art.texture!=null and screen.incoming.modulate.a==0,"淡入完成后复用两层图像，无黑帧")
	verify.call(screen.caption.text==config.images.wood.title,"轮播画面不改变实际目的地")
	screen.complete(); verify.call(screen.panel==null and not screen.is_processing() and not screen.busy,"完成后清理轮播并停止处理")
	game.session.state.settings.reduce_motion=true; screen.begin("city"); image=screen.image_key; tip=screen.tip_id; screen._process(30)
	verify.call(screen.image_key==image and screen.pending_key=="","减少动效固定背景，不预加载轮播图")
	verify.call(screen.tip_id!=tip,"减少动效仍可更新文字提示")
	screen.fail("测试网络异常"); var failed_tip=screen.tip_id; screen._process(30)
	verify.call(screen.failed and screen.tip_id==failed_tip and not screen.is_processing(),"错误状态停止轮播并保留提示")
	verify.call(screen.stage_label.tooltip_text=="测试网络异常","错误详情完整保留")
	screen.complete()
	var original=screen.config; screen.config=original.duplicate(true)
	for key in screen.config.images: screen.config.images[key].path="res://assets/loading/missing-"+key+".webp"
	screen.begin("departure"); verify.call(screen.art.texture==null and screen.tip_label.text!="","所有可选插画缺失时保留纯色底与提示")
	screen.complete(); screen.config=original
	var work_count=[0]; var start=Time.get_ticks_msec()
	await screen.run("camp",func(): work_count[0]+=1; return "")
	verify.call(work_count[0]==1 and not screen.busy,"加载工作只执行一次")
	verify.call(Time.get_ticks_msec()-start<1500,"快速加载不等待8秒轮播周期")
	game.session.state.settings=before.settings
	verify.call(game.session.state==before,"轮播与提示不改变游戏进度")
	game.queue_free(); await tree.process_frame
