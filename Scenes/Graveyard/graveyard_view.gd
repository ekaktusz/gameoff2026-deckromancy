class_name GraveyardView
extends Node2D
## Dead units laid out as a grid of cards; click one to raise it. As the first
## screen of a run it also shows the raised army in a row below the grid, and
## raised cards slide from the grid into that row. The battle screen embeds it
## at a smaller scale with the background hidden.

signal raise_requested(unit: UnitState)
signal continue_requested

const CARD_SCENE := preload("res://Scenes/Card/card_2d.tscn")
const MOVE_TIME := 0.35

@export var show_background: bool = true
@export var grid_columns: int = 5
@export var card_scale: float = 0.9
## Distance between card centres, in local pixels.
@export var cell_size: Vector2 = Vector2(240, 290)
## Local centre of the first graveyard card.
@export var grid_origin: Vector2 = Vector2(166, 324)
## Local centre of the first army card (starting graveyard only).
@export var army_origin: Vector2 = Vector2(166, 744)

var _cards: Dictionary = {}

@onready var _background: Sprite2D = $Background
@onready var _status: Label = $Status
@onready var _army_label: Label = $ArmyLabel
@onready var _card_layer: Node2D = $Cards
@onready var _continue_button: Button = $Continue


func _ready() -> void:
	_background.visible = show_background


func display(run: DeckRun, dead: Array[UnitState], is_starting_yard: bool = false) -> void:
	_status.text = (
		"%d/%d RiP  ·  %d/%d creatures"
		% [
			run.rp,
			DeckRun.MAX_RP,
			run.army.size(),
			DeckRun.MAX_UNITS,
		]
	)
	if dead.is_empty():
		_status.text += "\nNo creatures to raise"
	elif run.can_raise():
		_status.text += "\nClick a card to raise it for 1 RiP"

	_army_label.visible = is_starting_yard
	_continue_button.visible = is_starting_yard
	_continue_button.disabled = run.army.is_empty()

	var targets := {}
	for index in dead.size():
		targets[dead[index]] = grid_origin + _cell(index)
	if is_starting_yard:
		for index in run.army.size():
			targets[run.army[index]] = army_origin + Vector2(cell_size.x * index, 0)

	for unit: UnitState in _cards.keys():
		if not targets.has(unit):
			(_cards[unit] as Card2D).queue_free()
			_cards.erase(unit)

	for unit: UnitState in targets:
		var for_revival := dead.has(unit)
		var target := to_global(targets[unit])
		var card: Card2D = _cards.get(unit)
		if card == null:
			card = CARD_SCENE.instantiate() as Card2D
			_card_layer.add_child(card)
			card.base_scale = Vector2.ONE * card_scale
			card.global_position = target
			card.clicked.connect(_on_card_clicked.bind(unit))
			_cards[unit] = card
			card.pop()
		elif not card.global_position.is_equal_approx(target):
			card.move_to(target, MOVE_TIME)
		card.display(unit, Card2D.Look.DEAD if for_revival else Card2D.Look.ALLY, for_revival)
		card.clickable = for_revival and run.can_raise()
		card.dimmed = for_revival and not run.can_raise()


## Where a unit's card currently is, so another screen can fly a card from it.
func card_global_position(unit: UnitState) -> Vector2:
	var card: Card2D = _cards.get(unit)
	return card.global_position if card != null else global_position


func _cell(index: int) -> Vector2:
	var columns := maxi(1, grid_columns)
	return Vector2(cell_size.x * (index % columns), cell_size.y * floori(float(index) / columns))


func _on_card_clicked(unit: UnitState) -> void:
	raise_requested.emit(unit)


func _on_continue_pressed() -> void:
	continue_requested.emit()
