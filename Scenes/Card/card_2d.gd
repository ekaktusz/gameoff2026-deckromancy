class_name Card2D
extends Node2D
## A unit card drawn in 2D: portrait, name, shift pattern, ATK and HP badges and
## MARK pips. Positions are the card's centre. The helpers at the bottom return
## tweens so the battle screen can chain or await them.

signal clicked
signal dragged(point: Vector2)
signal dropped(point: Vector2)
signal drag_cancelled

enum Look { ALLY, ENEMY, DEAD }

const SIZE := Vector2(220, 300)
const ART_RECT := Rect2(-100, -112, 200, 160)
const ATTACK_BADGE := Vector2(-82, 122)
const HP_BADGE := Vector2(82, 122)
const BADGE_RADIUS := 26.0
const BORDER_COLORS := {
	Look.ALLY: Color(0.36, 0.52, 0.96),
	Look.ENEMY: Color(0.88, 0.3, 0.28),
	Look.DEAD: Color(0.55, 0.78, 0.38),
}
const BODY_COLOR := Color(0.13, 0.11, 0.1)
const ART_COLOR := Color(0.8, 0.76, 0.68)
const MARKED_TINT := Color(0.72, 0.95, 0.62)
const POOP_TINT := Color(0.62, 0.48, 0.32)
const DIMMED := Color(0.5, 0.5, 0.5)
const HIT_FLASH := Color(1.7, 0.5, 0.45)
const HOVER_SFX := preload("res://assets/sfx/hover.tres")
const SELECT_SFX := preload("res://assets/sfx/select.wav")
const DRAG_THRESHOLD := 10.0
const HOVER_Z := 5
const DRAG_Z := 30

var unit: UnitState
var look: Look = Look.ALLY
## Whether clicks emit `clicked`.
var clickable: bool = false:
	set(value):
		clickable = value
		if not value:
			_cancel_pointer()
		queue_redraw()
var draggable: bool = false
var hover_enabled: bool = true:
	set(value):
		hover_enabled = value
		if not value:
			_set_hovered(false, true)
## Greys the card out, e.g. a graveyard card you cannot afford to raise.
var dimmed: bool = false:
	set(value):
		dimmed = value
		modulate = _rest_modulate()
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## Scale the card rests at; animations return to it.
var base_scale: Vector2 = Vector2.ONE:
	set(value):
		base_scale = value
		scale = value

var _marks: int = 0
var _hovered: bool = false
var _hover_tween: Tween
var _pop_tween: Tween
var _pressed: bool = false
var _dragging: bool = false
var _press_position: Vector2
var _drag_origin: Vector2
var _body_style := StyleBoxFlat.new()

@onready var _portrait: Sprite2D = $Portrait
@onready var _marks_layer: Node2D = $Marks
@onready var _name: Label = $Name
@onready var _shift: Label = $Shift
@onready var _ability: Label = $Ability
@onready var _attack: Label = $Attack
@onready var _hp: Label = $HP


func _ready() -> void:
	_body_style.bg_color = BODY_COLOR
	_body_style.set_corner_radius_all(14)
	_body_style.shadow_color = Color(0, 0, 0, 0.45)
	_body_style.shadow_size = 8
	_body_style.shadow_offset = Vector2(0, 4)
	_marks_layer.draw.connect(_draw_marks)


## Shows a unit. With `for_revival` it previews the unit as it would come back
## from the graveyard (next MARK, reduced stats, starting shift direction).
## Call after the card is in the tree.
func display(unit_state: UnitState, card_look: Look, for_revival: bool = false) -> void:
	unit = unit_state
	look = card_look
	var stats := Vector2i(unit.combat_attack(), unit.combat_hp())
	var direction := unit.shift_direction
	if for_revival:
		stats = unit.revival_stats()
		direction = unit.definition.starting_shift_direction()
	_marks = unit.revivals + int(for_revival)
	_name.text = unit.title(for_revival)
	_shift.text = unit.shift_label(direction)
	_ability.text = unit.definition.ability_text()
	_attack.text = str(stats.x)
	_hp.text = str(stats.y)
	_marks_layer.queue_redraw()
	_update_portrait()
	queue_redraw()


func _update_portrait() -> void:
	var definition := unit.definition
	var texture := definition.portrait
	var tint := definition.portrait_tint
	if _marks > 0:
		if definition.marked_portrait != null:
			texture = definition.marked_portrait
		else:
			tint *= MARKED_TINT
	if _marks >= 4:
		tint *= POOP_TINT

	_portrait.visible = texture != null
	if texture == null:
		return
	_portrait.texture = texture
	_portrait.self_modulate = tint
	_portrait.position = ART_RECT.get_center()
	var fit := minf(ART_RECT.size.x / texture.get_width(), ART_RECT.size.y / texture.get_height())
	_portrait.scale = Vector2(fit, fit)


func _draw() -> void:
	var rect := Rect2(-SIZE / 2, SIZE)
	var border: Color = BORDER_COLORS[look]
	var highlighted := selected or (clickable and _hovered)
	_body_style.border_color = border.lightened(0.45) if highlighted else border
	_body_style.set_border_width_all(7 if highlighted else 4)
	draw_style_box(_body_style, rect)
	draw_rect(ART_RECT, ART_COLOR)

	draw_circle(ATTACK_BADGE, BADGE_RADIUS, Color(0.78, 0.6, 0.18))
	draw_circle(HP_BADGE, BADGE_RADIUS, Color(0.72, 0.18, 0.18))


func _draw_marks() -> void:
	for mark in mini(_marks, 4):
		var pip := ART_RECT.position + Vector2(14, 14 + mark * 19)
		_marks_layer.draw_circle(pip, 8, Color(0.1, 0.1, 0.1))
		_marks_layer.draw_circle(pip, 5.5, Color(0.65, 1.0, 0.36))


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
		if clickable:
			SoundManager.play_sfx(HOVER_SFX)
	elif z_index == HOVER_Z:
		z_index = 0
	if immediate:
		scale = target_scale
	else:
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "scale", target_scale, 0.12)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if (
		button == null
		or button.button_index != MOUSE_BUTTON_LEFT
		or not button.pressed
		or not clickable
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
	elif _contains_point(point):
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
	tween.tween_property(self, "modulate", HIT_FLASH, duration * 0.2)
	tween.parallel().tween_property(self, "rotation", 0.09, duration * 0.2)
	tween.tween_property(self, "rotation", -0.07, duration * 0.25)
	tween.tween_property(self, "rotation", 0.0, duration * 0.25)
	tween.parallel().tween_property(self, "modulate", _rest_modulate(), duration * 0.55)
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
