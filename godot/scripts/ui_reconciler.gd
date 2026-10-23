class_name UIReconciler
extends RefCounted

# Update the live view without removing stable backgrounds, portraits or focus.
const SIGNALS = ["pressed","toggled","item_selected","value_changed","text_changed","gui_input"]
const KEEP = ["script","owner","name","unique_name_in_owner","scene_file_path","scroll_vertical","scroll_horizontal"]

static func update_children(live: Node, desired: Node):
	var children=desired.get_children().duplicate()
	var keys=children.filter(func(n): return n.has_meta("ui_key")).map(func(n): return n.get_meta("ui_key"))
	for i in children.size():
		var fresh=children[i]
		var old=live.get_child(i) if i<live.get_child_count() else null
		if fresh.has_meta("ui_key"):
			old=null
			for candidate in live.get_children():
				if candidate.has_meta("ui_key") and candidate.get_meta("ui_key")==fresh.get_meta("ui_key"):
					old=candidate; live.move_child(old,i); break
		elif old!=null and old.has_meta("ui_key") and old.get_meta("ui_key") in keys: old=null
		var reusable=old!=null and old.get_class()==fresh.get_class() and old.get_script()==null and fresh.get_script()==null and not fresh.has_meta("transient_animation") and not fresh.has_meta("replace_on_refresh")
		if reusable:
			_update(old,fresh); update_children(old,fresh)
			desired.remove_child(fresh); fresh.queue_free()
		else:
			if old!=null: live.remove_child(old); old.queue_free()
			desired.remove_child(fresh); live.add_child(fresh); live.move_child(fresh,i)
	while live.get_child_count()>children.size():
		var child=live.get_child(live.get_child_count()-1); live.remove_child(child); child.queue_free()

static func _update(live: Node, fresh: Node):
	live.set_block_signals(true)
	# Theme overrides absent from a fresh declaration must not survive reuse.
	var fresh_names={}
	for property in fresh.get_property_list(): fresh_names[str(property.name)]=true
	for property in live.get_property_list():
		var key=str(property.name)
		if not key.begins_with("theme_override_") or fresh_names.has(key): continue
		var parts=key.trim_prefix("theme_override_").split("/")
		var kind={"styles":"stylebox","colors":"color","constants":"constant","fonts":"font","font_sizes":"font_size","icons":"icon"}.get(parts[0],"")
		if kind!="" and parts.size()==2: live.call("remove_theme_"+kind+"_override",parts[1])
	for property in fresh.get_property_list():
		var key=str(property.name)
		if key in KEEP or key.begins_with("metadata/"): continue
		if not (property.usage & PROPERTY_USAGE_STORAGE) or property.usage & PROPERTY_USAGE_READ_ONLY: continue
		var value=fresh.get(key)
		if live.get(key)!=value: live.set(key,value)
	for key in live.get_meta_list():
		if not fresh.has_meta(key): live.remove_meta(key)
	for key in fresh.get_meta_list(): live.set_meta(key,fresh.get_meta(key))
	for signal_name in SIGNALS:
		if not fresh.has_signal(signal_name): continue
		for connection in live.get_signal_connection_list(signal_name): live.disconnect(signal_name,connection.callable)
		for connection in fresh.get_signal_connection_list(signal_name): live.connect(signal_name,connection.callable,connection.flags)
	live.set_block_signals(false)
	# Font/theme changes can temporarily enlarge a reused button's minimum size.
	if live is Control and not live.get_parent() is Container:
		live.set_deferred("position",fresh.position); live.set_deferred("size",fresh.get_meta("layout_size",fresh.size))
