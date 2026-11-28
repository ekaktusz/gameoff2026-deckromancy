class_name Card2D
extends Node2D
## A unit card drawn in 2D: portrait, name, abilities, ATK and HP badges and
## MARK pips. Positions are the card's centre. The helpers at the bottom return
## tweens so the battle screen can chain or await them.

signal clicked
signal dragged(point: Vector2)
signal dropped(point: Vector2)
signal drag_cancelled

enum Look { ALLY, ENEMY, DEAD }

const SIZE := Vector2(220, 300)
const ART_RECT := Rect2(-68, -100, 136, 142)
const FRAMES := [
	preload("res://assets/cards/card bg own transparent middle.png"),
	preload("res://assets/cards/card bg own transparent middle broken.png"),
	preload("res://assets/cards/card bg own transparent middle broken 2.png"),
	preload("res://assets/cards/card bg own transparent middle broken 3.png"),
]
const POOP_PORTRAIT := preload("res://assets/units/poop_warrior.png")
const DIMMED := Color(0.5, 0.5, 0.5)
const HIT_FLASH := Color(1.7, 0.5, 0.45)
const HOVER_SFX := preload("res://assets/sfx/hover.tres")
const SELECT_SFX := preload("res://assets/sfx/select.wav")
const DRAG_THRESHOLD := 10.0
const NAME_FONT_SIZE := 17
const NAME_MIN_FONT_SIZE := 13
const HOVER_Z := 5
const DRAG_Z := 32

static var _opaque_bounds: Dictionary[Texture2D, Rect2] = {}

var unit: UnitState
var look: Look = Look.ALLY
## Whether clicks emit `clicked`.
var clickable: bool = false:
	set(value):
		clickable = value
		if not clickable and not draggable:
			_cancel_pointer()
var draggable: bool = false:
	set(value):
		draggable = value
		if not draggable and (_dragging or not clickable):
			_cancel_pointer()
var hover_enabled: bool = true:
	set(value):
		hover_enabled = value
		if not value:
			_set_hovered(false, true)
## Greys the card out, e.g. a graveyard card you cannot afford to raise.
var dimmed: bool = false:
	set(value):
		dimmed = value
		_art_modulate = _rest_modulate()
## Scale the card rests at; animations return to it.
var base_scale: Vector2 = Vector2.ONE:
	set(value):
		base_scale = value
		scale = value

var _marks: int = 0
var _portrait_gradient: GradientTexture1D
var _hovered: bool = false
var _hover_tween: Tween
var _pop_tween: Tween
var _pressed: bool = false
var _dragging: bool = false
var _press_position: Vector2
var _drag_origin: Vector2
var _art_modulate: Color = Color.WHITE:
	set(value):
		_art_modulate = value
		if _attack == null:
			return
		for child in get_children():
			if child is CanvasItem and child != _attack and child != _hp:
				child.modulate = value

@onready var _portrait: Sprite2D = $Portrait
@onready var _default_portrait_material := _portrait.material as ShaderMaterial
@onready var _plant_overlay: Sprite2D = $Portrait/PlantOverlay
@onready var _frame: Sprite2D = $Frame
@onready var _marks_layer: Node2D = $Marks
@onready var _name: Label = $Name
@onready var _faction: Label = $Faction
@onready var _ability: Label = $Ability
@onready var _attack: Label = $Attack
@onready var _hp: Label = $HP


func _ready() -> void:
	_marks_layer.draw.connect(_draw_marks)
	_art_modulate = _rest_modulate()
	_update_stat_color(null)


func _set_portrait_gradient(gradient: GradientTexture1D) -> void:
	if gradient == _portrait_gradient:
		return
	_portrait_gradient = gradient
	_update_stat_color(gradient)
	if gradient == null:
		_portrait.material = _default_portrait_material
		return
	var gradient_material := _default_portrait_material.duplicate() as ShaderMaterial
	gradient_material.set_shader_parameter("gradient_map", gradient)
	_portrait.material = gradient_material


func _update_stat_color(gradient: GradientTexture1D) -> void:
	if gradient == null or gradient.gradient == null:
		gradient = _default_portrait_material.get_shader_parameter("gradient_map")
	if gradient == null or gradient.gradient == null:
		return
	var color := gradient.gradient.sample(0.0)
	for stop in gradient.gradient.colors:
		if stop.s * stop.v > color.s * color.v:
			color = stop
	color.a = 1.0
	_attack.add_theme_color_override("font_color", color)
	_hp.add_theme_color_override("font_color", color)


