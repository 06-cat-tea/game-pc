extends RefCounted

var completed=false
var db: GameContent
var verify: Callable

func check(condition: bool, text: String): verify.call(condition,text)

func session() -> GameSession:
	var s=GameSession.new(db); s.new_game("warden"); return s

func turn(engine: BattleEngine, id: String):
	engine.battle.cursor=engine.battle.queue.find(id)
	if engine.battle.cursor<0: engine.battle.queue.append(id); engine.battle.cursor=engine.battle.queue.size()-1

func command(engine: BattleEngine, kind: String, target: String, skill: String="") -> Dictionary:
	return BattleCommand.new(engine.current().id,kind,target,skill,engine.battle.token).to_dict()

func run(tree: SceneTree, callback: Callable):
	verify=callback; db=GameContent.new()
	check(db.progression.ultimates.size()==7 and db.progression.buildings.size()==12 and db.progression.rooms.size()==2,"七段觉醒、十二建筑与两间新内室完整")
	for site in db.progression.buildings.values():
		check(site.details.size()==2 and db.raw.scenes.has(site.scene),"建筑有两处细节及可进入地点："+site.building)
	for id in db.progression.ultimates:
		var game=session()
		if id!="hero": game._add_member(id,db.actors[id].job,6); game.state.personal[id]={"stage":2,"done":true}
		else: game.state.chapter_complete=true
		var definition=db.progression.ultimates[id]; game.state.location={"scene":definition.scene,"x":8.5,"y":8.5}
		game.progression.begin(id)
		check(game.progression.record(id).stage==1,"觉醒开场可接取："+id)
		game.inspect_prop(definition.scene,definition.clues[0]); game.inspect_prop(definition.scene,definition.clues[0])
		check(game.progression.record(id).stage==1 and game.progression.record(id).clues==[0],"重复调查同一线索不推进第二处："+id)
		for clue in definition.clues: game.inspect_prop(definition.scene,clue)
		check(game.progression.record(id).stage==2,"两处实际线索推进觉醒："+id)
		var snapshot=game.state.duplicate(true)
		check(game.progression.begin_trial(id)=="" and game.state.training and game.state.active.size()==4 and id in game.state.active,"六级回响试炼包含指定角色："+id)
		check(game.state.members[id].level==6 and game.engine.unit(id).tp==100,"试炼提供六级与完整TP："+id)
		turn(game.engine,id)
		var targets=game.engine.legal_targets(game.engine.current(),"ultimate",id)
		var cast=command(game.engine,"ultimate",targets[0].id,id)
		var result=game.combat(cast)
		check(result.error=="" and game.engine.unit(id).tp==0,"七种大招均合法且仅扣100TP："+id)
		var replay=game.combat(cast)
		check(replay.error!="" and game.engine.unit(id).tp==0,"大招重复提交不会再次结算："+id)
		var safety=0
		while game.state.battle!=null and safety<160:
			game.combat(game.engine.ai_command()); safety+=1
		check(safety<160 and game.engine.battle.result=="win","角色试炼能正常获胜："+id)
		game.progression.finish_trial()
		check(not game.state.training and game.state.members==snapshot.members and game.state.items==snapshot.items and game.state.materials==snapshot.materials and game.state.gold==snapshot.gold,"试炼恢复原队伍、TP与物资："+id)
		check(game.progression.record(id).stage==3,"胜利只推进收束交谈："+id)
		game.progression.complete(id)
		check(game.progression.unlocked(id) and game.state.members[id].tp==0,"收束解锁角色大招："+id)
		check(game.validate_save(game.state)=="","新增觉醒进度可存读："+id)
		var restored=GameSession.new(db)
		check(restored.load_state(JSON.parse_string(JSON.stringify(game.state)))=="" and restored.progression.unlocked(id) and restored.progression.record(id).clues==[0,1],"实际JSON数值转换后觉醒仍可载入："+id)
		var before=game.state.duplicate(true); game.progression.complete(id)
		check(before==game.state,"觉醒奖励不可重复领取："+id)
	_test_tp()
	_test_services()
	_test_legacy()
	_test_upgrade_backup()
	await _test_ui(tree)
	completed=true

