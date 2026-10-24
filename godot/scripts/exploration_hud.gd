class_name ExplorationHUD
extends RefCounted

const CREAM=Color("fff3d8")
const GOLD=Color("e4cb8d")
const SHADOW=Color("17221f")
var game

func _init(owner): game=owner

func build(parent: Control):
	parent.set_meta("starlit_dark",true)
	_shade(parent,Vector2.ZERO,Vector2(1920,210),false,false,.35)
	_shade(parent,Vector2(0,890),Vector2(1920,190),false,true,.62)
	_shade(parent,Vector2(0,268),Vector2(590,152),true,false,.32)
	var s=game.session.state
	var map=RailMap.new(); map.position=Vector2(33,25); map.size=Vector2(230,230); parent.add_child(map); map.setup(game,true)
	_glyph(parent,"star",Vector2(286,52),Vector2(36,36))
	_text(parent,game.db.location_title(s.location.scene),Vector2(329,43),Vector2(560,54),34)
	_glyph(parent,"rest" if s.phase==3 else "sun",Vector2(289,105),Vector2(29,29))
	_text(parent,"第 %d 日 · %s" % [s.day,["清晨","正午","黄昏","深夜"][s.phase]],Vector2(329,103),Vector2(450,42),25)
	var objective="调查城墙巡径，寻找星钟线索"
	var title="归路与星钟"
	if s.scene_progress.get("town-wall:survey",false): objective="调查旧城地下渠，带回星钟线索"
	if s.scene_progress.get("town-drain:survey",false): objective="完成公会试炼，查明星钟的回响"
	if s.chapter_complete: title="星钟谜语"; objective=game.session.story.greeting("mira").get_slice("。",1)
	if game.db.regions.has(s.location.scene): title="自由探索"; objective="沿路探索地标，记录当地见闻"
	if s.story.events.get("epilogue",false): title="归灯之后"; objective="继续记录六地的名字与故事"
	var tracked=str(s.task_state.get("tracked",""))
	if game.session.tasks.accepted(tracked) and game.session.tasks.status(tracked)!="completed":
		var d=game.session.tasks.definition(tracked); var target=game.session.tasks.target(tracked); title=d.name
		objective="寻找当地入口线索" if target.get("unknown",false) else ("返回交付 · " if game.session.tasks.status(tracked)=="ready" else "目标地点 · ")+game.db.location_title(target.get("scene",s.location.scene))
	_glyph(parent,"diamond",Vector2(37,280),Vector2(31,37))
	_text(parent,title,Vector2(79,277),Vector2(490,44),28)
	_text(parent,"✦",Vector2(46,328),Vector2(22,30),16,GOLD)
	_text(parent,objective,Vector2(79,327),Vector2(475,72),22)
	var entries=[["quest","任务","journal"],["backpack","背包","inventory"],["character","角色","character"],["party","队伍","party"],["terminal","旅人终端","terminal"]]
	for i in entries.size():
		var entry=entries[i]; var button=HUDSeal.new(); parent.add_child(button); button.position=Vector2(1377+i*106,18)
		button.setup(entry[0],entry[1],GameBindings.label(entry[2]),func(): game.open_menu(entry[2]))
	for i in s.active.size():
		var id=s.active[i]; var member=s.members[id]; var stats=PartyMemberState.stats(member,s,game.db)
		var row=UIkit.canvas(parent,Vector2(1655,170+i*124),Vector2(250,110))
		UIkit.card(row,Vector2(12,-5),Vector2(238,106),Color(.055,.075,.065,.18))
		UIkit.portrait(row,game.db.art("portraits",id,"avatar"),Vector2.ZERO,82)
		_glyph(row,"star",Vector2(-6,60),Vector2(24,24))
		var name="旅人" if id=="hero" else game.db.actors[id].display_name.get_slice("·",0).strip_edges()
		_text(row,name,Vector2(96,0),Vector2(151,33),23)
		_text(row,"Lv.%d" % member.level,Vector2(96,33),Vector2(151,26),20)
		_meter(row,member.hp,stats.max_hp,Vector2(96,63),Vector2(141,5),Color("91df79"))
		_meter(row,member.mp,stats.max_mp,Vector2(96,76),Vector2(141,3),Color("8bd6ee"))
		if game.session.progression.unlocked(id): _meter(row,member.get("tp",0),100,Vector2(96,86),Vector2(141,2),GOLD)
		var hit=UIkit.action(row,"",Vector2(-2,-5),Vector2(252,110),func(): game.open_menu("character",id))
		for state in ["normal","pressed","disabled"]: hit.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		hit.add_theme_stylebox_override("hover",UIkit.style(Color(1,1,1,.04)))
		hit.tooltip_text="查看 "+game.db.actors[id].display_name
	var hero=s.members.hero; var stats=PartyMemberState.stats(hero,s,game.db)
	_glyph(parent,"star",Vector2(732,988),Vector2(27,27))
	_text(parent,"旅人   Lv.%d" % hero.level,Vector2(780,959),Vector2(450,33),23)
	_meter(parent,hero.hp,stats.max_hp,Vector2(780,999),Vector2(450,7),Color("91df79"))
	_meter(parent,hero.mp,stats.max_mp,Vector2(780,1010),Vector2(450,3),Color("8bd6ee"))
	_text(parent,"HP  %d / %d" % [hero.hp,stats.max_hp],Vector2(780,1022),Vector2(255,30),20)
	var mana=_text(parent,"MP  %d / %d" % [hero.mp,stats.max_mp],Vector2(1030,1022),Vector2(200,30),20); mana.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for i in 4: _keycap(parent,["W","A","S","D"][i],Vector2(39+i*31,1016),Vector2(27,29))
	_text(parent,"移动",Vector2(169,1013),Vector2(59,35),20)
	_keycap(parent,"Shift",Vector2(250,1016),Vector2(63,29)); _text(parent,"奔跑",Vector2(324,1013),Vector2(60,35),20)
	_keycap(parent,"Tab",Vector2(406,1016),Vector2(54,29)); _text(parent,"快捷轮盘",Vector2(473,1013),Vector2(122,35),20)
	game.hud_hint=_text(parent,"" if game.hint.begins_with("WASD") else game.hint,Vector2(40,956),Vector2(600,42),21)
	var action=UIkit.action(parent,"",Vector2(1665,967),Vector2(226,61),func(): game.open_menu("actions"))
	for state in ["normal","hover","pressed","focus"]:
		var box=UIkit.button_style(Color(.10,.13,.12,.84 if state=="normal" else .96),GOLD,32); box.set_border_width_all(2 if state=="focus" else 1); action.add_theme_stylebox_override(state,box)
	action.tooltip_text="附近行动 · F"; action.accessibility_name=action.tooltip_text
	_glyph(action,"star",Vector2(15,22),Vector2(18,18))
	_keycap(action,"F",Vector2(43,17),Vector2(28,28),true)
	_text(action,"附近行动",Vector2(84,13),Vector2(132,40),23)
	if s.training: UIkit.action(parent,"退出训练",Vector2(40,880),Vector2(240,60),game.exit_training,true)

