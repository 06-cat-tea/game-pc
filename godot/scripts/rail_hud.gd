class_name RailHUD
extends RefCounted

var game

func _init(owner): game=owner

func title(parent: Control):
	game.background(parent,game.db.raw.art.title,0.0)
	UIkit.gradient(parent,Vector2.ZERO,Vector2(1350,1080),true,true)
	UIkit.art(parent,"res://assets/ui/branding/logo.svg",Vector2(108,155),Vector2(104,104))
	_text(parent,"ASHEN FRONTIER",Vector2(236,179),Vector2(600,45),28,UIkit.GOLD)
	UIkit.rule(parent,Vector2(240,239),104,UIkit.GOLD)
	_text(parent,"灰烬边境",Vector2(100,283),Vector2(840,140),100)
	_text(parent,"星 陨 纪 事",Vector2(110,439),Vector2(730,85),45,UIkit.GOLD)
	_text(parent,"六地归途 · 完整星钟故事",Vector2(110,555),Vector2(680,55),28)
	_text(parent,"在钟声与雾中，寻找你的归路。",Vector2(110,617),Vector2(680,50),23,UIkit.MUTED)
	UIkit.action(parent,"继续旅程  →",Vector2(110,717),Vector2(540,70),game.load_continue,true,not FileAccess.file_exists(game.store.path_for(0)) and not FileAccess.file_exists(game.store.path_for(0)+".bak"))
	UIkit.action(parent,"开始新的旅程",Vector2(110,807),Vector2(540,64),func(): game.open_menu("new"))
	UIkit.action(parent,"读取 / 导入存档",Vector2(110,891),Vector2(540,58),func(): game.open_menu("saves"))
	if not BrowserFileBridge.is_browser(): UIkit.icon_button(parent,"close","离开游戏",Vector2(1796,52),func(): game.get_tree().quit())
	_text(parent,"WASD 移动   /   SHIFT 奔跑   /   "+GameBindings.label("interact")+" 交互",Vector2(110,1025),Vector2(1000,30),18,UIkit.INK)
	_text(parent,"灰烬边境 · 浏览器版" if BrowserFileBridge.is_browser() else "灰烬边境 · 原生电脑版",Vector2(1400,1025),Vector2(440,30),18,UIkit.INK).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func world(parent: Control):
	var s=game.session.state; var scene_id=s.location.scene
	var map=RailMap.new(); map.position=Vector2(52,56); map.size=Vector2(190,190); parent.add_child(map); map.setup(game,true)
	_text(parent,game.db.location_title(scene_id),Vector2(269,74),Vector2(630,56),33)
	_text(parent,"第 %d 日  /  %s" % [s.day,["清晨","正午","黄昏","深夜"][s.phase]],Vector2(270,142),Vector2(500,40),22,UIkit.GOLD)
	UIkit.rule(parent,Vector2(270,201),230,Color(0.9,0.85,0.7,0.5))
	var objective="调查三条路线，查明第十三声钟响。" if not s.chapter_complete else "首章已完成 · 下一站：低语森林"
	if game.db.regions.has(scene_id): objective="沿路探索地标 · 打开地图规划旅程"
	if s.chapter_complete: objective=game.session.story.greeting("mira").get_slice("。",1)
	if s.story.events.get("epilogue",false): objective="归灯已亮 · 继续记录六地的名字与故事"
	var title="◇  星钟谜语" if s.chapter_complete else "◇  自由探索" if game.db.regions.has(scene_id) else "◇  归路与星钟"
	var tracked=str(s.task_state.get("tracked",""))
	if game.session.tasks.accepted(tracked) and game.session.tasks.status(tracked)!="completed":
		var d=game.session.tasks.definition(tracked); var target=game.session.tasks.target(tracked)
		title="◇  "+d.name
		objective="寻找当地入口线索。" if target.get("unknown",false) else ("返回交付 · " if game.session.tasks.status(tracked)=="ready" else "目标地点 · ")+game.db.location_title(target.get("scene",scene_id))
	_text(parent,title,Vector2(64,282),Vector2(520,44),26,UIkit.GOLD)
	_text(parent,objective,Vector2(92,336),Vector2(430,90),22)
	var entries=[["main-quest","任务","journal"],["backpack","背包","inventory"],["character","角色","character"],["affinity","队伍","party"],["menu","旅人终端","terminal"]]
	for i in entries.size():
		var kind=entries[i][2]; var entry=HUDSeal.new(); parent.add_child(entry); entry.position=Vector2(1450+i*84,52)
		entry.setup(entries[i][0],entries[i][1],GameBindings.label(kind),func(): game.open_menu(kind))
	for i in s.active.size():
		var id=s.active[i]; var member=s.members[id]; var stats=PartyMemberState.stats(member,s,game.db)
		var panel=UIkit.canvas(parent,Vector2(1590,262+i*116),Vector2(280,100))
		UIkit.art(panel,game.db.art("portraits",id,"avatar"),Vector2(203,8),Vector2(68,68))
		_text(panel,game.db.actors[id].display_name,Vector2(12,10),Vector2(184,32),21)
		var hp=UIkit.bar(panel,member.hp,stats.max_hp); hp.position=Vector2(12,58); hp.size=Vector2(178,5)
		var mp=UIkit.bar(panel,member.mp,stats.max_mp,true); mp.position=Vector2(12,69); mp.size=Vector2(178,3)
		_world_bar(hp,false); _world_bar(mp,true)
		var tp=UIkit.bar(panel,member.get("tp",0),100); tp.position=Vector2(12,74); tp.size=Vector2(178,3); tp.add_theme_stylebox_override("fill",UIkit.meter(UIkit.GOLD))
		_text(panel,"倒地" if member.hp<=0 else "Lv.%d · TP %d" % [member.level,member.get("tp",0)],Vector2(12,78),Vector2(180,22),15,UIkit.MUTED)
		var hit=UIkit.action(panel,"",Vector2.ZERO,Vector2(280,98),func(): game.open_menu("character",id)); hit.add_theme_stylebox_override("normal",UIkit.button_style(Color.TRANSPARENT,Color.TRANSPARENT)); hit.add_theme_stylebox_override("hover",UIkit.button_style(Color(1,1,1,0.04),Color.TRANSPARENT)); hit.tooltip_text="查看 "+game.db.actors[id].display_name
	var hero=s.members.hero; var stats=PartyMemberState.stats(hero,s,game.db)
	_text(parent,"旅人   Lv.%d" % hero.level,Vector2(725,936),Vector2(470,37),23)
	var hp=UIkit.bar(parent,hero.hp,stats.max_hp); hp.position=Vector2(725,982); hp.size=Vector2(470,7)
	var mp=UIkit.bar(parent,hero.mp,stats.max_mp,true); mp.position=Vector2(725,997); mp.size=Vector2(470,4)
	_world_bar(hp,false); _world_bar(mp,true)
	_text(parent,"%d / %d     ·     MP %d / %d" % [hero.hp,stats.max_hp,hero.mp,stats.max_mp],Vector2(725,1012),Vector2(470,30),18,UIkit.INK)
	var interact=UIkit.action(parent,GameBindings.label("interact")+"  附近行动",Vector2(1550,881),Vector2(320,66),func(): game.open_menu("actions"))
	interact.add_theme_stylebox_override("normal",UIkit.button_style(Color(0.96,0.95,0.92,0.9),Color.TRANSPARENT))
	UIkit.icon_button(parent,"map","地图",Vector2(1798,965),func(): game.open_menu("map"))
	game.hud_hint=_text(parent,game.hint,Vector2(64,951),Vector2(610,94),21,UIkit.GOLD)
	_text(parent,"TAB  快捷轮盘   /   ESC  终端",Vector2(1425,1030),Vector2(445,30),18,UIkit.INK)
	if s.training: UIkit.action(parent,"退出训练",Vector2(64,856),Vector2(280,62),game.exit_training)

func _text(parent: Node, value: String, point: Vector2, dimensions: Vector2, font_size: int = 23, color: Color = UIkit.INK) -> Label:
	if game.mode=="world": color=Color("f4e5bb") if color==UIkit.GOLD else Color("ecece8")
	var node=UIkit.text(parent,value,point,dimensions,font_size,color)
	node.add_theme_color_override("font_shadow_color",Color(0.07,0.1,0.11,0.96) if game.mode=="world" else Color(0.98,0.97,0.93,0.9)); node.add_theme_constant_override("shadow_offset_x",0); node.add_theme_constant_override("shadow_offset_y",1); node.add_theme_constant_override("shadow_outline_size",3)
	return node

func _world_bar(node: ProgressBar, mana: bool):
	node.add_theme_stylebox_override("fill",UIkit.meter(Color("8bb8e0") if mana else Color("9bd8b6")))
	node.add_theme_stylebox_override("background",UIkit.meter(Color(0.06,0.12,0.10,0.75)))
