class_name WorldGround
extends Node2D

var layers: Array[TileMapLayer] = []

func setup(_content: GameContent, id: String):
	if id!="town": return
	for index in 3:
		var layer=TileMapLayer.new(); layer.name=["Meadow","EarthTransition","StoneRoad"][index]
		layer.tile_set=WorldPresentation.tile_set(); layer.position=Vector2(0,24)-layer.map_to_local(Vector2i.ZERO)
		layer.collision_enabled=false; layer.navigation_enabled=false; layer.occlusion_enabled=false
		var material_value=ShaderMaterial.new(); material_value.shader=load("res://shaders/world_ground.gdshader")
		material_value.set_shader_parameter("layer_kind",index)
		for key in ["grass","dirt","sand","pavement","road-mask"]: material_value.set_shader_parameter(key.replace("-","_"),WorldPresentation.texture("res://assets/refined-world/"+key+".png"))
		layer.material=material_value
		add_child(layer); layers.append(layer)
		if WorldPresentation.terrain_cells.is_empty():
			for y in 48:
				for x in 64: layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
			WorldPresentation.terrain_cells=layer.tile_map_data
		else: layer.tile_map_data=WorldPresentation.terrain_cells
		layer.update_internals()

func iso(point: Vector2) -> Vector2: return WorldPresentation.iso(point,"town")
