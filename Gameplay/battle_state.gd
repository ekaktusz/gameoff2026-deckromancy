class_name BattleState
extends RefCounted

const COLUMN_COUNT := DeckRun.MAX_UNITS

var run: DeckRun
var encounter: EncounterDefinition
var allies: Array[UnitState] = []
var enemies: Array[UnitState] = []
var graveyard: Array[UnitState] = []
var round_number: int = 0
# Empty enemy slots that already paid out RiP this battle.
var rewarded_columns: Array[int] = []
## Units on both rows that changed column in the latest round.
var last_shift_count: int = 0


func _init(deck_run: DeckRun, battle_encounter: EncounterDefinition) -> void:
	run = deck_run
	encounter = battle_encounter
	allies.resize(COLUMN_COUNT)
	enemies.resize(COLUMN_COUNT)
	for column in run.army.size():
		allies[column] = run.army[column]
	for column in mini(encounter.enemies.size(), COLUMN_COUNT):
		enemies[column] = UnitState.new(encounter.enemies[column])


func enemies_defeated() -> bool:
	return enemies.count(null) == COLUMN_COUNT


func swap_allies(first: int, second: int) -> void:
	if round_number != 0:
		return
	var unit := allies[first]
	allies[first] = allies[second]
	allies[second] = unit


func resolve_round() -> void:
	if run.army.is_empty() or enemies_defeated():
		return

	round_number += 1
	# The player's arrangement fights as set in round 1; units shift from round 2 on.
	last_shift_count = 0
	if round_number > 1:
		last_shift_count = _shift_row(allies) + _shift_row(enemies)
	_align_unopposed_formations()
	for column in COLUMN_COUNT:
		var ally := allies[column]
		var enemy := enemies[column]
		if ally == null and enemy == null:
			continue
		# Hitting an empty slot gains RiP once per slot per battle;
		# an enemy hitting an empty slot always costs RiP.
		if enemy == null:
			if not rewarded_columns.has(column):
				rewarded_columns.append(column)
				run.add_rp(1)
			continue
		if ally == null:
			run.add_rp(-1)
			continue

		# The defender always retaliates, even when the attack kills it.
		enemy.hp = maxi(0, enemy.hp - ally.attack)
		ally.hp = maxi(0, ally.hp - enemy.attack)

		if enemy.hp == 0:
			enemies[column] = null
			graveyard.append(enemy)
			if enemy.revivals == 0:
				run.add_rp(1)

		if ally.hp == 0:
			allies[column] = null
			run.army.erase(ally)
			graveyard.append(ally)


func try_raise(unit: UnitState) -> bool:
	if round_number == 0:
		return false

	var empty_column := allies.find(null)
	if empty_column == -1 or not run.try_raise(unit, graveyard):
		return false
	allies[empty_column] = unit
	return true


## Moves every unit one slot in its shift direction. Bounce units facing the
## edge turn around first. Two neighbours heading toward each other swap places.
## Everyone else resolves left movers from the left and right movers from the
## right, so a line heading the same way moves together, and only enters an
## empty slot; otherwise it stays put.
func _shift_row(row: Array[UnitState]) -> int:
	_turn_bounce_units_at_edges(row)
	var handled: Array[UnitState] = []
	var moves := 0

	for column in COLUMN_COUNT - 1:
		var left := row[column]
		var right := row[column + 1]
		if left == null or right == null or handled.has(left):
			continue
		if left.shift_direction == 1 and right.shift_direction == -1:
			row[column] = right
			row[column + 1] = left
			handled.append(left)
			handled.append(right)
			moves += 2

	for direction: int in [-1, 1]:
		var columns: Array = range(COLUMN_COUNT)
		if direction == 1:
			columns.reverse()
		for column: int in columns:
			var unit := row[column]
			if unit == null or unit.shift_direction != direction or handled.has(unit):
				continue
			handled.append(unit)
			var target := column + direction
			if target >= 0 and target < COLUMN_COUNT and row[target] == null:
				row[target] = unit
				row[column] = null
				moves += 1
	return moves


func _turn_bounce_units_at_edges(row: Array[UnitState]) -> void:
	for column: int in [0, COLUMN_COUNT - 1]:
		var unit := row[column]
		if unit == null or unit.definition.shift != UnitDefinition.Shift.BOUNCE:
			continue
		var target: int = column + unit.shift_direction
		if target < 0 or target >= COLUMN_COUNT:
			unit.shift_direction = -unit.shift_direction


## Fallback when no column has units on both sides after shifting, so two
## formations that never meet cannot stall the fight.
func _align_unopposed_formations() -> void:
	var first_ally := -1
	var first_enemy := -1
	for column in COLUMN_COUNT:
		if allies[column] != null and enemies[column] != null:
			return
		if first_ally == -1 and allies[column] != null:
			first_ally = column
		if first_enemy == -1 and enemies[column] != null:
			first_enemy = column

	allies[first_enemy] = allies[first_ally]
	allies[first_ally] = null
