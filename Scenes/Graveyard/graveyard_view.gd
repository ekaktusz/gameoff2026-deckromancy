class_name GraveyardView
extends Node2D
## Dead units laid out as a grid of cards; drag one to the army to raise it. As the first
## screen of a run it also shows the raised army in a row below the grid.
## The battle screen embeds it at a smaller scale with the background hidden.

signal unit_dragged(unit: UnitState, point: Vector2)
signal unit_dropped(unit: UnitState, point: Vector2)
signal drag_cancelled
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

var interactions_enabled: bool = true
var _cards: Dictionary = {}

@onready var _background: Sprite2D = $Background
@onready var _status: Label = $Status
@onready var _army_label: Label = $ArmyLabel
@onready var _army_slots: SlotRow = $ArmySlots
@onready var _card_layer: Node2D = $Cards
@onready var _continue_button: Button = $Continue


func _ready() -> void:
	_background.visible = show_background
	if show_background:
		var title: Label = $Title
		title.position = Vector2(1312, 838)
		_status.position = Vector2(1362, 904)
		_army_label.position = Vector2(1312, 754)
		for label in [title, _status, _army_label]:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func display(run: DeckRun, dead: Array[UnitState], is_starting_yard: bool = false) -> void:
	if is_starting_yard:
		_status.text = (
			"%d/%d starting cards\nDrag cards into your army"
			% [run.army.size(), DeckRun.STARTING_ARMY_SIZE]
		)
	else:
		_status.text = (
			"%d/%d RiP  ·  %d/%d creatures"
			% [run.rp, DeckRun.MAX_RP, run.army.size(), DeckRun.MAX_UNITS]
		)
		if dead.is_empty():
			_status.text += "\nNo creatures to raise"
		elif interactions_enabled and run.can_raise():
			_status.text += "\nDrag to an empty slot for 1 RiP"

	_army_label.visible = is_starting_yard
	_army_slots.visible = is_starting_yard
	_continue_button.visible = is_starting_yard
	_continue_button.disabled = run.army.size() != DeckRun.STARTING_ARMY_SIZE

	var targets := {}
	for index in dead.size():
		targets[dead[index]] = grid_origin + _cell(index)
	if is_starting_yard:
		for unit in run.army:
			targets[unit] = to_local(_army_slots.slot_position(run.starting_slots[unit]))

	for unit: UnitState in _cards.keys():
		if not targets.has(unit):
			var card: Card2D = _cards[unit]
			card.hide()
			card.queue_free()
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
			card.dragged.connect(func(point: Vector2) -> void: unit_dragged.emit(unit, point))
			card.dropped.connect(func(point: Vector2) -> void: unit_dropped.emit(unit, point))
			card.drag_cancelled.connect(drag_cancelled.emit)
			_cards[unit] = card
			card.pop()
		elif is_starting_yard:
			# ponytail: Snap to slots so a card can be dragged again immediately.
			card.global_position = target
		elif not card.global_position.is_equal_approx(target):
			card.move_to(target, MOVE_TIME)
		card.display(unit, Card2D.Look.DEAD if for_revival else Card2D.Look.ALLY, for_revival)
		var can_drag := run.can_raise() if for_revival else is_starting_yard
		card.draggable = interactions_enabled and can_drag
		card.hover_enabled = interactions_enabled
		card.dimmed = for_revival and not run.can_raise()


## Where a unit's card currently is, so another screen can fly a card from it.
func card_global_position(unit: UnitState) -> Vector2:
	var card: Card2D = _cards.get(unit)
	return card.global_position if card != null else global_position


func restore_drag_position(unit: UnitState) -> void:
	var card: Card2D = _cards.get(unit)
	if card != null:
		card.restore_drag_position()


func _cell(index: int) -> Vector2:
	var columns := maxi(1, grid_columns)
	return Vector2(cell_size.x * (index % columns), cell_size.y * floori(float(index) / columns))


func army_slot_at(point: Vector2) -> int:
	return _army_slots.column_at(point) if _army_slots.is_visible_in_tree() else -1


func _on_continue_pressed() -> void:
	continue_requested.emit()
