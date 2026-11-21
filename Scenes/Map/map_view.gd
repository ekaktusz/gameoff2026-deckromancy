class_name MapView
extends VBoxContainer

signal fight_requested
signal retry_requested

var _run_finished: bool = false

@onready var _title: Label = $Title
@onready var _encounters: Label = $Encounters
@onready var _army: Label = $Army
@onready var _action: Button = $Action


func display(run: DeckRun, encounters: Array[EncounterDefinition]) -> void:
	_run_finished = run.defeated or run.encounter_index >= encounters.size()
	if run.defeated:
		_title.text = "Your army fell"
	elif _run_finished:
		_title.text = "The city gate is yours"

	var route := PackedStringArray()
	for index in encounters.size():
		var label := encounters[index].title
		if index < run.encounter_index:
			label += "  ·  Cleared"
		elif index == run.encounter_index and not _run_finished:
			label += "  ·  Next"
		route.append("%d. %s" % [index + 1, label])
	_encounters.text = "\n".join(route)

	var roster := PackedStringArray()
	roster.append("Army (%d/%d)  ·  %d RP" % [run.army.size(), DeckRun.MAX_UNITS, run.rp])
	for unit in run.army:
		roster.append("%s  ·  %d ATK  %d HP" % [unit.title(), unit.attack, unit.hp])
	_army.text = "\n".join(roster)

	_action.disabled = false
	_action.text = "Start another run" if _run_finished else "Enter battle"


func _on_action_pressed() -> void:
	if _run_finished:
		retry_requested.emit()
	else:
		fight_requested.emit()
