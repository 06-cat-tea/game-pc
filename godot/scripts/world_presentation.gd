class_name WorldPresentation
extends RefCounted

static var data: Dictionary = {}
static var textures: Dictionary = {}
static var terrain_set: TileSet
static var terrain_cells=PackedByteArray()
static var region_cells: Dictionary = {}

static func config() -> Dictionary:
	if data.is_empty():
		data=JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation.json"))
		var town=JSON.parse_string(FileAccess.get_file_as_string("res://data/town-design.json"))
		data.decor=town.decor
		data.mapBounds.town=town.bounds
	return data

static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path]=load(path) if ResourceLoader.exists(path) else null
	return textures[path]

static func iso(point: Vector2, scene: String) -> Vector2:
	var axes=config().coordinates.town if scene=="town" or RegionCatalog.has(scene) else config().coordinates.scene
	return Vector2(axes.origin[0],axes.origin[1])+Vector2(axes.axisX[0],axes.axisX[1])*point.x+Vector2(axes.axisY[0],axes.axisY[1])*point.y

static func bounds(scene: String) -> Rect2:
	if RegionCatalog.has(scene):
		var region_bounds=RegionCatalog.get_region(scene).mapBounds
		return Rect2(region_bounds[0],region_bounds[1],region_bounds[2],region_bounds[3])
	var b=config().mapBounds.town if scene=="town" else config().mapBounds.scene
	return Rect2(b[0],b[1],b[2],b[3])

static func overview(scene: String) -> Texture2D:
	return texture("res://assets/refined-world/maps/"+scene+".png")

static func tile_set() -> TileSet:
	if terrain_set!=null: return terrain_set
	terrain_set=TileSet.new(); terrain_set.tile_size=Vector2i(96,48)
	terrain_set.tile_shape=TileSet.TILE_SHAPE_ISOMETRIC; terrain_set.tile_layout=TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas=TileSetAtlasSource.new(); atlas.texture=texture("res://assets/refined-world/diamond.png"); atlas.texture_region_size=Vector2i(96,48); atlas.create_tile(Vector2i.ZERO)
	terrain_set.add_source(atlas,0)
	return terrain_set
