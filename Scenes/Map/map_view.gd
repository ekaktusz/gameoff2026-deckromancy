class_name MapView
extends VBoxContainer

signal fight_requested(encounter: EncounterDefinition)
signal retry_requested


class EncounterButton:
	extends Button

	func _make_custom_tooltip(text: String) -> Object:
		var preview := Label.new()
		preview.theme_type_variation = &"TooltipLabel"
		preview.text = text
		preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview.add_theme_constant_override("line_spacing", -5)
		return preview


const CARD_SCENE := preload("res://Scenes/Card/card_2d.tscn")
const ACTIVE_PATH := Color(0.84, 0.66, 0.41)
const FUTURE_PATH := Color(0.27, 0.24, 0.21)
const LANE_HEIGHT := 88.0

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
	run: DeckRun,
	route: Array[EncounterDefinition],
	available: Array[EncounterDefinition],
	enemy_pool: Array[UnitDefinition],
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
		var button := EncounterButton.new()
		button.accessibility_name = encounter.title
		button.disabled = not available.has(encounter)
		_graph.add_child(button)
		var title := Label.new()
		title.name = "Title"
		title.text = encounter.title
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.clip_text = true
		title.add_theme_constant_override("line_spacing", -9)
		title.add_theme_font_size_override("font_size", 18 if encounter.is_boss else 17)
		var color := button.get_theme_color(
			"font_disabled_color" if button.disabled else "font_color"
		)
		var lineup := run.enemy_lineup(encounter, enemy_pool)
		button.tooltip_text = _enemy_types(lineup, encounter.is_boss)
		if encounter.is_boss and not button.disabled:
			color = Color(0.27, 0.11, 0.10)
		if _cleared.has(encounter):
			color = Color(0.12, 0.26, 0.13)
			button.tooltip_text = "Cleared"
		title.add_theme_color_override("font_color", color)
		button.add_child(title)
		title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title.offset_left = 15
		title.offset_right = -15
		button.pressed.connect(fight_requested.emit.bind(encounter))
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


func _enemy_types(lineup: Array[UnitDefinition], is_boss: bool) -> String:
	var counts: Dictionary[String, int] = {}
	var default_type := "Boss" if is_boss else "Enemy"
	for index in mini(lineup.size(), DeckRun.MAX_UNITS):
		var enemy := lineup[index]
		if enemy == null:
			continue
		var type: String = UnitDefinition.FACTION_NAMES.get(enemy.faction, default_type)
		counts[type] = counts.get(type, 0) + 1
	var summary := PackedStringArray()
	for type in counts:
		summary.append("%d× %s" % [counts[type], type])
	return "\n".join(summary)


func _stage(encounter: EncounterDefinition, index: int) -> int:
	return encounter.map_stage if encounter.map_stage > 0 else index + 1


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
		button.size = Vector2(minf(stage_width - 6.0, 220.0), 66.0)
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
