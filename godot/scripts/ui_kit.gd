class_name UIkit
extends RefCounted

static var image_cache: Dictionary = {}
static var hud_typeface: FontVariation

const GOLD = Color("856c40")
const ACCENT = Color("b69c6c")
const MUTED = Color("5b6671")
const INK = Color("27313b")
const PAPER = Color("f5f2eb")
const LINE = Color("d7d5ce")
const SELECTED = Color("eee5d1")
const HP = Color("41795e")
const MP = Color("4a759a")

const NIGHT = Color("202c42")
const IVORY = Color("f4eddf")
const PALE_GOLD = Color("dbc494")

static func is_dark(parent: Node) -> bool:
	var current=parent
	while current!=null:
		if current.has_meta("starlit_dark"): return current.get_meta("starlit_dark")
		current=current.get_parent()
	return false

static func ink(parent: Node, color: Color) -> Color:
	if not is_dark(parent): return color
	if color==INK: return IVORY
	if color==MUTED: return Color("b8c4d2")
	if color==GOLD: return PALE_GOLD
	return color

static func style(color: Color = Color.TRANSPARENT, border: Color = Color.TRANSPARENT, radius: int = 12) -> StyleBoxFlat:
	var box = StyleBoxFlat.new(); box.bg_color = color; box.border_color = border
	box.set_border_width_all(1); box.set_corner_radius_all(radius)
	box.content_margin_left = 18; box.content_margin_right = 18; box.content_margin_top = 12; box.content_margin_bottom = 12
	return box

static func theme() -> Theme:
	var result = Theme.new()
	result.default_font = font(); result.default_font_size = 23
	result.set_color("font_color","Label",INK)
	result.set_color("font_color","Button",INK); result.set_color("font_hover_color","Button",INK); result.set_color("font_pressed_color","Button",INK)
	result.set_color("font_disabled_color","Button",Color("92999b"))
	result.set_stylebox("normal","Button",style())
	result.set_stylebox("hover","Button",style(Color("eae7df"),LINE))
	result.set_stylebox("pressed","Button",style(SELECTED,ACCENT))
	result.set_stylebox("focus","Button",style(Color(0,0,0,0),GOLD))
	result.set_stylebox("disabled","Button",style(Color(0.6,0.6,0.6,0.06)))
	result.set_stylebox("panel","PanelContainer",style())
	result.set_stylebox("panel","Panel",style(PAPER,LINE)); result.set_stylebox("panel","PopupPanel",style(PAPER,LINE))
	result.set_stylebox("background","ProgressBar",meter(Color("ced2cc")))
	result.set_stylebox("fill","ProgressBar",meter(HP))
	result.set_stylebox("panel","TooltipPanel",style(PAPER,ACCENT))
	result.set_color("font_color","TooltipLabel",INK)
	result.set_font_size("font_size","TooltipLabel",21)
	for control in ["OptionButton","CheckButton","CheckBox"]:
		result.set_font_size("font_size",control,22)
		result.set_color("font_color",control,INK)
	result.set_stylebox("normal","OptionButton",style())
	result.set_stylebox("hover","OptionButton",style(SELECTED,ACCENT))
	result.set_stylebox("panel","PopupMenu",style(PAPER,LINE))
	result.set_stylebox("hover","PopupMenu",style(SELECTED))
	result.set_color("font_color","PopupMenu",INK); result.set_color("font_hover_color","PopupMenu",INK)
	for control in ["OptionButton","CheckBox","CheckButton"]:
		result.set_color("font_hover_color",control,INK); result.set_color("font_pressed_color",control,INK)
		result.set_color("font_disabled_color",control,Color("92999b"))
		result.set_stylebox("focus",control,style(Color.TRANSPARENT,ACCENT))
	result.set_color("font_color","LineEdit",INK); result.set_stylebox("normal","LineEdit",style(Color.WHITE,LINE))
	result.set_color("font_color","TextEdit",INK); result.set_stylebox("normal","TextEdit",style(Color.WHITE,LINE))
	result.set_stylebox("panel","Window",style(PAPER,LINE))
	result.set_color("title_color","Window",INK)
	result.set_stylebox("slider","HSlider",meter(LINE)); result.set_stylebox("grabber_area","HSlider",meter(ACCENT))
	result.set_constant("separation","VBoxContainer",12); result.set_constant("separation","HBoxContainer",12)
	return result

