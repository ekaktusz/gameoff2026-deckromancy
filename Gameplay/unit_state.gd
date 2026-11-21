class_name UnitState
extends RefCounted

var definition: UnitDefinition
var attack: int
var hp: int
var revivals: int = 0


func _init(unit_definition: UnitDefinition) -> void:
	definition = unit_definition
	attack = definition.attack
	hp = definition.hp


func title(after_revival: bool = false) -> String:
	var marks := revivals + int(after_revival)
	return "Poop Warrior" if marks >= 4 else definition.title


func revival_stats() -> Vector2i:
	var base_stats := Vector2(definition.attack, definition.hp)
	match revivals:
		0:
			return Vector2i(base_stats)
		1:
			return Vector2i((base_stats * 0.7).round()).max(Vector2i.ONE)
		2:
			return Vector2i((base_stats * 0.3).round()).max(Vector2i.ONE)
		_:
			return Vector2i.ONE


func revive() -> void:
	var stats := revival_stats()
	attack = stats.x
	hp = stats.y
	revivals += 1
