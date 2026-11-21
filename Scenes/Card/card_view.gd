class_name CardView
extends Button


func display(unit: UnitState, for_revival: bool = false) -> void:
	if unit == null:
		text = "Empty"
		return

	var stats := Vector2i(unit.attack, unit.hp)
	if for_revival:
		stats = unit.revival_stats()

	var name_and_marks := unit.title(for_revival)
	var marks := unit.revivals + int(for_revival)
	if marks > 0:
		name_and_marks += "  ·  %d MARK" % marks

	text = "%s\n%d ATK   %d HP" % [name_and_marks, stats.x, stats.y]
	if for_revival:
		text += "\nRaise · 1 RP"
