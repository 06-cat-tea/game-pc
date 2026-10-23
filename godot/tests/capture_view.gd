extends SceneTree

# Render at the requested resolution independently of desktop window limits.
# size_2d_override keeps the same 1920x1080 input/layout coordinates as the game.
func _initialize():
	var requested=Vector2i(1920,1080)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-size="):
			var parts=argument.trim_prefix("--capture-size=").split("x")
			requested=Vector2i(int(parts[0]),int(parts[1]))
	var scale_factor=minf(float(requested.x)/1920,float(requested.y)/1080)
	var surface=SubViewport.new(); surface.name="CaptureSurface"
	surface.size=Vector2i(roundi(1920*scale_factor),roundi(1080*scale_factor))
	surface.size_2d_override=Vector2i(1920,1080); surface.size_2d_override_stretch=true
	surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var scene=load("res://scenes/main.tscn").instantiate(); surface.add_child(scene)
