class_name HUDSeal
extends Button

var key_label=""
var art: Texture2D

func setup(symbol: String, caption: String, shortcut: String, callback: Callable):
	key_label=shortcut; art=UIkit.icon(symbol); size=Vector2(68,74)
	tooltip_text=caption+" · "+shortcut; accessibility_name=tooltip_text
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	pressed.connect(callback)
	mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw); button_down.connect(queue_redraw); button_up.connect(queue_redraw)
	focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)

func _draw():
	var center=Vector2(34,32)+Vector2(0,1 if is_pressed() else 0)
	var active=is_hovered() or has_focus()
	draw_circle(center+Vector2(0,3),29,Color(0.04,0.08,0.11,.16))
	draw_circle(center,29,Color("e6dac1") if is_pressed() else Color("fff8e9") if active else Color("f3efe4"))
	draw_arc(center,28,0,TAU,64,Color("c0a46c") if active else Color("cabfa6"),1.5,true)
	draw_arc(center,23,-PI*.9,-PI*.15,32,Color("d8c59a"),.7,true)
	if art!=null: draw_texture_rect(art,Rect2(center-Vector2(13,13),Vector2(26,26)),false,UIkit.INK)
	var box=Rect2(41,52,30,21); draw_style_box(UIkit.button_style(Color("26333c"),Color("d5c29c"),4),box)
	draw_string(UIkit.font(),Vector2(46,68),key_label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f5e7cb"))
