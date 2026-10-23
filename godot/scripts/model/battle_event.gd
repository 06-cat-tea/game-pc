class_name BattleEvent
extends RefCounted

static func create(kind: String, text: String, actor: String = "", target: String = "", value: int = 0, metadata: Dictionary = {}) -> Dictionary:
	var result={"kind": kind, "text": text, "actor": actor, "target": target, "value": value}
	result.merge(metadata,true)
	return result
