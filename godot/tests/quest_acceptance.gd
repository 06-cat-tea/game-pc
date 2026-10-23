extends RefCounted

func run(tree: SceneTree, check: Callable):
	var db=tree.db; var g=GameSession.new(db); g.new_game()
	check.call(g.tasks.ledger.records.is_empty(),"新档支线接取记录为空，主线独立自动追踪")
	for action in ["guild","chapel"]: g.story.activity(action)
	g.visit("wood"); g.story.activity("forage"); g.story.activity("ruins"); g.story.core_event("tavern","forest")
	check.call(g.tasks.ledger.records.is_empty() and g.state.story.quests.is_empty(),"交谈、采集、调查、地点行动不隐式接取")
	check.call(not g.tasks.published("expeditions:town") and not g.tasks.published("battle:patrol"),"未发现入口的连续调查与战斗委托不提前发布")
	check.call(g.visit("town-wall")!="","未知子地图不能通过菜单直接进入")
	g.visit("room-guildhall"); g.tasks.accept("service:guildhall","board")
	check.call(g.tasks.status("service:guildhall")=="active","缺少药草时只显示进行中")
	var before=g.state.duplicate(true); g.tasks.turn_in("service:guildhall","board")
	check.call(before==g.state,"材料不足时交付不结算任何部分")
	g.state.materials.herb=3
	check.call(g.tasks.status("service:guildhall")=="ready","已有库存能使材料委托可交付")
	var gold=g.state.gold; g.tasks.turn_in("service:guildhall","board")
	check.call(g.state.materials.herb==0 and g.state.gold==gold+18 and g.state.story.building_services.guildhall,"药草委托复用原服务，交付扣除三份材料并仅发原奖励")
	before=g.state.duplicate(true); g.progression.use_service("guildhall"); g.tasks.turn_in("service:guildhall","board")
	check.call(g.state==before,"委托板与原建筑服务不能重复领奖")
	g.tasks.accept("guild-ore","board"); g.state.materials.ore=2; gold=g.state.gold; g.tasks.turn_in("guild-ore","board")
	check.call(g.state.materials.ore==0 and g.state.gold==gold+14,"矿样委托在板上交付并原子扣除库存")
	var gathering=GameSession.new(db); gathering.new_game(); gathering.visit("room-guildhall"); gathering.tasks.accept("first","board"); gathering.tasks.accept("service:guildhall","board")
	check.call(gathering.tasks.target("service:guildhall").id=="herb-1","缺少材料时定位实际尚未采集的资源点")
	gathering.visit("town")
	for resource in ["herb-1","herb-2","herb-3"]: gathering.tasks.town_action(resource,"gather")
	check.call(gathering.tasks.status("first")=="ready" and gathering.tasks.status("service:guildhall")=="ready","新镇内采集同时推进已接取的名册与材料目标")
	check.call(gathering.tasks.ledger.records.size()==2,"采集不会隐式接取其他任务")
	g.visit("town")
	for id in ["resident:dog","resident:bag","resident:letter"]: check.call(not g.tasks.published(id),"后续居民委托在前一份交付前隐藏："+id)
	for id in ["resident:cat","resident:dog","resident:rabbit","resident:bag","resident:hen","resident:letter"]:
		var d=g.tasks.definition(id); g.tasks.accept(id,d.giver)
		check.call(g.tasks.status(id)=="active","向孩子明确接取："+id)
		var tokens=g.tasks.ledger.tokens.duplicate(true); g.tasks.accept(id,d.giver)
		check.call(tokens==g.tasks.ledger.tokens,"重复接取不会重复发放任务物品："+id)
		for step in d.steps: g.tasks.town_action(step.target,"task")
		check.call(g.tasks.status(id)=="ready","居民目标完成进入可交付："+id)
		gold=g.state.gold; g.tasks.turn_in(id,"board")
		check.call(g.state.gold==gold,"居民委托不能在板上远程交付："+id)
		g.tasks.turn_in(id,d.giver)
		check.call(g.tasks.status(id)=="completed" and g.state.gold==gold+d.reward.gold,"返回孩子单次交付："+id)
		before=g.state.duplicate(true); g.tasks.turn_in(id,d.giver)
		check.call(g.state==before,"居民奖励防止连点与双入口重复："+id)
	check.call(g.tasks.ledger.tokens.values().all(func(v): return v==0),"六份居民委托结束不残留嫩叶、食盆、饲料、药包或信笺")
	for d in db.world_interactions.resources:
		var amount=g.state.materials[d.material]; g.tasks.town_action(d.id,"gather"); g.tasks.town_action(d.id,"gather")
		check.call(g.state.materials[d.material]==amount+1,"镇内资源仅首次采集一份："+d.id)
	var saved=JSON.parse_string(JSON.stringify(g.state)); var copy=GameSession.new(db)
	var loading=copy.load_state(saved)
	check.call(loading=="" and JSON.parse_string(JSON.stringify(copy.state))==saved,"任务生命周期与镇内记录可完整存读："+loading)
	for d in db.world_interactions.resources:
		var amount=copy.state.materials[d.material]; copy.tasks.town_action(d.id,"gather")
		check.call(copy.state.materials[d.material]==amount,"读档不会刷新一次性资源："+d.id)
	var old=g.state.duplicate(true); old.erase("task_state"); old.quests.first={"progress":2,"done":false}; old.personal.eira={"stage":1,"done":false}; old.story.expeditions.town={"stage":3,"done":true}
	gold=old.gold; check.call(copy.load_state(old)=="","旧 v1 任务迁移可载入")
	check.call(copy.tasks.accepted("first") and copy.tasks.stage("first")==2 and copy.tasks.accepted("personal:eira"),"旧档已有任务视为已接取并保留进度")
	check.call(copy.tasks.status("expeditions:town")=="completed" and copy.state.gold==gold,"旧档已完成任务归档，不追发奖励")
	old.story.investigation_facts={}
	check.call(copy.load_state(old)=="" and copy.state.story.investigation_facts.size()==5,"缺失的地区剧情事实逐项安全补默认")
	var store=SaveStore.new(copy,"user://tests/quest-migration"); store.write_json(store.path_for(1),old); store.load_slot(1)
	check.call(FileAccess.file_exists(store.path_for(1)+".before-quests-v1.json"),"旧档升级前保留一次任务生命周期备份")
	for field in ["sequence","tokens","entrances","records"]:
		var bad=saved.duplicate(true); bad.task_state[field]=-1
		check.call(copy.load_state(bad)!="","非法任务字段拒绝载入："+field)
	var bad_entrance=saved.duplicate(true); bad_entrance.task_state.entrances=[0]
	check.call(copy.load_state(bad_entrance)!="","入口数组中的非法数值安全拒绝，不能造成加载异常")
	var scene=load("res://scenes/main.tscn").instantiate(); tree.root.add_child(scene); scene.capture_mode=true; scene.capture_args.path=""
	await tree.process_frame; scene.new_game("warden"); scene.world.set_process(false); scene.focused=true
	var world=scene.world
	for e in db.world_interactions.entrances:
		scene.session.state.location={"scene":e.region,"x":e.point[0],"y":e.point[1]}; world.scene_id=""; world.show_location(); world.blocked=false
		check.call(world._can_walk(Vector2(e.point[0],e.point[1])),"实际入口可通行："+e.id)
		check.call(world.targets.any(func(t): return t.kind=="entrance" and t.id==e.id),"场景有独立可交互入口："+e.id)
		var spawn=db.regions[e.region].spawn if db.regions.has(e.region) else [30,27]
		world.player=world._safe_point(Vector2(spawn[0],spawn[1])); world.navigate(Vector2(e.point[0],e.point[1]))
		check.call(not world.walking_path.is_empty(),"从所属地区出生点有实际寻路路径抵达入口："+e.id)
		world.stop()
		world.player=Vector2(e.point[0],e.point[1]); world._update_camera(); await tree.process_frame; await tree.process_frame
		world.town_life.process(.25)
		check.call(e.id in scene.session.tasks.ledger.entrances,"近距离且可见通路发现正确入口："+e.id)
		check.call(not scene.session.tasks.accepted("expeditions:"+e.region),"发现只发布、不自动接取："+e.id)
		if int(e.index)>0: scene.session.state.scene_progress[e.requires]=true
		check.call(scene.session.visit(e.scene)=="","十五入口逐一能进入："+e.id)
		check.call(scene.session.story.return_scene()==e.region,"子地图返回所属地区："+e.id)
		scene.session.visit(e.region)
		check.call(Vector2(scene.session.state.location.x,scene.session.state.location.y).distance_to(Vector2(e.point[0],e.point[1]))<.01,"返回落点绑定对应入口："+e.id)
	var drain=scene.session.tasks.entrance_for("town-drain")
	check.call(drain.region=="town" and drain.point==[22.5,14.0] and drain.building=="","旧渠检修口与月沼紫晶地牢完全分离")
	scene.session.state.location={"scene":"town","x":30.0,"y":27.0}; world.scene_id=""; world.show_location(); world.blocked=false
	var animal=world.town_life.animals[0]; var initial=animal.target.point
	world.town_life.process(3); world.town_life.process(.5)
	check.call(animal.target.point!=initial and animal.target.point.distance_to(animal.home)<.81,"动物短距离巡游，交互点随实际位置更新")
	world.blocked=true; initial=animal.target.point; world.town_life.process(10)
	check.call(initial==animal.target.point,"菜单打开暂停动物巡游")
	scene.session.state.phase=3; world.scene_id=""; world.show_location()
	check.call(world.targets.filter(func(t): return t.kind=="town-life").size()==15,"深夜六动物、五资源点与四任务物仍可交互")
	var same_scene=scene.session.state.duplicate(true); same_scene.location={"scene":"town","x":30.0,"y":27.0}; same_scene.task_state.town["herb-1"]=true
	scene.session.load_state(same_scene); world.show_location()
	check.call(world.player==Vector2(30,27) and world.targets.filter(func(t): return t.id=="herb-1")[0].node.modulate.a<.5,"同地图读档也恢复存档落点与已采集标记")
	same_scene.task_state.town.erase("herb-1"); scene.session.load_state(same_scene); world.show_location()
	check.call(world.targets.filter(func(t): return t.id=="herb-1")[0].node.modulate.a==1,"同地图切换存档会清除另一档残留的资源外观")
	# Exact target, acceptance time, training exclusion, event identity and delivery.
	g=GameSession.new(db); g.new_game(); g.tasks.discover("entrance-town-wall"); g.visit("room-guildhall")
	g.tasks.event("battle","town-wall","","before-accept"); g.tasks.accept("battle:patrol","board")
	check.call(g.tasks.stage("battle:patrol")==0,"接取前战斗不追溯")
	g.tasks.event("battle","town-drain","","wrong-scene")
	check.call(g.tasks.stage("battle:patrol")==0,"错误地区不会推进同类战斗委托")
	g.enter_training("warden",[],6); g.tasks.event("battle","town-wall","","training"); g.exit_training()
	check.call(g.tasks.stage("battle:patrol")==0,"训练与觉醒试炼不计入委托")
	g.tasks.event("battle","town-wall","","patrol-win"); g.tasks.event("battle","town-wall","","patrol-win")
	check.call(g.tasks.stage("battle:patrol")==1 and g.tasks.status("battle:patrol")=="ready","普通胜利只推进一次并等待返回交付")
	gold=g.state.gold; g.tasks.turn_in("battle:patrol","board")
	check.call(g.state.gold==gold+15,"战斗委托回板领取固定奖励")
	g.tasks.accept("expeditions:town","board")
	g.tasks.event("survey","town-drain","survey"); g.tasks.event("survey","town-wall","other")
	check.call(g.tasks.stage("expeditions:town")==0,"连续调查绑定具体场景与具体调查物，不能跳段")
	for route in db.route_ids("town"): g.tasks.event("survey",route,"survey")
	check.call(g.tasks.status("expeditions:town")=="ready","五份连续调查沿用三段目标并等待交付")
	g.state.chapter_complete=true; g.state.story.awakenings.hero={"stage":3,"clues":[0,1],"order":3}
	scene.session.load_state(g.state); scene.mode="world"; scene.open_menu("journal"); await tree.process_frame; await tree.process_frame
	var buttons=nodes(scene.overlay_root).filter(func(n): return n is Button)
	var awakening_row=buttons.filter(func(b): return b.text.contains(db.progression.ultimates.hero.title))[0]
	var main_row=buttons.filter(func(b): return b.text.contains(db.narrative.quests.stars.name))[0]
	check.call(awakening_row.global_position.y<main_row.global_position.y,"试炼完成的觉醒故事也按可交付任务排在进行中主线之前")
	check.call(buttons.any(func(b): return b.text.begins_with("已完成（")),"日志把完成任务折叠收纳在列表底部")
	check.call(buttons.filter(func(b): return b.has_meta("selected") and b.get_meta("selected")).size()<=2,"日志分类与业务列表保持单一选中")
	scene.open_menu("commission-board"); await tree.process_frame
	check.call(nodes(scene.overlay_root).filter(func(n): return n is Button and n.text in ["全部","战斗","居民","采集","探索"]).size()==5,"专用委托板具有五个分类")
	scene.close_menu(); scene.queue_free(); await tree.process_frame
	tree.results.append("任务生命周期：明确接取、材料原子交付、六份儿童委托、五资源点、十五真实入口、精确推进、旧档备份与完成归档")

func nodes(root: Node) -> Array:
	var result=[]
	for child in root.get_children(): result.append(child); result.append_array(nodes(child))
	return result
