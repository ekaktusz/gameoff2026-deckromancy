extends Control

const GRAVEYARD := preload("res://Scenes/Graveyard/graveyard_scene.tscn")
const MAP := preload("res://Scenes/Map/map_scene.tscn")
const BATTLE := preload("res://Scenes/BattleGround/battle_ground.tscn")

@export var starting_units: Array[UnitDefinition] = []
@export var encounters: Array[EncounterDefinition] = []

var _run: DeckRun
var _starting_graveyard: Array[UnitState] = []
var _screen: CanvasItem

@onready var _screen_container: MarginContainer = $Screen
@onready var _world: Node2D = $World


func _ready() -> void:
	MusicPlayer.start_music()
	_start_run()


func _start_run() -> void:
	_run = DeckRun.new()
	_starting_graveyard.clear()
	for unit in starting_units:
		_starting_graveyard.append(UnitState.new(unit))

	var graveyard := GRAVEYARD.instantiate() as GraveyardView
	_show_screen(graveyard)
	graveyard.display(_run, _starting_graveyard, true)
	graveyard.raise_requested.connect(_on_starting_raise_requested.bind(graveyard))
	graveyard.continue_requested.connect(_show_map)


func _on_starting_raise_requested(unit: UnitState, graveyard: GraveyardView) -> void:
	if _run.try_raise(unit, _starting_graveyard):
		graveyard.display(_run, _starting_graveyard, true)


func _show_map() -> void:
	var map_view := MAP.instantiate() as MapView
	_show_screen(map_view)
	map_view.display(_run, encounters)
	map_view.fight_requested.connect(_start_battle)
	map_view.retry_requested.connect(_start_run)


func _start_battle() -> void:
	var battle_view := BATTLE.instantiate() as BattleView
	_show_screen(battle_view)
	battle_view.display(BattleState.new(_run, encounters[_run.encounter_index]))
	battle_view.finished.connect(_on_battle_finished)


func _on_battle_finished(won: bool) -> void:
	if won:
		_run.encounter_index += 1
	else:
		_run.defeated = true
	_show_map()


## Control screens (the map) go into the margin container; Node2D screens
## (graveyard, battle) are placed in world space at the viewport origin.
func _show_screen(screen: CanvasItem) -> void:
	if _screen != null:
		_screen.get_parent().remove_child(_screen)
		_screen.queue_free()
	_screen = screen
	if screen is Control:
		_screen_container.add_child(screen)
	else:
		_world.add_child(screen)
