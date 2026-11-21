extends Control

const GAME_LOOP := preload("res://game_loop.tscn")


func _on_exit_button_pressed() -> void:
	await SoundManager.play_click_sound().finished
	get_tree().quit()


func _on_start_button_pressed() -> void:
	$VBoxContainer/StartButton.disabled = true
	await SoundManager.play_click_sound().finished
	get_tree().change_scene_to_packed(GAME_LOOP)
