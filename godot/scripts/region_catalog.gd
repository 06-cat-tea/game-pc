class_name RegionCatalog
extends RefCounted

static var definitions: Dictionary = {}
static var geometry: Dictionary = {}

static func all() -> Dictionary:
	if definitions.is_empty(): definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/world-regions.json"))
	return definitions

static func has(id: String) -> bool: return all().has(id)

static func get_region(id: String) -> Dictionary: return all().get(id,{})

static func walkable(id: String, point: Vector2) -> bool:
	var region=get_region(id)
	if point.x<2 or point.y<2 or point.x>region.columns-3 or point.y>region.rows-3: return false
	if not geometry.has(id):
		var cache={"water":[],"rocks":[],"buildings":[],"bridges":[],"cliffs":[]}
		for kind in ["water","rocks"]:
			for polygon in region[kind]:
				var points=PackedVector2Array()
				for p in polygon: points.append(Vector2(p[0],p[1]))
				cache[kind].append(points)
		for b in region.buildings: cache.buildings.append(Rect2(b.x-.3,b.y-.3,b.w+.6,b.d+.6))
		for b in region.bridges: cache.bridges.append(Rect2(b.x-b.w/2,b.y-b.d/2,b.w,b.d))
		for decor in region.decor:
			if decor.style=="cliff" and decor.tall: cache.cliffs.append(Rect2(decor.point[0]-.65,decor.point[1]-.65,1.3,1.3))
		geometry[id]=cache
	var cache=geometry[id]
	for rect in cache.buildings:
		if rect.has_point(point): return false
	for rect in cache.cliffs:
		if rect.has_point(point): return false
	if id=="city": return region.terrain[int(point.y)][int(point.x)] not in ["water","wall"]
	for polygon in cache.rocks:
		if Geometry2D.is_point_in_polygon(point,polygon): return false
	for polygon in cache.water:
		if Geometry2D.is_point_in_polygon(point,polygon):
			return cache.bridges.any(func(rect): return rect.has_point(point))
	return true