## Shows a unit. With `for_revival` it previews the unit as it would come back
## from the graveyard (next MARK and reduced stats).
## Call after the card is in the tree.
func display(unit_state: UnitState, card_look: Look, for_revival: bool = false) -> void:
	unit = unit_state
	look = card_look
	_set_portrait_gradient(unit.portrait_gradient)
	var stats := (
		unit.revival_stats() if for_revival else Vector2i(unit.combat_attack(), unit.combat_hp())
	)
	_marks = unit.marks + int(for_revival)
	var is_poop := unit.is_poop_warrior(for_revival)
	fit_name(unit.title(for_revival))
	_faction.text = "" if is_poop else UnitDefinition.FACTION_NAMES.get(unit.definition.faction, "")
	var ability := unit.definition.battle_ability(look == Look.ENEMY)
	_ability.text = "" if is_poop else UnitDefinition.ABILITY_DESCRIPTIONS.get(ability, "")
	_attack.text = str(stats.x)
	_hp.text = str(stats.y)
	_frame.texture = FRAMES[clampi(_marks - 1, 0, FRAMES.size() - 1)]
	_marks_layer.queue_redraw()
	_update_portrait(is_poop)


## Sets the name, shrinking the font so long names fit the name plaque.
func fit_name(title: String) -> void:
	_name.text = title
	var font := _name.get_theme_font("font")
	var font_size := NAME_FONT_SIZE
	while (
		font_size > NAME_MIN_FONT_SIZE
		and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > _name.size.x
	):
		font_size -= 1
	_name.add_theme_font_size_override("font_size", font_size)


func _update_portrait(is_poop: bool) -> void:
	var definition := unit.definition
	var texture: Texture2D = POOP_PORTRAIT if is_poop else definition.portrait
	var overlay: Texture2D = null if is_poop else definition.mark_overlay
	var tint := Color.WHITE if is_poop else definition.portrait_tint
	_plant_overlay.texture = overlay
	_plant_overlay.visible = overlay != null and unit.marks > 0
	if not is_poop and _marks > 0 and overlay == null and definition.marked_portrait != null:
		texture = definition.marked_portrait

	_portrait.visible = texture != null
	if texture == null:
		return
	_portrait.texture = texture
	_portrait.self_modulate = tint
	_plant_overlay.self_modulate = tint
	var bounds := _texture_bounds(texture)
	if overlay != null:
		# Use the same fit before and after a MARK so the art and plant stay aligned.
		bounds = bounds.merge(_texture_bounds(overlay))
	var fit := minf(ART_RECT.size.x / bounds.size.x, ART_RECT.size.y / bounds.size.y)
	var art_offset := texture.get_size() / 2.0 - bounds.get_center()
	_portrait.position = ART_RECT.get_center() + art_offset * fit
	_portrait.scale = Vector2(fit, fit)


func _texture_bounds(texture: Texture2D) -> Rect2:
	if not _opaque_bounds.has(texture):
		var bounds := Rect2(Vector2.ZERO, texture.get_size())
		var image := texture.get_image()
		if image != null and not image.is_compressed():
			var used := image.get_used_rect()
			if used.has_area():
				bounds = Rect2(used)
		_opaque_bounds[texture] = bounds
	return _opaque_bounds[texture]


func _draw_marks() -> void:
	for mark in mini(_marks, UnitState.POOP_MARKS):
		var pip := Vector2(77, -92 + mark * 29)
		_marks_layer.draw_circle(pip, 5.0, Color(0.65, 1.0, 0.36))


func _process(_delta: float) -> void:
	if _pressed and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_cancel_pointer()
	if not _pressed:
		_set_hovered(
			hover_enabled and is_visible_in_tree() and _contains_point(get_global_mouse_position())
		)


