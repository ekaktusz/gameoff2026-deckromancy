class_name BattleEvent
extends RefCounted
## One thing that happened while a round resolved, in play order, so the battle
## screen can animate it. The battle state is already final when these arrive.

enum Kind { SHIFT, ATTACK, DEATH, RIP }
enum Side { ALLY, ENEMY }

## A Kind value. Stored as int: Godot does not match the enum's inner name `Side`
## with `BattleEvent.Side` from other scripts.
var kind: int
## A Side value.
var side: int
## SHIFT: the unit that moved. ATTACK: the attacker. DEATH: the unit that died.
var unit: UnitState
## ATTACK: the defender, or null when the attack hit an empty slot.
var target: UnitState
## SHIFT: the column the unit left. Otherwise: the column it happened in.
var column: int
## SHIFT only: the column the unit moved to.
var to_column: int
## ATTACK: damage dealt. RIP: RiP gained (positive) or lost (negative).
var amount: int


func _init(
	event_kind: int,
	event_side: int,
	event_unit: UnitState,
	event_column: int,
	event_amount: int = 0,
) -> void:
	kind = event_kind
	side = event_side
	unit = event_unit
	column = event_column
	to_column = event_column
	amount = event_amount
