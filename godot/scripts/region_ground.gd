class_name RegionGround
extends Node2D

var materials: Array[ShaderMaterial] = []
var layers: Array[TileMapLayer] = []

func setup(id: String):
	var region=RegionCatalog.get_region(id)
	# Ground extends beyond the walkable world so an edge camera never sees a void.
	for index in 3:
		var layer=TileMapLayer.new(); layer.name=["Terrain","Paths","Water"][index]; layer.tile_set=WorldPresentation.tile_set(); layer.position=Vector2(0,24)-layer.map_to_local(Vector2i.ZERO)
		layer.collision_enabled=false; layer.navigation_enabled=false; layer.occlusion_enabled=false
		var material_value=ShaderMaterial.new(); material_value.shader=load("res://shaders/region_ground.gdshader")
		material_value.set_shader_parameter("ground_art",WorldPresentation.texture(region.ground)); material_value.set_shader_parameter("road_art",WorldPresentation.texture(region.road)); material_value.set_shader_parameter("terrain_mask",WorldPresentation.texture(region.mask)); material_value.set_shader_parameter("map_cells",Vector2(region.columns,region.rows)); material_value.set_shader_parameter("layer_kind",index)
		material_value.set_shader_parameter("water_color",Color(region.palette.water)); material_value.set_shader_parameter("biome",["wood","pass","fen","coast","city"].find(id)); layer.material=material_value
		add_child(layer); layers.append(layer); materials.append(material_value)
		var key=id+"-"+str(index)
		if WorldPresentation.region_cells.has(key): layer.tile_map_data=WorldPresentation.region_cells[key]
		else:
			var margin=24 if index==0 else 0
			for y in range(-margin,int(region.rows)+margin):
				for x in range(-margin,int(region.columns)+margin): layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
			WorldPresentation.region_cells[key]=layer.tile_map_data
		layer.update_internals()

func set_clock(value: float):
	for material_value in materials: material_value.set_shader_parameter("scene_clock",value)