func _test_tp():
	var game=session(); game.enter_training("warden",["mira","toren","eira"],6); game.start_battle("town-trial-2",817)
	var engine=game.engine; var hero=engine.unit("hero"); var enemy=engine.living("enemy")[0]
	turn(engine,"hero"); hero.tp=99
	check(engine.validate(command(engine,"ultimate",enemy.id,"hero"))!="" and hero.tp==99,"不足100TP不能释放且不扣除")
	hero.tp=100; hero.awakened=false
	check(engine.validate(command(engine,"ultimate",enemy.id,"hero"))!="","未觉醒不能释放")
	hero.awakened=true; engine.apply_effect(hero,"silence",2)
	check(engine.validate(command(engine,"ultimate",enemy.id,"hero"))!="" and hero.tp==100,"沉默期间不能释放")
	hero.effects=[]
	check(engine.validate(command(engine,"ultimate",enemy.id,"mira"))!="" and hero.tp==100,"不能借用其他角色大招")
	hero.tp=0; turn(engine,"hero"); enemy.hp=900; enemy.max_hp=900; enemy.posture=1; enemy.weakness=["physical"]
	game.combat(command(engine,"attack",enemy.id))
	check(hero.tp==30,"普通行动20TP、架势击破额外10TP")
	hero.tp=0; hero.effects=[]
	for i in 3: engine._strike(enemy,hero,.4,"physical",true,"受击测试",0,false)
	check(hero.tp==20,"每轮受击TP上限20")
	engine._hurt(hero,2,"持续毒",false); check(hero.tp==20,"持续伤害不充TP")
	hero.tp=100; engine._hurt(hero,100000,"倒地测试"); check(hero.tp==0,"倒地清空TP")
	engine._revive(hero,.3,"复活测试"); check(hero.tp==0,"苏生不补TP")
	turn(engine,"mira"); var mira=engine.unit("mira"); mira.tp=100
	check(engine.ai_command().action!="ultimate","自动战斗默认保留TP")
	mira.ultimate_auto=true; check(engine.ai_command().action=="ultimate","显式允许后AI可用大招")
	turn(engine,"eira"); var eira=engine.unit("eira"); eira.tp=100
	hero.hp=0; engine.unit("toren").hp=0; eira.hp=10
	game.combat(command(engine,"ultimate",eira.id,"eira"))
	check(hero.hp==ceili(hero.max_hp*.3) and engine.unit("toren").hp==0,"艾拉按站位复活一人且不重复群疗")
	game.exit_training()
	game.enter_training("warden",["mira","toren","eira"],6); game.start_battle("town-trial-2",820)
	turn(game.engine,"hero"); hero=game.engine.unit("hero"); enemy=game.engine.living("enemy")[0]
	enemy.hp=900; enemy.max_hp=900; enemy.posture=90; enemy.max_posture=90; enemy.weakness=["astral"]
	game.combat(command(game.engine,"ultimate",enemy.id,"hero"))
	check(enemy.posture==60,"旅人大招使用独立配置的30点削韧")
	game.exit_training()
	game.state.story.awakenings.hero={"stage":4,"clues":[0,1]}; game.state.members.hero.tp=73
	game.rest(); game.change_job("ranger"); game.visit("room-chapel")
	check(game.state.members.hero.tp==73,"休息、转职、旅行保留TP")
	var copy=GameSession.new(db); copy.load_state(game.state); check(copy.state.members.hero.tp==73,"跨存读保留TP")
	game.state.location={"scene":"town-wall","x":8.5,"y":8.5}; game.start_battle("town-wall-0",818)
	check(game.engine.unit("hero").tp==73,"新战斗继承个人TP")

