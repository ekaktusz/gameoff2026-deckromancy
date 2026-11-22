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

	# Temporary shift rule so separated formations can still finish the fight.
	allies[first_enemy] = allies[first_ally]
	allies[first_ally] = null
