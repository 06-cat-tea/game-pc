class_name ProgressionPages
extends RefCounted

var game
func _init(owner): game=owner

func build(kind: String, subject: String) -> bool:
	match kind:
		"awakening": awakening(subject)
		"awakening-log": overview()
		"building-service": building(subject)
		"building-log": buildings()
		_: return false
	return true

func overview():
	var entries=[]
	for id in game.db.progression.ultimates:
		var d=game.db.progression.ultimates[id]
		entries.append(game.menus.story_pages._entry(id,game.db.actors[id].display_name+" · "+d.name,d.title+"\n\n"+game.session.progression.status(id)+"\n\n"+d.desc,"觉醒", "","查看故事",func(): game.open_menu("awakening",id)))
	game.menus.story_pages.collection("awakening-log","七枚归灯纹章",entries,["全部","觉醒"])

func buildings():
	var entries=[]
	for id in game.db.progression.buildings:
		var site=game.db.progression.buildings[id]; var name=game.db.building(id).name
		entries.append(game.menus.story_pages._entry(id,name,site.name+"\n\n"+"\n\n".join(site.details.map(func(d): return d.name+"："+d.detail)),game.db.location_title(site.place),"","查看建筑用途",func(): game.open_menu("building-service",id)))
	game.menus.story_pages.collection("building-log","六地见闻",entries,["全部","晨星镇","低语森林","余烬峡道","月沼遗境","风葬海崖","归灯王城"])

func awakening(id: String):
	if not game.db.progression.ultimates.has(id): return
	var d=game.db.progression.ultimates[id]; var runtime=game.session.progression; var stage=int(runtime.record(id).stage)
	var root=game.menus.pages.shell(d.title)
	UIkit.art(root,game.db.art("portraits",id,"smile" if stage==4 else "serious"),Vector2(30,2),Vector2(640,760))
	var body=UIkit.scroll_at(root,Vector2(744,12),Vector2(1018,750))
	UIkit.label(body,game.db.actors[id].display_name+"  /  角色觉醒",24,UIkit.GOLD)
	UIkit.label(body,d.name,42,UIkit.GOLD); UIkit.label(body,d.desc,27)
	UIkit.label(body,runtime.status(id),25)
	UIkit.label(body,"故事地点："+game.db.raw.scenes[d.scene].title,24,UIkit.MUTED)
	if stage==4:
		UIkit.label(body,"TP %d / 100 · Q 选择大招，Enter 确认\n战后与休息保留 TP，倒地清零。" % game.session.state.members[id].get("tp",0),24)
		for line in d.closing: UIkit.label(body,line,24,UIkit.MUTED)
		return
	if game.session.state.location.scene!=d.scene:
		UIkit.button(body,"前往故事地点",func(): await game.travel_to(d.scene),game.session.state.battle!=null or game.session.state.training)
	if stage==0:
		UIkit.label(body,d.intro[0],26)
		UIkit.button(body,"聆听这段故事",func(): dialogue(id,false),not runtime.available(id) or game.session.state.location.scene!=d.scene or game.session.state.training)
	elif stage in [1,2]:
		for clue in d.clues:
			var known=int(clue.clue) in runtime.record(id).clues
			UIkit.button(body,("✓ 已调查 · " if known else "◇ 寻找 · ")+clue.name,func(): game.seek(d.scene,"prop",clue.id))
		if stage==2:
			UIkit.label(body,"试炼使用临时六级队伍与 100 TP。选择大招后仍需确认；离开完整恢复原队伍与物资。",23,UIkit.MUTED)
			UIkit.button(body,"进入觉醒试炼",func():
				var error=runtime.begin_trial(id)
				if error!="": game.toast(error); return
				game.paused=false; game.close_menu(); game.mode="battle"; game.refresh(); game.toast("临时 Lv.6 试炼 · Q 选择大招 / Enter 确认"),game.session.state.location.scene!=d.scene)
	elif stage==3: UIkit.button(body,"完成归灯的交谈",func(): dialogue(id,true),game.session.state.location.scene!=d.scene)