func _test_services():
	for id in db.progression.buildings:
		var site=db.progression.buildings[id]
		if site.type not in ["commission","order","research","clue"]: continue
		var game=session(); game.state.materials={"herb":20,"ore":20,"shard":20}; game.state.location={"scene":site.scene,"x":8.5,"y":8.5}
		var gold=game.state.gold
		if site.type!="clue": game.tasks.accept("service:"+id,"service:"+id)
		game.progression.use_service(id)
		if site.type in ["research","order"]: game.progression.use_service(id)
		check(game.state.story.building_services.get(id,false),"建筑服务可完成："+id)
		if site.type=="commission": check(game.state.gold==gold+site.gold,"委托金币按约定发放")
		var snapshot=game.state.duplicate(true); game.progression.use_service(id)
		check(game.state==snapshot,"服务不能重复领取："+id)
		check(game.validate_save(game.state)=="","服务记录合法："+id)

func _test_legacy():
	var game=session(); game.state.story.erase("awakenings"); game.state.story.erase("building_services")
	game.state.members.hero.erase("tp"); game.state.members.hero.erase("ultimate_auto")
	var restored=GameSession.new(db)
	check(restored.load_state(game.state)=="" and restored.state.members.hero.tp==0,"旧v1缺字段安全补零")
	for invalid in [-1,101,0.5,"100"]:
		var data=restored.state.duplicate(true); data.members.hero.tp=invalid
		check(restored.validate_save(data)!="","拒绝非法TP："+str(invalid))
	var corrupt=restored.state.duplicate(true); corrupt.story.awakenings.hero={"stage":4,"clues":[]}
	check(restored.validate_save(corrupt)!="","拒绝损坏觉醒阶段")
	game=session(); game.state.location.scene="town-wall"; game.start_battle("town-wall-0",821)
	var data=game.state.duplicate(true); data.battle.erase("event_seq"); data.battle.erase("instance_id")
	for actor in data.battle.units:
		for field in ["tp","awakened","ultimate_auto","tp_hit_round","tp_hit_gain"]: actor.erase(field)
	check(restored.load_state(data)=="" and restored.engine.unit("hero").tp==0,"旧战斗存档补齐TP与事件编号")
	var original_seq=restored.engine.battle.event_seq
	var event_ids={}
	var result=restored.combat(restored.engine.ai_command())
	for event in result.events: event_ids[event.event_id]=true
	check(restored.engine.battle.event_seq>original_seq and event_ids.size()==result.events.size(),"旧战斗继续行动后事件编号唯一递增")
	var resumed=GameSession.new(db)
	check(resumed.load_state(restored.state)=="" and resumed.engine.battle.event_seq==restored.engine.battle.event_seq,"事件序号随战斗存档保留")
	data=restored.state.duplicate(true); data.battle.event_seq=1.5
	check(restored.validate_save(data)!="","拒绝小数战斗事件序号")

