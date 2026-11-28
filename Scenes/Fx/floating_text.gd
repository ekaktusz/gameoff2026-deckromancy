class_name FloatingText
extends Label
## A short-lived label that drifts from one point to another, fades and frees
## itself. Used for damage, stat changes, and RiP gains.

const SIZE := Vector2(240, 52)


## Spawns the text centred on `from` (global). It rises a little, or flies to
## `to` when one is given. Returns the tween so callers can await it.
static func spawn(
	parent: Node,
	message: String,
	color: Color,
	from: Vector2,
	to: Vector2 = Vector2.INF,
	duration: float = 0.8,
) -> Tween:
	var label := FloatingText.new()
	label.text = message
	label.size = SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	parent.add_child(label)
	label.global_position = from - SIZE / 2

	var destination := from + Vector2(0, -80) if to == Vector2.INF else to
	var tween := label.create_tween().set_parallel()
	var drift := tween.tween_property(label, "global_position", destination - SIZE / 2, duration)
	drift.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	tween.chain().tween_callback(label.queue_free)
	return tween