func _text(parent: Node,value: String,point: Vector2,dimensions: Vector2,font_size: int,color: Color=CREAM) -> Label:
	var node=UIkit.text(parent,value,point,dimensions,font_size,color)
	node.add_theme_font_override("font",UIkit.hud_font())
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,.9)); node.add_theme_constant_override("shadow_offset_x",1); node.add_theme_constant_override("shadow_offset_y",2)
	node.add_theme_color_override("font_outline_color",Color(SHADOW,.75)); node.add_theme_constant_override("outline_size",1)
	node.autowrap_mode=TextServer.AUTOWRAP_OFF if dimensions.y<=font_size*1.8 else TextServer.AUTOWRAP_WORD_SMART
	node.clip_text=true; node.size=dimensions; node.set_deferred("size",dimensions)
	return node

func _glyph(parent: Node,id: String,point: Vector2,dimensions: Vector2):
	UIkit.art(parent,"res://assets/ui/hud-filled/"+id+".svg",point,dimensions)

func _meter(parent: Node,value: float,maximum: float,point: Vector2,dimensions: Vector2,color: Color):
	var node=UIkit.bar(parent,value,maximum); node.custom_minimum_size=Vector2.ZERO
	var bg=StyleBoxFlat.new(); bg.bg_color=Color(.03,.075,.055,.86)
	var fill=StyleBoxFlat.new(); fill.bg_color=color
	node.add_theme_stylebox_override("background",bg); node.add_theme_stylebox_override("fill",fill)
	node.position=point; node.size=dimensions

func _keycap(parent: Node,value: String,point: Vector2,dimensions: Vector2,light: bool=false):
	var box=UIkit.card(parent,point,dimensions)
	box.add_theme_stylebox_override("panel",UIkit.style(CREAM if light else Color(.08,.12,.12,.76),GOLD if light else Color("d7d2be"),5))
	var label=_text(box,value,Vector2(0,-1),dimensions+Vector2(0,2),18,SHADOW if light else CREAM)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	if light: label.add_theme_constant_override("outline_size",0); label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)

func _shade(parent: Node,point: Vector2,dimensions: Vector2,horizontal: bool,reverse: bool,opacity: float):
	var ramp=Gradient.new(); ramp.colors=PackedColorArray([Color(.035,.06,.045,0),Color(.035,.06,.045,opacity)] if reverse else [Color(.035,.06,.045,opacity),Color(.035,.06,.045,0)])
	var texture_value=GradientTexture2D.new(); texture_value.gradient=ramp; texture_value.width=128; texture_value.height=128; texture_value.fill_to=Vector2(1,0) if horizontal else Vector2(0,1)
	var layer=TextureRect.new(); layer.texture=texture_value; layer.position=point; layer.size=dimensions; layer.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(layer)
