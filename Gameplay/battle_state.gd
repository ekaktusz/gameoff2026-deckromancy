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
	var enemy_count := mini(encounter.enemies.size(), COLUMN_COUNT)
	var first_column := floori((COLUMN_COUNT - enemy_count) / 2.0)
	for index in enemy_count:
		enemies[first_column + index] = UnitState.new(encounter.enemies[index])


func enemies_defeated() -> bool:
	return enemies.count(null) == COLUMN_COUNT


func swap_allies(first: int, second: int) -> void:
	if round_number != 0:
		return
	var unit := allies[first]
	allies[first] = allies[second]
	allies[second] = unit


## Starts the round and moves both formations. Health and RiP change as the
## following events play.
func begin_round() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if run.army.is_empty() or enemies_defeated():
		return events

	round_number += 1
	# The player's arrangement fights as set in round 1; units shift from round 2 on.
	last_shift_count = 0
	if round_number > 1:
		last_shift_count = (
			_shift_row(allies, BattleEvent.Side.ALLY, events)
			+ _shift_row(enemies, BattleEvent.Side.ENEMY, events)
		)
	return events


func plan_bonuses(shifts: Array[BattleEvent]) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var moves := {}
	for event in shifts:
		moves[event.unit] = event
	for side: int in [BattleEvent.Side.ALLY, BattleEvent.Side.ENEMY]:
		var row := allies if side == BattleEvent.Side.ALLY else enemies
		var marks := 0
		for unit in row:
			if unit != null:
				marks += unit.revivals
		for column in COLUMN_COUNT:
			var unit := row[column]
			if unit == null:
				continue
			var move: BattleEvent = moves.get(unit)
			if (
				unit.definition.ability == UnitDefinition.Ability.DIE_IF_BLOCKED
				and round_number > 1
				and move == null
			):
				events.append(BattleEvent.new(BattleEvent.Kind.DEATH, side, unit, column))
				continue
			var bonus := _round_bonus(unit, row, column, marks, move)
			if bonus != unit.battle_bonus:
				events.append(BattleEvent.new(BattleEvent.Kind.BONUS, side, unit, column, bonus))
	return events


func _round_bonus(
	unit: UnitState, row: Array[UnitState], column: int, marks: int, move: BattleEvent
) -> int:
	var bonus := 0
	match unit.definition.ability:
		UnitDefinition.Ability.GRAVEYARD:
			bonus = graveyard.size()
		UnitDefinition.Ability.ARMY_MARKS:
			bonus = marks
		UnitDefinition.Ability.OWN_MARKS:
			bonus = 4 * unit.revivals
		UnitDefinition.Ability.ALLIES_TO_RIGHT:
			for index in range(column + 1, COLUMN_COUNT):
				if row[index] != null:
					bonus += 1
		UnitDefinition.Ability.SWAP_GROWTH:
			bonus = unit.battle_bonus + int(move != null and move.swapped)
		UnitDefinition.Ability.HOLD_GROWTH:
			bonus = unit.battle_bonus + int(move == null)
	return bonus


## Plans attacks from the current formations. If all lanes are open, the
## nearest opposing pair trades blows across lanes to keep the fight moving.
func plan_attacks() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if run.army.is_empty() or enemies_defeated():
		return events
	var cross_lane := _cross_lane_pair()
	for column in COLUMN_COUNT:
		var ally := allies[column]
		var enemy := enemies[column]
		if column == cross_lane.x:
			_plan_duel(column, cross_lane.y, events)
		elif column == cross_lane.y:
			continue
		elif ally != null and enemy != null:
			_plan_duel(column, column, events)
		elif ally != null:
			events.append(_attack_event(BattleEvent.Side.ALLY, ally, null, column))
			if not rewarded_columns.has(column):
				var reward := BattleEvent.new(
					BattleEvent.Kind.RIP, BattleEvent.Side.ALLY, null, column, 1
				)
				reward.rewards_column = true
				events.append(reward)
		elif enemy != null:
			events.append(_attack_event(BattleEvent.Side.ENEMY, enemy, null, column))
			events.append(
				BattleEvent.new(BattleEvent.Kind.RIP, BattleEvent.Side.ENEMY, null, column, -1)
			)
	return events