static func font() -> FontVariation:
	var result = FontVariation.new()
	result.base_font = load("res://assets/fonts/NotoSansSC.ttf")
	result.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):400.0}
	result.variation_embolden = 0.0
	return result

static func hud_font() -> FontVariation:
	if hud_typeface==null:
		hud_typeface=FontVariation.new()
		hud_typeface.base_font=load("res://assets/fonts/NotoSerifSC.ttf")
		hud_typeface.variation_opentype={TextServerManager.get_primary_interface().name_to_tag("wght"):600.0}
	return hud_typeface

static func fill(node: Control): node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func v(parent: Node) -> VBoxContainer:
	var box = VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(box); return box

static func h(parent: Node) -> HBoxContainer:
	var box = HBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(box); return box

static func label(parent: Node, value: String, size: int = 23, color: Color = INK) -> Label:
	var text = Label.new(); text.text = value; text.add_theme_font_size_override("font_size",size); text.add_theme_color_override("font_color",ink(parent,color)); text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; text.size_flags_horizontal = Control.SIZE_EXPAND_FILL; text.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(text); return text

static func button(parent: Node, value: String, callback: Callable, disabled: bool = false) -> Button:
	var control = Button.new(); control.text = value; control.custom_minimum_size.y = 52; control.disabled = disabled; control.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(control); control.pressed.connect(callback)
	if is_dark(parent):
		for state in ["normal","hover","pressed","focus","disabled"]:
			control.add_theme_stylebox_override(state,button_style(Color(NIGHT,.5 if state=="normal" else .82),Color(PALE_GOLD,.4) if state in ["hover","focus"] else Color.TRANSPARENT))
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: control.add_theme_color_override(state,IVORY)
		control.add_theme_color_override("font_disabled_color",Color("7d8c9f"))
	return control

static func panel(parent: Node) -> PanelContainer:
	var box = PanelContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; parent.add_child(box); return box

static func texture(path: String) -> Texture2D:
	if path!="" and not image_cache.has(path): image_cache[path]=load(path) if ResourceLoader.exists(path) else null
	return image_cache.get(path)

static func image(parent: Node, path: String, minimum: Vector2) -> TextureRect:
	var node = TextureRect.new(); node.texture = texture(path); node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; node.custom_minimum_size = minimum; node.mouse_filter = Control.MOUSE_FILTER_IGNORE; parent.add_child(node); return node

static func bar(parent: Node, value: float, maximum: float, mana: bool = false) -> ProgressBar:
	var control = ProgressBar.new(); control.custom_minimum_size.y = 6; control.max_value = maxf(1,maximum); control.value = value; control.show_percentage = false; control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if mana: control.add_theme_stylebox_override("fill",meter(MP))
	parent.add_child(control); return control

static func space(parent: Node, height: float = 12):
	var node = Control.new(); node.custom_minimum_size.y = height; parent.add_child(node)

static func scroll(parent: Node) -> VBoxContainer:
	var control = ScrollContainer.new(); control.follow_focus=true; control.size_flags_vertical = Control.SIZE_EXPAND_FILL; control.size_flags_horizontal = Control.SIZE_EXPAND_FILL; control.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; parent.add_child(control)
	return v(control)

static func option(parent: Node, values: Array, selected: int, callback: Callable) -> OptionButton:
	var control = OptionButton.new(); control.custom_minimum_size = Vector2(190,48); control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for value in values: control.add_item(str(value))
	control.select(selected); parent.add_child(control); control.item_selected.connect(callback); return control