func dialogue(id: String, closing: bool):
	var d=game.db.progression.ultimates[id]
	game.overlay="message"; game.world.blocked=true; game.main_view.visible=false
	game.message_back={"kind":"awakening","subject":id}
	game.show_dialogue(game.db.actors[id].display_name,game.db.art("portraits",id,"smile" if closing else "serious"),d.closing if closing else d.intro,[{"text":"让归灯记住这一刻" if closing else "记下线索，回应这道回响"}],func(_index):
		var text=game.session.progression.complete(id) if closing else game.session.progression.begin(id)
		game.world.scene_id=""; game.toast(text); game.replace_menu("awakening",id))

func building(id: String):
	if not game.db.progression.buildings.has(id): return
	var site=game.db.progression.buildings[id]; var runtime=game.session.progression
	var root=game.menus.pages.shell(game.db.building(id).name)
	var body=UIkit.scroll_at(root,Vector2(36,12),Vector2(1712,760))
	UIkit.label(body,game.db.location_title(site.place)+"  /  六地见闻",23,UIkit.GOLD)
	UIkit.label(body,site.name,38,UIkit.GOLD)
	if not runtime.at_site(id): UIkit.button(body,"前往「"+game.db.raw.scenes[site.scene].title+"」",func(): await game.travel_to(site.scene))
	for detail in site.details:
		UIkit.label(body,detail.name,25,UIkit.GOLD); UIkit.label(body,detail.detail,23)
	var done=game.session.state.story.building_services.get(id,false)
	if site.type in ["commission","order","research","clue"]:
		var text={"commission":"交付材料","order":"完成首份订单","research":"完成研究记录","clue":"记录线索与地图指引"}[site.type]
		if site.type=="commission": UIkit.label(body,"需要%s %d · 金币 %d / 旅人经验 %d · 一次性" % ["草药" if site.material=="herb" else "矿石",site.amount,site.gold,site.xp],24)
		elif site.type=="order": UIkit.label(body,"巡路者短刃 · 矿石 2 · 成品归你所有，首份额外经验 10；已有制作记录可追认。",24)
		elif site.type=="research": UIkit.label(body,"一次性获得旅人经验 15 与地点线索。",24)
		if done: UIkit.label(body,"✧ 已完成 · 记录留在旅途档案",25,UIkit.GOLD)
		elif site.type!="clue" and not game.session.tasks.accepted("service:"+id):
			UIkit.button(body,"接取 · "+site.name,func(): game.toast(game.session.tasks.accept("service:"+id,"service:"+id)); game.refresh_menu(),not runtime.at_site(id))
		else:
			var status=game.session.tasks.status("service:"+id) if site.type!="clue" else "active"
			UIkit.button(body,"交付并领取奖励" if status=="ready" else text,func(): game.toast(runtime.use_service(id)); game.refresh_menu(),not runtime.at_site(id) or game.session.state.training or game.session.state.battle!=null)
		if id=="guildhall": UIkit.button(body,"打开公会委托板",func(): game.open_menu("commission-board"))
	if site.type=="training":
		UIkit.label(body,"免费演练：临时六级队伍，可试用 TP 与大招，无持久奖励。",24)
		UIkit.button(body,"进入沙盘演练",func():
			game.toast(game.session.enter_training(game.session.state.members.hero.job,["mira","toren","eira"],6)); game.world.scene_id=""; game.close_menu(); game.refresh(); game.open_menu("training"),not runtime.at_site(id) or game.session.state.training)
	for who in game.db.progression.ultimates:
		if game.db.progression.ultimates[who].building==id and runtime.available(who) and not runtime.unlocked(who):
			UIkit.button(body,"觉醒故事 · "+game.db.actors[who].display_name,func(): game.open_menu("awakening",who))
	if site.type=="archive": UIkit.button(body,"翻阅七人的觉醒档案",func(): game.open_menu("awakening-log"))