func _test_upgrade_backup():
	var game=session(); game.state.story.erase("awakenings"); game.state.story.erase("building_services")
	game.state.members.hero.erase("tp"); game.state.members.hero.erase("ultimate_auto")
	var store=SaveStore.new(game,"user://tests/awakening-backup")
	for suffix in ["",".bak",".before-tp-v1.json",".before-tp-v1.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store.path_for(1)+suffix))
	store.write_json(store.path_for(1)+".bak",game.state)
	check(store.load_slot(1)=="" and FileAccess.file_exists(store.path_for(1)+".before-tp-v1.json"),"从备用旧档恢复也先保留升级前备份")
	var backup=JSON.parse_string(FileAccess.get_file_as_string(store.path_for(1)+".before-tp-v1.json"))
	check(not backup.story.has("awakenings") and not backup.members.hero.has("tp"),"升级备份保留原始v1字段")

func _test_ui(tree: SceneTree):
	var game=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(game); game.capture_mode=true
	await tree.process_frame; game.new_game("warden"); game.focused=true; game.set_process(false); game.world.set_process(false)
	game.open_menu("journal"); await tree.process_frame
	var list=game._scrolls(game.overlay_root)[0].get_child(0)
	for i in mini(6,list.get_child_count()):
		list.get_child(i).pressed.emit()
		check(list.get_children().filter(func(n): return n.get_meta("selected",false)).size()==1,"连续点选始终恰好一个选中项")
	game.session.state.dialogue["mira:past"]=0; game.session.state.dialogue["mira:daily:read"]=true; game.open_menu("npc","mira")
	var dialogue=game.overlay_root.get_child(0)
	var labels=dialogue.choice_buttons.map(func(n): return n.text)
	check(not labels.any(func(text): return game.db.raw.dialogues.mira.past.title in text or game.db.raw.dialogues.mira.daily.title in text),"已完成及旧往事对话不再显示")
	check(labels.any(func(text): return "赠礼" in text),"重复服务继续显示")
	var menu_event=InputEventKey.new(); menu_event.keycode=KEY_B; menu_event.pressed=true; game._input(menu_event)
	check(game.overlay=="npc","对白优先接收按键，不被菜单快捷键切走")
	game.close_menu()
	var f=InputEventKey.new(); f.physical_keycode=KEY_F
	var e=InputEventKey.new(); e.physical_keycode=KEY_E
	check(InputMap.event_is_action(f,"interact") and not InputMap.event_is_action(e,"interact"),"F交互与战斗E键没有冲突")
	var input=LineEdit.new(); game.ui.add_child(input); input.grab_focus(); await tree.process_frame
	game._input(menu_event); check(game.overlay=="","文字输入优先，不触发菜单快捷键")
	input.queue_free(); await tree.process_frame
	for key in GameBindings.MENUS:
		var event=InputEventKey.new(); event.pressed=true; event.keycode=key; event.physical_keycode=key
		game._input(event); check(game.overlay==GameBindings.MENUS[key],"快捷键打开菜单："+GameBindings.label(game.overlay))
		game._input(event); check(game.overlay=="","同键关闭菜单")
	game.session.state.location={"scene":"room-chapel","x":8,"y":8}; game.world.scene_id=""; game.refresh(); game.world.blocked=false
	for pair in [[KEY_W,KEY_A],[KEY_W,KEY_D],[KEY_UP,KEY_LEFT],[KEY_UP,KEY_RIGHT]]:
		for key in pair:
			var event=InputEventKey.new(); event.keycode=key; event.physical_keycode=key; event.pressed=true; Input.parse_input_event(event)
		await tree.process_frame
		var before=game.world.player; game.world._process(.03); var screen=game.world.projection()*(game.world.player-before)
		check(screen.y<0 and (screen.x<0 if pair[1] in [KEY_A,KEY_LEFT] else screen.x>0),"真实按键左右上方向正确")
		for key in pair:
			var event=InputEventKey.new(); event.keycode=key; event.physical_keycode=key; event.pressed=false; Input.parse_input_event(event)
		await tree.process_frame
	game.close_menu(); game.session.enter_training("warden",["mira","toren","eira"],6); game.session.start_battle("town-trial-2",819); turn(game.session.engine,"hero"); game.mode="battle"; game.refresh()
	var event=InputEventKey.new(); event.keycode=KEY_Q; event.pressed=true; game._input(event)
	check(game.pending_action=="ultimate" and game.session.engine.unit("hero").tp==100,"Q只选择大招，不直接扣TP")
	game.perform(); var ids=game.combat_effects.seen.size(); var token=game.session.engine.battle.token
	game.perform(); game.refresh()
	check(game.session.engine.battle.token==token and game.combat_effects.seen.size()==ids,"演出期间不能重复提交，刷新不重播特效")
	var playing=game.combat_effects.visuals.duplicate(true)
	check(game.combat_effects.play(game.last_events,game._fighter_anchors(),false)==0 and game.combat_effects.visuals==playing,"重复事件不重播且不打断当前演出")
	game.combat_effects.reset()
	check(game.combat_effects.play(game.last_events,game._fighter_anchors(),true)==.12 and game.combat_effects.reduced,"减少动效保留简短命中与状态提示")
	game.exit_training()
	check(not game.session.state.training and game.mode=="world" and game.action_cooldown==0 and game.combat_effects.visuals.is_empty(),"演出期间退出演练立即恢复世界且清理表现队列")
	game.queue_free(); await tree.process_frame