func _plan_duel(ally_column: int, enemy_column: int, events: Array[BattleEvent]) -> void:
	var ally := allies[ally_column]
	var enemy := enemies[enemy_column]
	var attack := _attack_event(BattleEvent.Side.ALLY, ally, enemy, ally_column)
	attack.to_column = enemy_column
	events.append(attack)
	var retaliation := _attack_event(BattleEvent.Side.ENEMY, enemy, ally, enemy_column)
	retaliation.to_column = ally_column
	events.append(retaliation)
	if enemy.combat_hp() <= attack.amount:
		events.append(
			BattleEvent.new(BattleEvent.Kind.DEATH, BattleEvent.Side.ENEMY, enemy, enemy_column)
		)
		if enemy.revivals == 0:
			events.append(
				BattleEvent.new(BattleEvent.Kind.RIP, BattleEvent.Side.ALLY, null, ally_column, 1)
			)
	if ally.combat_hp() <= retaliation.amount:
		events.append(
			BattleEvent.new(BattleEvent.Kind.DEATH, BattleEvent.Side.ALLY, ally, ally_column)
		)


func _cross_lane_pair() -> Vector2i:
	var closest := Vector2i(-1, -1)
	var distance := COLUMN_COUNT
	for ally_column in COLUMN_COUNT:
		if allies[ally_column] == null:
			continue
		if enemies[ally_column] != null:
			return Vector2i(-1, -1)
		for enemy_column in COLUMN_COUNT:
			var gap := absi(enemy_column - ally_column)
			if enemies[enemy_column] != null and gap < distance:
				closest = Vector2i(ally_column, enemy_column)
				distance = gap
	return closest


func apply_death(event: BattleEvent) -> void:
	var unit := event.unit
	unit.hp = 0
	unit.set_battle_bonus(0)
	if event.side == BattleEvent.Side.ALLY:
		allies[event.column] = null
		run.army.erase(unit)
	else:
		enemies[event.column] = null
	graveyard.append(unit)


func sacrifice(column: int) -> BattleEvent:
	if round_number == 0 or not _valid_column(column) or allies[column] == null:
		return null
	return BattleEvent.new(BattleEvent.Kind.DEATH, BattleEvent.Side.ALLY, allies[column], column)


func clear_bonuses() -> void:
	for unit in run.army:
		unit.set_battle_bonus(0)


func can_raise_at(column: int) -> bool:
	return round_number > 0 and _valid_column(column) and allies[column] == null and run.can_raise()


## Returns the chosen column, or -1 when the unit cannot be raised. Click-to-raise
## passes no column and takes the first vacancy.
func try_raise(unit: UnitState, column: int = -1) -> int:
	if round_number == 0:
		return -1
	if column == -1:
		column = allies.find(null)
	if not can_raise_at(column) or not run.try_raise(unit, graveyard):
		return -1
	allies[column] = unit
	return column


func _valid_column(column: int) -> bool:
	return column >= 0 and column < COLUMN_COUNT


func _attack_event(side: int, attacker: UnitState, defender: UnitState, column: int) -> BattleEvent:
	var event := BattleEvent.new(
		BattleEvent.Kind.ATTACK, side, attacker, column, attacker.combat_attack()
	)
	event.target = defender
	return event


func _shift_event(
	side: int, unit: UnitState, from: int, to: int, swapped: bool = false
) -> BattleEvent:
	var event := BattleEvent.new(BattleEvent.Kind.SHIFT, side, unit, from)
	event.to_column = to
	event.swapped = swapped
	return event


## Moves every unit one slot in its shift direction. Bounce units facing the
## edge turn around first. Two neighbours heading toward each other swap places.
## Everyone else resolves left movers from the left and right movers from the
## right, so a line heading the same way moves together, and only enters an
## empty slot; otherwise it stays put.
func _shift_row(row: Array[UnitState], side: int, events: Array[BattleEvent]) -> int:
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
			events.append(_shift_event(side, left, column, column + 1, true))
			events.append(_shift_event(side, right, column + 1, column, true))
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
				events.append(_shift_event(side, unit, column, target))
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
