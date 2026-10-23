class_name GameBindings
extends RefCounted

const MENUS={KEY_B:"inventory",KEY_C:"character",KEY_J:"journal",KEY_M:"map",KEY_L:"party"}
const KEYS={"terminal":KEY_ESCAPE,"interact":KEY_F,"wheel":KEY_TAB,"confirm":KEY_ENTER,"default_skill":KEY_E,"ultimate":KEY_Q}

static func install():
	var bindings={"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN],"run":[KEY_SHIFT]}
	for action in KEYS: bindings[action]=[KEYS[action]]
	for key in MENUS: bindings["open_"+MENUS[key]]=[key]
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event=InputEventKey.new(); event.physical_keycode=key; InputMap.action_add_event(action,event)

static func key(event: InputEventKey) -> int: return event.physical_keycode if event.physical_keycode!=0 else event.keycode
static func matches(event: InputEventKey, action: String) -> bool: return key(event)==KEYS.get(action,0)
static func label(action: String) -> String:
	var code=KEYS.get(action,MENUS.find_key(action))
	if code==null: return ""
	return {KEY_ESCAPE:"Esc",KEY_ENTER:"Enter",KEY_TAB:"Tab"}.get(code,OS.get_keycode_string(code))
