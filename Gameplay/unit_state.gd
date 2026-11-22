class_name UnitState
extends RefCounted

var definition: UnitDefinition
var attack: int
var hp: int
var revivals: int = 0
## -1 moves left, 1 moves right, 0 holds. Bounce units flip it at the row's edge.
var shift_direction: int = 0


func _init(unit_definition: UnitDefinition) -> void:
	definition = unit_definition
	attack = definition.attack
	hp = definition.hp
	shift_direction = definition.starting_shift_direction()


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
	shift_direction = definition.starting_shift_direction()


func shift_label(direction: int) -> String:
	match definition.shift:
		UnitDefinition.Shift.LEFT:
			return "< Left"
		UnitDefinition.Shift.RIGHT:
			return "Right >"
		UnitDefinition.Shift.BOUNCE:
			return "< Bounce" if direction < 0 else "Bounce >"
		_:
			return "Hold"
