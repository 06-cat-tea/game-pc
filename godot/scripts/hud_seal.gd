class_name HUDSeal
extends Button

var key_label=""
var art: Texture2D
var caption_text=""

func setup(symbol: String, caption: String, shortcut: String, callback: Callable):
	key_label=shortcut; caption_text="终端" if caption=="旅人终端" else caption
	art=UIkit.texture("res://assets/ui/hud-filled/"+{"main-quest":"quest","affinity":"party","menu":"terminal"}.get(symbol,symbol)+".svg"); size=Vector2(92,106)
	tooltip_text=caption+" · "+shortcut; accessibility_name=tooltip_text
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	pressed.connect(callback)
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw); button_down.connect(queue_redraw); button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

func _draw():
	var center=Vector2(43,32)+Vector2(0,1 if is_pressed() else 0)
	var active=is_hovered() or has_focus()
	if active: draw_circle(center,30,Color(UIkit.NIGHT,.55))
	if art!=null:
		draw_texture_rect(art,Rect2(center-Vector2(25,23)+Vector2(1,2),Vector2(50,46)),false,Color(0,0,0,.38))
		draw_texture_rect(art,Rect2(center-Vector2(25,23),Vector2(50,46)),false)
	draw_string(UIkit.hud_font(),Vector2(0,85),caption_text,HORIZONTAL_ALIGNMENT_LEFT,44,20,UIkit.IVORY)
	var box=Rect2(49,66,34,25); draw_style_box(UIkit.button_style(Color("26333c"),Color("d5c29c"),5),box)
	draw_string(UIkit.hud_font(),Vector2(55,85),key_label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("f5e7cb"))
