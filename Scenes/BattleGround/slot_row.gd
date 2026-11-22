class_name SlotRow
extends Node2D
## One row of card slots. Each child Marker2D is a slot centre, so the layout can
## be moved around in the editor. Slots are drawn as faint frames so empty
## columns stay readable; highlighted slots glow (e.g. valid swap targets).

const FRAME_COLOR := Color(1, 1, 1, 0.18)
const HIGHLIGHT_COLOR := Color(0.62, 0.82, 1, 0.75)

var highlighted: Array[int] = []:
	set(value):
		highlighted = value
		queue_redraw()

var _style := StyleBoxFlat.new()


func _ready() -> void:
	_style.bg_color = Color(0, 0, 0, 0.22)
	_style.set_corner_radius_all(14)
	_style.set_border_width_all(3)


func slot_position(column: int) -> Vector2:
	return (get_child(column) as Node2D).global_position


## The column whose slot contains a global point, or -1.
func column_at(global_point: Vector2) -> int:
	for column in get_child_count():
		var rect := Rect2(slot_position(column) - Card2D.SIZE / 2, Card2D.SIZE)
		if rect.has_point(global_point):
			return column
	return -1


func _draw() -> void:
	for column in get_child_count():
		var centre := to_local(slot_position(column))
		_style.border_color = HIGHLIGHT_COLOR if highlighted.has(column) else FRAME_COLOR
		draw_style_box(_style, Rect2(centre - Card2D.SIZE / 2, Card2D.SIZE))
