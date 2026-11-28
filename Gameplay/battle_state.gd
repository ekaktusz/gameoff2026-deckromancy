class_name BattleState
extends RefCounted

const COLUMN_COUNT := DeckRun.MAX_UNITS

var run: DeckRun
var encounter: EncounterDefinition
var allies: Array[UnitState] = []
var enemies: Array[UnitState] = []
## The run's graveyard, shared across battles.
var graveyard: Array[UnitState]:
	get:
		return run.graveyard
var round_number: int = 0
## Units on both rows that died this battle.
var fallen_count: int = 0
## Units on both rows that changed column in the latest round.
var last_shift_count: int = 0


func _init(
	deck_run: DeckRun, battle_encounter: EncounterDefinition, enemy_pool: Array[UnitDefinition] = []
) -> void:
	run = deck_run
	encounter = battle_encounter
	allies.resize(COLUMN_COUNT)
	enemies.resize(COLUMN_COUNT)
	if run.cleared_encounters.is_empty():
		for unit in run.army:
			if run.starting_slots.has(unit):
				allies[run.starting_slots[unit]] = unit
	for unit in run.army:
		if not allies.has(unit):
			allies[allies.find(null)] = unit
	var lineup := run.enemy_lineup(encounter, enemy_pool)
	var enemy_count := mini(lineup.size(), COLUMN_COUNT)
	var first_column := floori((COLUMN_COUNT - enemy_count) / 2.0)
	for index in enemy_count:
		if lineup[index] != null:
			enemies[first_column + index] = UnitState.new(
				lineup[index], encounter.portrait_gradient
			)


func enemies_defeated() -> bool:
	return enemies_remaining() == 0


func enemies_remaining() -> int:
	return enemies.size() - enemies.count(null)


func swap_allies(first: int, second: int) -> void:
	if round_number != 0:
		return
	var unit := allies[first]
	allies[first] = allies[second]
	allies[second] = unit


## Starts the round, expires graveyard bonuses, and moves both formations.
func begin_round() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if run.army.is_empty() or enemies_defeated():
		return events

	round_number += 1
	for unit in run.army:
		if unit.definition.ability == UnitDefinition.Ability.GRAVEYARD:
			unit.set_battle_bonus(0)
	_shift_row(allies, BattleEvent.Side.ALLY, events)
	_shift_row(enemies, BattleEvent.Side.ENEMY, events)
	last_shift_count = events.size()
	return events


func plan_shift_deaths(shifts: Array[BattleEvent]) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var moved := shifts.map(func(event: BattleEvent) -> UnitState: return event.unit)
	for side: int in [BattleEvent.Side.ALLY, BattleEvent.Side.ENEMY]:
		var row := allies if side == BattleEvent.Side.ALLY else enemies
		for column in COLUMN_COUNT:
			var unit := row[column]
			if (
				unit != null
				and unit.definition.ability == UnitDefinition.Ability.DIE_IF_BLOCKED
				and not unit.is_poop_warrior()
				and not moved.has(unit)
			):
				events.append(BattleEvent.new(BattleEvent.Kind.DEATH, side, unit, column))
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
				marks += unit.marks
		for column in COLUMN_COUNT:
			var unit := row[column]
			if unit == null or unit.is_poop_warrior():
				continue
			var move: BattleEvent = moves.get(unit)
			var ability := unit.definition.battle_ability(side == BattleEvent.Side.ENEMY)
			var bonus := _round_bonus(ability, unit, row, column, marks, move)
			if bonus != unit.battle_bonus:
				events.append(BattleEvent.new(BattleEvent.Kind.BONUS, side, unit, column, bonus))
	return events


func _round_bonus(
	ability: UnitDefinition.Ability,
	unit: UnitState,
	row: Array[UnitState],
	column: int,
	marks: int,
	move: BattleEvent,
) -> int:
	var bonus := 0
	match ability:
		UnitDefinition.Ability.GRAVEYARD:
			bonus = graveyard.size()
		UnitDefinition.Ability.ARMY_MARKS:
			bonus = marks - unit.marks
		UnitDefinition.Ability.OWN_MARKS:
			bonus = 4 * unit.marks
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
		elif enemy != null:
			events.append(_attack_event(BattleEvent.Side.ENEMY, enemy, null, column))
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


## Returns the actual RiP gained at the time of death.
func apply_death(event: BattleEvent) -> int:
	var unit := event.unit
	var is_ally := event.side == BattleEvent.Side.ALLY
	var row := allies if is_ally else enemies
	if row[event.column] != unit:
		return 0
	row[event.column] = null
	unit.hp = 0
	unit.set_battle_bonus(0)
	if event.sacrificed:
		unit.marks += 1
	run.bury(unit)
	fallen_count += 1
	if is_ally:
		run.army.erase(unit)
		return 0
	return run.add_rp(1) if unit.marks == 0 else 0


func sacrifice(column: int) -> BattleEvent:
	if round_number == 0 or not _valid_column(column) or allies[column] == null:
		return null
	var event := BattleEvent.new(
		BattleEvent.Kind.DEATH, BattleEvent.Side.ALLY, allies[column], column
	)
	event.sacrificed = true
	return event


func clear_bonuses() -> void:
	for unit in run.army:
		unit.set_battle_bonus(0)


func can_raise_at(column: int) -> bool:
	return round_number > 0 and _valid_column(column) and allies[column] == null and run.can_raise()


func try_raise(unit: UnitState, column: int) -> bool:
	if not can_raise_at(column) or not run.try_raise(unit, graveyard):
		return false
	allies[column] = unit
	return true


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


## Resolve left to right so a line of birds can follow into vacated slots.
func _shift_row(row: Array[UnitState], side: int, events: Array[BattleEvent]) -> void:
	var displaced: Array[UnitState] = []
	for column in range(1, COLUMN_COUNT):
		var bird := row[column]
		if bird == null or bird.is_poop_warrior() or not bird.definition.shifts_left():
			continue
		var destination := column - 1
		var target := row[destination]
		if (
			target != null
			and bird.definition.ability == UnitDefinition.Ability.DIE_IF_BLOCKED
			and _is_holding(target)
		):
			destination -= 1
			if destination < 0 or row[destination] != null:
				continue
			target = null
		if target != null:
			if (
				not target.definition.can_be_displaced()
				or target.is_poop_warrior()
				or displaced.has(target)
			):
				continue
			displaced.append(target)
			events.append(_shift_event(side, target, destination, column, true))
		row[destination] = bird
		row[column] = target
		events.append(_shift_event(side, bird, column, destination, target != null))


func _is_holding(unit: UnitState) -> bool:
	return (
		unit.is_poop_warrior()
		or unit.definition.ability == UnitDefinition.Ability.HOLD_GROWTH
		or (not unit.definition.shifts_left() and not unit.definition.can_be_displaced())
	)
