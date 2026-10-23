extends SceneTree

func _initialize(): call_deferred("run")

func run():
	if "--rocks-only" in OS.get_cmdline_user_args():
		await rocks(); quit(); return
	var db=GameContent.new(); var session=GameSession.new(db); session.new_game("warden")
	var view=WorldView.new()
	var viewport=SubViewport.new(); viewport.size=Vector2i(1642,950); viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	viewport.add_child(view); view.setup(db,session); view.set_process(false); view.set_process_unhandled_input(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/refined-world/maps"))
	var scenes=["town"]; scenes.append_array(db.raw.scenes.keys())
	if "--regions-only" in OS.get_cmdline_user_args(): scenes=db.regions.keys()
	for id in scenes:
		var spawn=db.regions[id].spawn if db.regions.has(id) else [30,27] if id=="town" else [8.5,8.5]
		session.state.location={"scene":id,"x":spawn[0],"y":spawn[1]}; view.show_location(); view.hero.hide(); view.hero_shadow.hide()
		if view.region_layer!=null: view.region_layer.freeze_for_capture()
		for target in view.targets:
			for child in target.node.get_children():
				if child.has_meta("world_caption"): child.hide()
		var bounds=WorldPresentation.bounds(id); viewport.size=Vector2i(1642,950) if id=="town" else Vector2i(1440,810)
		if db.regions.has(id): viewport.size=Vector2i(2048,roundi(2048*bounds.size.y/bounds.size.x))
		view.camera.position=bounds.get_center(); view.camera.zoom=Vector2.ONE*float(viewport.size.x)/bounds.size.x
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var image=viewport.get_texture().get_image(); image.save_png("res://assets/refined-world/maps/"+id+".png")
		print("Baked actual scene: "+id)
	viewport.queue_free(); await process_frame; quit()

func rocks():
	for i in range(1,6):
		var vertices=[]; var uvs=[]; var normals=[]; var surface=SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var text=FileAccess.get_file_as_string("res://authoring/rocks/rock%d.obj" % i)
		for line in text.split("\n"):
			var parts=line.strip_edges().split(" ",false)
			if parts.is_empty(): continue
			if parts[0]=="v": vertices.append(Vector3(float(parts[1]),float(parts[2]),float(parts[3])))
			elif parts[0]=="vt": uvs.append(Vector2(float(parts[1]),1.0-float(parts[2])))
			elif parts[0]=="vn": normals.append(Vector3(float(parts[1]),float(parts[2]),float(parts[3])))
			elif parts[0]=="f":
				for index in range(2,parts.size()-1):
					for face in [parts[1],parts[index],parts[index+1]]:
						var ids=face.split("/"); surface.set_uv(uvs[int(ids[1])-1]); surface.set_normal(normals[int(ids[2])-1]); surface.add_vertex(vertices[int(ids[0])-1])
		var mesh=surface.commit(); var viewport=SubViewport.new(); viewport.size=Vector2i(384,384); viewport.own_world_3d=true; viewport.transparent_bg=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
		var model=MeshInstance3D.new(); model.mesh=mesh; viewport.add_child(model)
		var material_value=StandardMaterial3D.new(); var image=Image.load_from_file("res://authoring/rocks/rock%d.png" % i); material_value.albedo_texture=ImageTexture.create_from_image(image); material_value.roughness=1; material_value.cull_mode=BaseMaterial3D.CULL_DISABLED; model.material_override=material_value
		var bounds=mesh.get_aabb(); model.position=-bounds.get_center(); model.scale=Vector3.ONE*2.4/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)); model.position*=model.scale.x
		var camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=3.5; camera.position=Vector3(3,2.45,3); viewport.add_child(camera); camera.look_at(Vector3.ZERO)
		var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-45,-35,0); light.light_energy=.8; viewport.add_child(light)
		var env=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.background_mode=Environment.BG_COLOR; env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color("f6eedb"); env.environment.ambient_light_energy=.65; viewport.add_child(env)
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://assets/refined-world/rock-%d.png" % i); viewport.queue_free(); await process_frame
		print("Baked CC0 rock "+str(i))
