extends Node
## Plays one-shot sound effects on the SFX bus. A small pool of players lets
## sounds overlap (a hover tick no longer cuts off a hit). Each call returns the
## player it used, so callers can await its `finished` signal.

const VOICES := 6

@export var click_sound: AudioStream

var _voices: Array[AudioStreamPlayer] = []

@onready var sfx_player: AudioStreamPlayer = $SfxPlayer


func _ready() -> void:
	_voices.append(sfx_player)
	for index in VOICES - 1:
		var voice := AudioStreamPlayer.new()
		voice.bus = sfx_player.bus
		voice.process_mode = sfx_player.process_mode
		add_child(voice)
		_voices.append(voice)


func play_sfx(stream: AudioStream) -> AudioStreamPlayer:
	var player := _free_voice()
	player.stream = stream
	player.play()
	return player


func play_click_sound() -> AudioStreamPlayer:
	return play_sfx(click_sound)


## The first idle player, or the one that has played longest when all are busy.
func _free_voice() -> AudioStreamPlayer:
	var oldest := _voices[0]
	for voice in _voices:
		if not voice.playing:
			return voice
		if voice.get_playback_position() > oldest.get_playback_position():
			oldest = voice
	return oldest
