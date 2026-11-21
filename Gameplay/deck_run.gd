class_name DeckRun
extends RefCounted

const MAX_UNITS := 5
const STARTING_RP := 3

var army: Array[UnitState] = []
var rp: int = STARTING_RP
var encounter_index: int = 0
var defeated: bool = false


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
