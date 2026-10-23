class_name BattleCommand
extends RefCounted

var actor_id = ""
var action = "attack"
var target_id = ""
var skill_id = ""
var turn_id = 0

func _init(actor: String = "", kind: String = "attack", target: String = "", skill: String = "", token: int = 0):
	actor_id = actor
	action = kind
	target_id = target
	skill_id = skill
	turn_id = token

func to_dict() -> Dictionary:
	return {"actor": actor_id, "action": action, "target": target_id, "skill": skill_id, "turn": turn_id}
