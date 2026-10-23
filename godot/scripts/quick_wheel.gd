class_name QuickWheel
extends Control

# One table and one selected index drive both the drawing and the committed action.
const ENTRIES = [
	{"id":"inventory", "name":"背包", "icon":"backpack"},
	{"id":"journal", "name":"任务", "icon":"main-quest"},
	{"id":"party", "name":"队伍", "icon":"affinity"},
	{"id":"skills", "name":"技能", "icon":"skills"},
	{"id":"craft", "name":"工坊", "icon":"crafting"},
	{"id":"map", "name":"地图", "icon":"map"},
	{"id":"rest", "name":"休息", "icon":"rest"},
	{"id":"settings", "name":"设置", "icon":"settings"},
]
const DEAD_ZONE = 85.0
const RING_RADIUS = 200.0
const OUTER_RADIUS = 260.0
var selected_index = -1
var submitted = false
var icons: Array[TextureRect] = []
var caption: Label
var instruction: Label
var cancel_hint: Label

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	for entry in ENTRIES:
		var icon = TextureRect.new()
		icon.texture = UIkit.icon(entry.icon)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(38,38)
		icon.pivot_offset = icon.size*0.5
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon); icons.append(icon)
	caption = UIkit.text(self,"移动鼠标选择",Vector2.ZERO,Vector2(260,46),26)
	instruction = UIkit.text(self,"快捷轮盘",Vector2.ZERO,Vector2(260,32),18,UIkit.MUTED)
	cancel_hint = UIkit.text(self,"中央松开取消   ·   Esc 返回",Vector2.ZERO,Vector2(500,34),18,Color("eee9dd"))
	for label in [caption,instruction,cancel_hint]: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resized.connect(_layout)
	_layout()

func center() -> Vector2:
	return size * 0.5

func _layout():
	for i in icons.size():
		icons[i].position = center() + Vector2.from_angle(i*TAU/8.0-PI/2)*RING_RADIUS - icons[i].size*0.5
	caption.position = center() + Vector2(-130,-34)
	instruction.position = center() + Vector2(-130,18)
	cancel_hint.position = center() + Vector2(-250,282)
	queue_redraw()

func begin_hold():
	submitted = false
	select_at(center())
	# Viewport.warp_mouse applies the window's stretch and letterbox transform.
	# Preview SubViewports and headless tests must not move the desktop cursor.
	if get_viewport() is Window and DisplayServer.get_name() != "headless" and not BrowserFileBridge.is_browser():
		get_viewport().warp_mouse(get_global_transform_with_canvas() * center())

func select_at(point: Vector2):
	if submitted: return
	var offset = point - center()
	var index = -1
	if offset.length() >= DEAD_ZONE:
		index = int(floor(fposmod(offset.angle()+PI/2+PI/8,TAU)/(TAU/8)))
	if index == selected_index: return
	selected_index = index
	caption.text = "移动鼠标选择" if index < 0 else ENTRIES[index].name
	instruction.text = "快捷轮盘" if index < 0 else "松开 Tab 执行"
	for i in icons.size():
		icons[i].modulate = Color.WHITE if i == index else Color(1,1,1,0.75)
		icons[i].scale = Vector2.ONE*(1.12 if i == index else 1.0)
	queue_redraw()

func track_pointer(event: InputEventMouseMotion):
	select_at(get_global_transform_with_canvas().affine_inverse() * event.position)

func take_selection() -> int:
	if submitted: return -1
	submitted = true
	return selected_index

func _gui_input(_event: InputEvent):
	# Tab release is the only commit path. Clicks cannot execute an action twice
	# or reach the exploration HUD behind the wheel.
	accept_event()

func _draw():
	var c = center()
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.055,0.07,0.085,0.24))
	draw_circle(c+Vector2(0,5),OUTER_RADIUS,Color(0.06,0.08,0.10,0.12))
	draw_arc(c,RING_RADIUS,0,TAU,128,Color(UIkit.PAPER,0.97),96,true)
	draw_arc(c,249,0,TAU,128,Color(UIkit.ACCENT,0.6),1.5,true)
	draw_arc(c,151,0,TAU,128,Color(UIkit.LINE,0.75),1,true)
	draw_circle(c,109,Color(UIkit.PAPER,0.98))
	draw_arc(c,109,0,TAU,96,Color(UIkit.ACCENT,0.6),1,true)
	if selected_index >= 0:
		var angle = selected_index*TAU/8.0-PI/2
		draw_arc(c,RING_RADIUS,angle-PI/8+0.035,angle+PI/8-0.035,24,Color("e8dbc1"),94,true)
		draw_arc(c,249,angle-PI/8+0.035,angle+PI/8-0.035,24,UIkit.GOLD,3,true)
	for i in 8:
		var angle = i*TAU/8.0-PI/2+PI/8
		draw_line(c+Vector2.from_angle(angle)*179,c+Vector2.from_angle(angle)*221,Color(UIkit.LINE,0.65),1,true)
