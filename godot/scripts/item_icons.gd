class_name ItemIcons
extends RefCounted

static var catalog: Dictionary={}

static func path(db: GameContent, id: String) -> String:
	var equipment=db.art("equipment",id)
	if equipment!="" and ResourceLoader.exists(equipment): return equipment
	if catalog.is_empty(): catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/item-icons.json"))
	var candidate=str(catalog.icons.get(id,{}).get("path","res://assets/ui/icons/backpack.svg"))
	return candidate if ResourceLoader.exists(candidate) else "res://assets/ui/icons/backpack.svg"

static func strip(parent: Node, db: GameContent, values: Dictionary, point: Vector2, spacing: float = 172):
	var index=0
	var names={"gold":"金币","herb":"草药","ore":"矿石","shard":"星屑"}
	for id in values:
		var p=point+Vector2(index*spacing,0)
		var art=UIkit.art(parent,path(db,id),p,Vector2(28,28)); art.tooltip_text=names.get(id,id)
		UIkit.text(parent,str(values[id]),p+Vector2(38,-2),Vector2(spacing-45,34),21,UIkit.GOLD)
		index+=1