static func meter(color: Color) -> StyleBoxFlat:
	var box=StyleBoxFlat.new(); box.bg_color=color; box.set_corner_radius_all(2); return box

static func canvas(parent: Node, position_value: Vector2, dimensions: Vector2) -> Control:
	var node=Control.new(); node.position=position_value; node.size=dimensions; node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node); return node

static func card(parent: Node, position_value: Vector2, dimensions: Vector2, color: Color = Color.TRANSPARENT, border: Color = Color.TRANSPARENT) -> Panel:
	var node=Panel.new(); node.position=position_value; node.size=dimensions; node.add_theme_stylebox_override("panel",style(Color(NIGHT,.65) if is_dark(parent) and color.a>0.5 else color,Color(PALE_GOLD,.18) if is_dark(parent) and border.a>0 else border)); node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node); return node

static func text(parent: Node, value: String, position_value: Vector2, dimensions: Vector2, font_size: int = 23, color: Color = INK) -> Label:
	var node=label(parent,value,font_size,color); node.position=position_value; node.size=dimensions; return node

static func art(parent: Node, path: String, position_value: Vector2, dimensions: Vector2, cover: bool = false) -> TextureRect:
	var node=image(parent,path,Vector2.ZERO); node.position=position_value; node.size=dimensions
	if cover: node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; node.clip_contents=true
	return node

static func portrait(parent: Node, path: String, point: Vector2, diameter: float) -> TextureRect:
	var ring=card(parent,point-Vector2.ONE*2,Vector2.ONE*(diameter+4),Color(NIGHT,.7),PALE_GOLD)
	ring.add_theme_stylebox_override("panel",style(Color(NIGHT,.7),PALE_GOLD,int(diameter/2)+2))
	var node=art(parent,path,point,Vector2.ONE*diameter)
	var material_value=ShaderMaterial.new(); material_value.shader=load("res://shaders/portrait_circle.gdshader"); node.material=material_value
	return node

static func action(parent: Node, value: String, position_value: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false, disabled: bool = false) -> Button:
	var node=button(parent,value,callback,disabled); node.position=position_value; node.size=dimensions; node.custom_minimum_size.y=0
	node.set_meta("layout_size",dimensions)
	node.add_theme_stylebox_override("normal",button_style(Color.TRANSPARENT,Color.TRANSPARENT))
	node.add_theme_stylebox_override("hover",button_style(Color("eae7df"),LINE))
	node.add_theme_stylebox_override("pressed",button_style(SELECTED,ACCENT))
	node.add_theme_stylebox_override("disabled",button_style(Color(0.6,0.6,0.6,0.06),Color.TRANSPARENT))
	node.add_theme_stylebox_override("focus",button_style(Color.TRANSPARENT,GOLD))
	if primary:
		node.add_theme_stylebox_override("normal",button_style(Color("e8dbc0"),Color.TRANSPARENT,4))
		node.add_theme_stylebox_override("hover",button_style(Color("f1e3c8"),ACCENT,4))
		node.add_theme_stylebox_override("pressed",button_style(Color("d7c4a2"),ACCENT,4))
		node.add_theme_color_override("font_color",INK); node.add_theme_color_override("font_hover_color",INK); node.add_theme_color_override("font_pressed_color",INK)
	if is_dark(parent) and not primary:
		for state in ["normal","hover","pressed","focus"]: node.add_theme_stylebox_override(state,button_style(Color(NIGHT,.3 if state=="normal" else .85),PALE_GOLD if state=="focus" else Color(PALE_GOLD,.5) if state=="hover" else Color.TRANSPARENT))
	if primary:
		for state in ["normal","hover","pressed"]: node.add_theme_stylebox_override(state,button_style(IVORY if state=="normal" else Color("e7d7b7"),PALE_GOLD,30))
		node.add_theme_color_override("font_focus_color",INK)
	node.size=dimensions
	node.set_deferred("size",dimensions)
	return node

