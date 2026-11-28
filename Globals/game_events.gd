extends Node

@warning_ignore("unused_signal")
signal menu_back_pressed


func _ready() -> void:
	# Set the runtime font after Godot has imported it on a fresh checkout.
	var font := load("res://assets/fonts/HoldMoney-Regular.ttf") as Font
	ThemeDB.get_default_theme().default_font = font
