extends Control

const MAIN_MENU: PackedScene = preload("uid://c64idl1pun738")

@onready var audio_player = $AspectRatioContainer/VideoStreamPlayer/AudioStreamPlayer2D
@onready var video_player = $AspectRatioContainer/VideoStreamPlayer


func _ready() -> void:
	# The video can stall startup in the single-threaded Web build.
	if OS.has_feature("web"):
		get_tree().change_scene_to_packed.call_deferred(MAIN_MENU)
		return

	video_player.play()
	video_player.paused = true


func _on_timer_timeout() -> void:
	video_player.paused = false
	audio_player.play()


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	get_tree().change_scene_to_packed(MAIN_MENU)
