class_name GraveyardView
extends VBoxContainer

signal raise_requested(unit: UnitState)
signal continue_requested

const CARD_SCENE := preload("res://Scenes/Card/card_scene.tscn")

@onready var _status: Label = $Status
@onready var _army: Label = $Army
@onready var _cards: HFlowContainer = $Cards
@onready var _continue_button: Button = $Continue


func display(run: DeckRun, dead: Array[UnitState], is_starting_yard: bool = false) -> void:
	_status.text = "%d/%d RiP  ·  %d/%d creatures" % [
		run.rp,
		DeckRun.MAX_RP,
		run.army.size(),
		DeckRun.MAX_UNITS,
	]
	if dead.is_empty():
		_status.text += "  ·  No creatures to raise"

	_army.visible = is_starting_yard
	_continue_button.visible = is_starting_yard
	_continue_button.disabled = run.army.is_empty()
	if is_starting_yard:
		var names := PackedStringArray()
		for unit in run.army:
			names.append(unit.title())
		_army.text = "Army: %s" % ", ".join(names) if not names.is_empty() else ""

	for card in _cards.get_children():
		_cards.remove_child(card)
		card.queue_free()
	for unit in dead:
		var card := CARD_SCENE.instantiate() as CardView
		card.display(unit, true)
		card.disabled = not run.can_raise()
		card.pressed.connect(raise_requested.emit.bind(unit))
		_cards.add_child(card)


func _on_continue_pressed() -> void:
	continue_requested.emit()
