extends Node

@warning_ignore("unused_signal")
signal menu_back_pressed


func _ready() -> void:
	# Load imported theme assets at runtime, after Godot's first import.
	var theme := ThemeDB.get_default_theme()
	theme.merge_with(load("res://UI/button_theme.tres") as Theme)
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/HoldMoney-Regular.ttf") as Font
	# Hold Money is narrow and thin; widen and thicken it so small text stays readable.
	font.variation_embolden = 0.5
	font.spacing_glyph = 1
	font.spacing_space = 2
	theme.default_font = font
