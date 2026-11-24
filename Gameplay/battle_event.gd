class_name BattleEvent
extends RefCounted
## An action in the round, in the order the battle screen plays it.

enum Kind { SHIFT, ATTACK, DEATH, RIP, BONUS }
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
## SHIFT: destination. ATTACK: target column, which can differ in a cross-lane duel.
var to_column: int
## SHIFT only: this move traded places with a neighbour.
var swapped: bool = false
## ATTACK: damage. RIP: requested change. BONUS: the new temporary stat bonus.
var amount: int
## RIP only: the first attack on an empty enemy slot uses up its reward.
var rewards_column: bool = false


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
