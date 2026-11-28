class_name DeckRun
extends RefCounted

const MAX_UNITS := 5
const STARTING_RP := 3
const MAX_RP := 5

var army: Array[UnitState] = []
var rp: int = STARTING_RP
var cleared_encounters: Array[EncounterDefinition] = []
var defeated: bool = false


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