static func button_style(color: Color, border: Color, radius: int = 28) -> StyleBoxFlat:
	var box=style(color,border,radius); box.content_margin_top=6; box.content_margin_bottom=6; box.content_margin_left=12; box.content_margin_right=12; return box

static func icon(id: String, light: bool = false) -> Texture2D:
	var path="res://assets/ui/icons/"+id+".svg"
	if not light: return texture(path)
	var key=path+":ivory"
	if not image_cache.has(key) and FileAccess.file_exists(path):
		var source=FileAccess.get_file_as_string(path).replace("#27313b","#f4eddf").replace("#856c40","#dbc494")
		var pixels=Image.new()
		if pixels.load_svg_from_string(source)==OK: image_cache[key]=ImageTexture.create_from_image(pixels)
	return image_cache.get(key,texture(path))

static func icon_button(parent: Node, id: String, caption: String, position_value: Vector2, callback: Callable, dimensions: Vector2 = Vector2(68,64)) -> Button:
	var node=action(parent,"",position_value,dimensions,callback)
	node.icon=icon(id,is_dark(parent)); node.expand_icon=true; node.add_theme_constant_override("icon_max_width",30); node.tooltip_text=caption; node.accessibility_name=caption
	return node

static func rule(parent: Node, position_value: Vector2, width: float, color: Color = LINE):
	var node=ColorRect.new(); node.position=position_value; node.size=Vector2(width,1); node.color=Color(PALE_GOLD,.25) if is_dark(parent) else color; node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node)

static func selected(button_node: Button, active: bool):
	if not button_node.has_meta("selection_base"):
		button_node.set_meta("selection_base",button_node.get_theme_stylebox("normal"))
	button_node.set_meta("selected",active)
	if active:
		var box=button_style(IVORY,GOLD,8 if button_node.get_meta("grid_tile",false) else 28)
		box.border_width_left=1; box.set_border_width_all(1); box.border_color=GOLD
		button_node.add_theme_stylebox_override("normal",box)
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button_node.add_theme_color_override(state,INK)
	else:
		button_node.add_theme_stylebox_override("normal",button_node.get_meta("selection_base"))
		for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: button_node.add_theme_color_override(state,IVORY if is_dark(button_node) else INK)

static func enter(node: Control, reduced: bool):
	var previous=node.get_meta("entry_tween") if node.has_meta("entry_tween") else null
	if previous is Tween and previous.is_valid(): previous.kill()
	var destination=node.get_meta("entry_origin",node.position); node.set_meta("entry_origin",destination)
	node.position=destination; node.modulate.a=1
	# Selections and navigation never fade the entire page out.

static func scroll_at(parent: Node, position_value: Vector2, dimensions: Vector2) -> VBoxContainer:
	var node=ScrollContainer.new(); node.follow_focus=true; node.position=position_value; node.size=dimensions; node.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; parent.add_child(node)
	return v(node)

static func gradient(parent: Node, position_value: Vector2, dimensions: Vector2, horizontal: bool = false, fade_out: bool = false) -> TextureRect:
	var ramp=Gradient.new(); var solid=Color(PAPER,0.98); var clear=Color(PAPER,0.0)
	ramp.colors=PackedColorArray([solid,solid,clear] if fade_out else [clear,solid,solid])
	ramp.offsets=PackedFloat32Array([0.0,0.62,1.0] if fade_out else [0.0,0.38,1.0])
	var texture_value=GradientTexture2D.new(); texture_value.gradient=ramp; texture_value.width=512; texture_value.height=512
	texture_value.fill_from=Vector2.ZERO; texture_value.fill_to=Vector2(1,0) if horizontal else Vector2(0,1)
	var node=TextureRect.new(); node.texture=texture_value; node.position=position_value; node.size=dimensions; node.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(node); return node
