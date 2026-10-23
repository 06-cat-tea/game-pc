class_name RailDialogue
extends Control

var game
var pages=[]
var page_index=0
var letters=0.0
var caption: Label
var choice_root: VBoxContainer
var advance_button: Button
var choice_buttons=[]
var completed=false
var choice_callback: Callable
var portrait_view: TextureRect
var speaker_label: Label

func setup(owner, speaker: String, portrait: String, lines: Array, options: Array, callback: Callable):
	game=owner; choice_callback=callback; UIkit.fill(self); mouse_filter=Control.MOUSE_FILTER_STOP; focus_mode=Control.FOCUS_ALL
	UIkit.card(self,Vector2.ZERO,Vector2(1920,1080),Color(0.25,0.28,0.30,0.12),Color.TRANSPARENT)
	portrait_view=UIkit.art(self,portrait,Vector2(220,130),Vector2(740,730))
	UIkit.text(self,"人物交谈",Vector2(64,48),Vector2(500,50),28,UIkit.GOLD)
	UIkit.action(self,"返回 · Esc",Vector2(1640,48),Vector2(216,54),game.back_menu)
	choice_root=UIkit.scroll_at(self,Vector2(1160,260),Vector2(670,460))
	UIkit.gradient(self,Vector2(0,724),Vector2(1920,356))
	UIkit.rule(self,Vector2(180,802),1560,UIkit.GOLD)
	speaker_label=UIkit.text(self,speaker,Vector2(180,821),Vector2(1340,45),29,UIkit.GOLD)
	caption=UIkit.text(self,"",Vector2(180,877),Vector2(1510,134),28)
	advance_button=UIkit.action(self,"",Vector2(1640,1005),Vector2(200,48),advance)
	UIkit.text(self,"点击文字或按 Enter 继续",Vector2(180,1025),Vector2(700,35),18,UIkit.MUTED)
	update_content(speaker,portrait,lines,options,callback)

func update_content(speaker: String, portrait: String, lines: Array, options: Array, callback: Callable):
	# Keep the dialogue shell and portrait node alive across questions and replies.
	pages=[]; page_index=0; letters=0; completed=false; choice_callback=callback
	for line in lines:
		var value=str(line)
		while value.length()>100:
			pages.append(value.left(100)); value=value.substr(100)
		pages.append(value)
	if pages.is_empty(): pages=["……"]
	speaker_label.text=speaker
	var source=UIkit.texture(portrait)
	if "/static-v2/" in portrait and source!=null:
		var crop=AtlasTexture.new(); crop.atlas=source; crop.region=Rect2(0,0,source.get_width(),source.get_height()*0.70)
		portrait_view.texture=crop
	else: portrait_view.texture=source
	for child in choice_root.get_children(): choice_root.remove_child(child); child.queue_free()
	choice_buttons=[]
	for index in options.size():
		var entry=options[index]
		var node=UIkit.button(choice_root,"◇  "+str(entry.text),func(): choose(index),entry.get("disabled",false))
		node.add_theme_stylebox_override("normal",UIkit.style(Color(0.96,0.95,0.92,0.93)))
		node.add_theme_stylebox_override("disabled",UIkit.style(Color(0.96,0.95,0.92,0.62)))
		node.alignment=HORIZONTAL_ALIGNMENT_LEFT; node.custom_minimum_size.y=64; node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		node.set_meta("choice_disabled",entry.get("disabled",false)); choice_buttons.append(node)
	_show_page()

func _show_page():
	caption.text=pages[page_index]; letters=0; caption.visible_characters=0
	advance_button.text="继续  ▷" if page_index<pages.size()-1 else "显示全文  ▷"
	_update_choices()

func _update_choices():
	var ready=page_index==pages.size()-1 and caption.visible_characters>=caption.text.length()
	for node in choice_buttons: node.disabled=not ready or node.get_meta("choice_disabled") or completed
	if ready: advance_button.text="等待选择" if not choice_buttons.is_empty() else "返回  ▷"

func _process(delta: float):
	if caption==null or caption.visible_characters>=caption.text.length(): return
	letters+=delta*32; caption.visible_characters=mini(int(letters),caption.text.length()); _update_choices()

func advance():
	if caption.visible_characters<caption.text.length():
		caption.visible_characters=caption.text.length(); letters=caption.text.length(); _update_choices()
	elif page_index<pages.size()-1: page_index+=1; _show_page()
	elif choice_buttons.is_empty(): game.back_menu()

func choose(index: int):
	if completed or page_index!=pages.size()-1 or caption.visible_characters<caption.text.length(): return
	if index<0 or index>=choice_buttons.size() or choice_buttons[index].disabled: return
	completed=true
	for node in choice_buttons: node.disabled=true
	choice_callback.call(index)

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and event.position.y>800:
		# Advancing may remove this control; finish input dispatch before navigation.
		accept_event(); advance()

func _unhandled_key_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER,KEY_SPACE]:
		get_viewport().set_input_as_handled(); advance()
