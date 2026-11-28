class_name DeckRun
extends RefCounted

const MAX_UNITS := 5
const STARTING_ARMY_SIZE := 3
const STARTING_RP := 3
const MAX_RP := 5
const MAX_GRAVEYARD := 9

var army: Array[UnitState] = []
## Dead units, oldest first. Kept across battles; the oldest drops out past MAX_GRAVEYARD.
var graveyard: Array[UnitState] = []
var starting_slots: Dictionary[UnitState, int] = {}
var rp: int = STARTING_RP
var cleared_encounters: Array[EncounterDefinition] = []
var defeated: bool = false
var _lineups: Dictionary[EncounterDefinition, Array] = {}


static func route_successors(
	encounter: EncounterDefinition, route: Array[EncounterDefinition]
) -> Array[EncounterDefinition]:
	var successors: Array[EncounterDefinition] = []
	if encounter.map_stage > 0:
		for candidate in route:
			if (
				candidate.map_stage == encounter.map_stage + 1
				and encounter.next_lanes.has(candidate.map_lane)
			):
				successors.append(candidate)
	else:
		var index := route.find(encounter)
		if index >= 0 and index + 1 < route.size():
			successors.append(route[index + 1])
	return successors


func enemy_lineup(
	encounter: EncounterDefinition, enemy_pool: Array[UnitDefinition]
) -> Array[UnitDefinition]:
	if encounter.random_enemy_count <= 0:
		return encounter.enemies
	if _lineups.has(encounter):
		return _lineups[encounter]
	var pool := enemy_pool.filter(func(unit: UnitDefinition) -> bool: return unit != null)
	if pool.is_empty():
		return encounter.enemies
	var lineup: Array[UnitDefinition] = []
	# ponytail: Each slot draws independently once per run, including the map preview.
	for index in mini(encounter.random_enemy_count, MAX_UNITS):
		lineup.append(pool.pick_random())
	_lineups[encounter] = lineup
	return lineup


func bury(unit: UnitState) -> void:
	graveyard.append(unit)
	while graveyard.size() > MAX_GRAVEYARD:
		graveyard.pop_front()


func add_rp(amount: int) -> int:
	var before := rp
	rp = clampi(rp + amount, 0, MAX_RP)
	return rp - before


func can_raise() -> bool:
	return rp > 0 and army.size() < MAX_UNITS


func try_raise(unit: UnitState, graveyard: Array[UnitState]) -> bool:
	if not can_raise() or not graveyard.has(unit):
		return false

	graveyard.erase(unit)
	rp -= 1
	unit.revive()
	army.append(unit)
	return true
