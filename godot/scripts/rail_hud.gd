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
	ExplorationHUD.new(game).build(parent)

func _text(parent: Node, value: String, point: Vector2, dimensions: Vector2, font_size: int = 23, color: Color = UIkit.INK) -> Label:
	if game.mode=="world": color=Color("f4e5bb") if color==UIkit.GOLD else Color("ecece8")
	var node=UIkit.text(parent,value,point,dimensions,font_size,color)
	if game.mode=="world":
		node.add_theme_color_override("font_outline_color",Color("192730")); node.add_theme_constant_override("outline_size",3)
	node.add_theme_color_override("font_shadow_color",Color(0.07,0.1,0.11,0.96) if game.mode=="world" else Color(0.98,0.97,0.93,0.9)); node.add_theme_constant_override("shadow_offset_x",0); node.add_theme_constant_override("shadow_offset_y",1); node.add_theme_constant_override("shadow_outline_size",3)
	return node

func _world_bar(node: ProgressBar, mana: bool):
	node.add_theme_stylebox_override("fill",UIkit.meter(Color("8bb8e0") if mana else Color("9bd8b6")))
	node.add_theme_stylebox_override("background",UIkit.meter(Color(0.06,0.12,0.10,0.75)))
