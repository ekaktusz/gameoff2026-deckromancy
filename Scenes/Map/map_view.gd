class_name MapView
extends VBoxContainer

signal fight_requested(encounter: EncounterDefinition)
signal retry_requested

const CARD_SCENE := preload("res://Scenes/Card/card_2d.tscn")
const ACTIVE_PATH := Color(0.84, 0.66, 0.41)
const FUTURE_PATH := Color(0.27, 0.24, 0.21)
const LANE_HEIGHT := 88.0
const CHOICE_BORDER := Color(0.65, 0.49, 0.29)
const CLEARED_BORDER := Color(0.35, 0.44, 0.29)
const LOCKED_BORDER := Color(0.32, 0.28, 0.24)
const NODE_FILL := Color(0.15, 0.12, 0.10)

var _route: Array[EncounterDefinition] = []
var _available: Array[EncounterDefinition] = []
var _cleared: Array[EncounterDefinition] = []
var _nodes: Dictionary = {}
var _stage_count: int = 0

@onready var _title: Label = $Title
@onready var _graph: Control = $Graph
@onready var _army: Label = $Army
@onready var _army_cards: HBoxContainer = $ArmyCards
@onready var _retry: Button = $Retry


func _ready() -> void:
	_graph.draw.connect(_draw_paths)
	_graph.resized.connect(_layout_route)


func display(
	run: DeckRun, route: Array[EncounterDefinition], available: Array[EncounterDefinition]
) -> void:
	_route = route
	_available = available
	_cleared = run.cleared_encounters
	_retry.visible = run.defeated or available.is_empty()
	if run.defeated:
		_title.text = "Your army fell"
	elif available.is_empty():
		_title.text = "The city is yours"

	for index in route.size():
		var encounter := route[index]
		_stage_count = maxi(_stage_count, _stage(encounter, index))
		var button := Button.new()
		button.text = encounter.title
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.add_theme_font_size_override("font_size", 19 if encounter.is_boss else 17)
		button.disabled = not available.has(encounter)
		button.add_theme_stylebox_override("normal", _node_style(NODE_FILL, CHOICE_BORDER))
		button.add_theme_stylebox_override(
			"hover", _node_style(NODE_FILL.lightened(0.08), ACTIVE_PATH)
		)
		var cleared := _cleared.has(encounter)
		var border := CLEARED_BORDER if cleared else LOCKED_BORDER
		button.add_theme_stylebox_override("disabled", _node_style(NODE_FILL, border))
		button.add_theme_color_override("font_disabled_color", Color(0.68, 0.62, 0.56))
		var names := PackedStringArray()
		for enemy in encounter.enemies:
			names.append(enemy.title)
		button.tooltip_text = ", ".join(names)
		if encounter.is_boss:
			button.add_theme_color_override("font_color", ACTIVE_PATH.lightened(0.35))
			button.add_theme_color_override("font_disabled_color", Color(0.78, 0.65, 0.46))
		if cleared:
			button.add_theme_color_override("font_disabled_color", Color(0.70, 0.82, 0.58))
			button.tooltip_text = "Cleared"
		button.pressed.connect(fight_requested.emit.bind(encounter))
		_graph.add_child(button)
		_nodes[encounter] = button
	_layout_route()

	_army.text = (
		"Army (%d/%d)  ·  %d/%d RiP" % [run.army.size(), DeckRun.MAX_UNITS, run.rp, DeckRun.MAX_RP]
	)
	# ponytail: Reuse the battle cards as read-only army previews.
	for unit in run.army:
		var slot := Control.new()
		slot.custom_minimum_size = Card2D.SIZE + Vector2(0, 44)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_army_cards.add_child(slot)
		var card := CARD_SCENE.instantiate() as Card2D
		card.position = slot.custom_minimum_size / 2.0
		slot.add_child(card)
		card.display(unit, Card2D.Look.ALLY)


func _stage(encounter: EncounterDefinition, index: int) -> int:
	return encounter.map_stage if encounter.map_stage > 0 else index + 1


func _node_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	return style


func _layout_route() -> void:
	if _stage_count == 0 or _graph.size.x <= 0:
		return
	var stage_width := _graph.size.x / _stage_count
	for index in _route.size():
		var encounter := _route[index]
		var button: Button = _nodes[encounter]
		var centre := Vector2(
			(_stage(encounter, index) - 0.5) * stage_width,
			_graph.size.y / 2.0 + encounter.map_lane * LANE_HEIGHT
		)
		var width := minf(stage_width - 14.0, 220.0)
		button.size = Vector2(width, 62.0)
		var title := encounter.title
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		if font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width - 14.0:
			var split := title.rfind(" ")
			if split != -1:
				title = title.left(split) + "\n" + title.substr(split + 1)
		button.text = title
		button.position = centre - button.size / 2.0
	_graph.queue_redraw()


func _draw_paths() -> void:
	for encounter in _route:
		var start: Button = _nodes[encounter]
		for next in DeckRun.route_successors(encounter, _route):
			var end: Button = _nodes.get(next)
			if end == null:
				continue
			var active := _cleared.has(encounter) and (_cleared.has(next) or _available.has(next))
			_graph.draw_line(
				start.position + start.size / 2.0,
				end.position + end.size / 2.0,
				ACTIVE_PATH if active else FUTURE_PATH,
				3.0,
				true
			)


func _on_retry_pressed() -> void:
	retry_requested.emit()
