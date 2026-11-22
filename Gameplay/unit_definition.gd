class_name UnitDefinition
extends Resource

## How the unit moves along its row at the start of every round after the first.
enum Shift { HOLD, LEFT, RIGHT, BOUNCE }

@export var title: String
@export_range(1, 99, 1, "or_greater") var attack: int = 1
@export_range(1, 99, 1, "or_greater") var hp: int = 1
@export var shift: Shift = Shift.HOLD
@export_group("Art")
@export var portrait: Texture2D
## Shown once the unit carries at least one MARK. Without it the portrait is tinted.
@export var marked_portrait: Texture2D
## Multiplied into the portrait, e.g. to tell apart bosses that share art.
@export var portrait_tint: Color = Color.WHITE


func starting_shift_direction() -> int:
	match shift:
		Shift.LEFT:
			return -1
		Shift.RIGHT, Shift.BOUNCE:
			return 1
		_:
			return 0
