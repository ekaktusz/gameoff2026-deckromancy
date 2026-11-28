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
@onready var _map_background: TextureRect = $MapBackground


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
	graveyard.unit_dropped.connect(_on_starting_unit_dropped.bind(graveyard))
	graveyard.continue_requested.connect(_show_map)


func _on_starting_unit_dropped(unit: UnitState, point: Vector2, graveyard: GraveyardView) -> void:
	if not graveyard.is_army_drop(point) or not _run.try_raise(unit, _starting_graveyard):
		graveyard.restore_drag_position(unit)
		return
	# ponytail: The starting army fills left to right within the shared drop zone.
	graveyard.display(_run, _starting_graveyard, true)


func _show_map() -> void:
	var cleared_bosses := 0
	for encounter in _run.cleared_encounters:
		cleared_bosses += int(encounter.is_boss)
	# ponytail: Load the numbered city backgrounds on demand.
	var background_path := "res://assets/city_%02d.png" % mini(cleared_bosses, 4)
	_map_background.texture = load(background_path) as Texture2D
	var map_view := MAP.instantiate() as MapView
	_show_screen(map_view)
	map_view.display(_run, encounters, _available_encounters())
	map_view.fight_requested.connect(_start_battle)
	map_view.retry_requested.connect(_start_run)


func _available_encounters() -> Array[EncounterDefinition]:
	if _run.defeated or encounters.is_empty():
		return []
	if _run.cleared_encounters.is_empty():
		return [encounters[0]]
	return DeckRun.route_successors(_run.cleared_encounters.back(), encounters)


func _start_battle(encounter: EncounterDefinition) -> void:
	if not _available_encounters().has(encounter):
		return
	var battle_view := BATTLE.instantiate() as BattleView
	_show_screen(battle_view)
	battle_view.display(BattleState.new(_run, encounter))
	battle_view.finished.connect(_on_battle_finished.bind(encounter))


func _on_battle_finished(won: bool, encounter: EncounterDefinition) -> void:
	if won:
		_run.cleared_encounters.append(encounter)
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
	_map_background.visible = screen is MapView
	if screen is Control:
		_screen_container.add_child(screen)
	else:
		_world.add_child(screen)
