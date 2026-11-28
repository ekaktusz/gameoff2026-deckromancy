extends Node

@warning_ignore("unused_signal")
signal menu_back_pressed


func _ready() -> void:
	# Set the runtime font after Godot has imported it on a fresh checkout.
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/HoldMoney-Regular.ttf") as Font
	# Hold Money is narrow and thin; widen and thicken it so small text stays readable.
	font.variation_embolden = 0.5
	font.spacing_glyph = 1
	font.spacing_space = 2
	ThemeDB.get_default_theme().default_font = font