func _set_hovered(value: bool, immediate: bool = false) -> void:
	if _hovered == value and not (immediate and _hover_tween != null and _hover_tween.is_running()):
		return
	_hovered = value
	if _hover_tween != null:
		_hover_tween.kill()
	var enlarged := 1.38 if look == Look.DEAD else 1.14
	var target_scale := base_scale * enlarged if value else base_scale
	if value:
		if _pop_tween != null and _pop_tween.is_running():
			_pop_tween.kill()
		z_index = HOVER_Z
		if clickable or draggable:
			SoundManager.play_sfx(HOVER_SFX)
	elif z_index == HOVER_Z:
		z_index = 0
	if immediate:
		scale = target_scale
	else:
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "scale", target_scale, 0.12)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if (
		button == null
		or button.button_index != MOUSE_BUTTON_LEFT
		or not button.pressed
		or not (clickable or draggable)
		or not is_visible_in_tree()
	):
		return
	var point := get_canvas_transform().affine_inverse() * button.position
	if not _contains_point(point):
		return
	get_viewport().set_input_as_handled()
	_pressed = true
	_press_position = point
	_drag_origin = global_position


func _input(event: InputEvent) -> void:
	var mouse := event as InputEventMouse
	if not _pressed or mouse == null:
		return
	var point := get_canvas_transform().affine_inverse() * mouse.position
	if event is InputEventMouseMotion and draggable:
		if not _dragging and point.distance_to(_press_position) >= DRAG_THRESHOLD:
			_dragging = true
			_set_hovered(false, true)
			z_index = DRAG_Z
			SoundManager.play_sfx(SELECT_SFX)
		if _dragging:
			get_viewport().set_input_as_handled()
			global_position = _drag_origin + point - _press_position
			dragged.emit(point)
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or button.pressed:
		return
	get_viewport().set_input_as_handled()
	_pressed = false
	if _dragging:
		_dragging = false
		z_index = 0
		global_position = _drag_origin + point - _press_position
		dropped.emit(point)
	elif clickable and _contains_point(point):
		SoundManager.play_sfx(SELECT_SFX)
		clicked.emit()


func restore_drag_position() -> void:
	global_position = _drag_origin


func _cancel_pointer() -> void:
	_pressed = false
	if _dragging:
		_dragging = false
		z_index = 0
		restore_drag_position()
		drag_cancelled.emit()


func _contains_point(global_point: Vector2) -> bool:
	var point := to_local(global_point) * scale / base_scale
	return Rect2(-SIZE / 2, SIZE).has_point(point)


func _rest_modulate() -> Color:
	return DIMMED if dimmed else Color.WHITE


## Slides to a global position. A non-zero `arc` lifts the path (negative dips),
## so two cards swapping places pass each other instead of overlapping.
func move_to(target: Vector2, duration: float, arc: float = 0.0) -> Tween:
	var start := global_position
	var tween := create_tween()
	var step := func(progress: float) -> void:
		global_position = start.lerp(target, progress) + Vector2(0, -arc * sin(progress * PI))
	tween.tween_method(step, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	return tween


## Lunges part of the way toward `point` and back. `on_impact` runs at the
## furthest point, which is where the hit should land.
func lunge(point: Vector2, duration: float, on_impact: Callable) -> Tween:
	var home := global_position
	var impact := Vector2(move_toward(point.x, home.x, SIZE.x * 0.45), lerpf(home.y, point.y, 0.38))
	z_index = 10
	var tween := create_tween()
	(
		tween
		. tween_property(self, "global_position", impact, duration * 0.45)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_IN)
	)
	tween.tween_callback(on_impact)
	(
		tween
		. tween_property(self, "global_position", home, duration * 0.55)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_callback(func() -> void: z_index = 0)
	return tween


## Takes a hit: the HP badge counts down, the card flashes red and shakes.
func hit(remaining_hp: int, duration: float) -> Tween:
	_hp.text = str(remaining_hp)
	var tween := create_tween()
	tween.tween_property(self, "_art_modulate", HIT_FLASH, duration * 0.2)
	tween.parallel().tween_property(self, "rotation", 0.09, duration * 0.2)
	tween.tween_property(self, "rotation", -0.07, duration * 0.25)
	tween.tween_property(self, "rotation", 0.0, duration * 0.25)
	tween.parallel().tween_property(self, "_art_modulate", _rest_modulate(), duration * 0.55)
	return tween


## Tilts, shrinks and fades out. The caller frees the card afterwards.
func die(duration: float) -> Tween:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "rotation", 0.4, duration).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", base_scale * 0.55, duration).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	return tween


## Pops in from slightly larger, for cards that just appeared.
func pop(duration: float = 0.3) -> Tween:
	scale = base_scale * 1.25
	_pop_tween = create_tween()
	(
		_pop_tween
		. tween_property(self, "scale", base_scale, duration)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	return _pop_tween
