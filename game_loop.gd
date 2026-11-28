extends Control

const GRAVEYARD := preload("res://Scenes/Graveyard/graveyard_scene.tscn")
const MAP := preload("res://Scenes/Map/map_scene.tscn")
const BATTLE := preload("res://Scenes/BattleGround/battle_ground.tscn")
const STORY_BOX := preload("res://Scenes/Story/story_box.gd")
const STARTING_OFFER_SIZE := 4

@export var enemy_pool: Array[UnitDefinition] = []
@export var encounters: Array[EncounterDefinition] = []

var _run: DeckRun
var _starting_graveyard: Array[UnitState] = []
var _screen: CanvasItem

@onready var _screen_container: MarginContainer = $Screen
@onready var _world: Node2D = $World
@onready var _map_background: TextureRect = $MapBackground
@onready var _story: STORY_BOX = $StoryBox


func _ready() -> void:
	MusicPlayer.start_music()
	_show_city_story(0, STORY_BOX.INTRO, _start_run)


func _restart_run() -> void:
	for connection in _story.dismissed.get_connections():
		_story.dismissed.disconnect(connection.callable)
	_story.close()
	_start_run()


func _start_run() -> void:
	_run = DeckRun.new()
	_starting_graveyard.clear()
	# ponytail: Draw the starting offer from the same nine base units used by regular fights.
	var pool := enemy_pool.filter(func(unit: UnitDefinition) -> bool: return unit != null)
	pool.shuffle()
	for unit in pool.slice(0, STARTING_OFFER_SIZE):
		_starting_graveyard.append(UnitState.new(unit))

	var graveyard := GRAVEYARD.instantiate() as GraveyardView
	_show_screen(graveyard)
	graveyard.unit_dropped.connect(_on_starting_unit_dropped.bind(graveyard))
	graveyard.continue_requested.connect(_show_map)
	_story.dismissed.connect(
		graveyard.display.bind(_run, _starting_graveyard, true), CONNECT_ONE_SHOT
	)
	_story.display(STORY_BOX.CEMETERY, graveyard.get_node("Background"))


func _on_starting_unit_dropped(unit: UnitState, point: Vector2, graveyard: GraveyardView) -> void:
	var slot := graveyard.army_slot_at(point)
	if slot == -1:
		graveyard.restore_drag_position(unit)
		return
	var occupant := _run.starting_slots.find_key(slot) as UnitState
	if _run.starting_slots.has(unit):
		if occupant != null:
			_run.starting_slots[occupant] = _run.starting_slots[unit]
	elif (
		occupant != null
		or _run.army.size() >= DeckRun.STARTING_ARMY_SIZE
		or not _run.try_raise(unit, _starting_graveyard)
	):
		graveyard.restore_drag_position(unit)
		return
	_run.starting_slots[unit] = slot
	graveyard.display(_run, _starting_graveyard, true)


func _city_stage() -> int:
	var cleared_bosses := 0
	for encounter in _run.cleared_encounters:
		cleared_bosses += int(encounter.is_boss)
	return mini(cleared_bosses, STORY_BOX.AFTER_BOSS.size())


func _set_city_background(stage: int) -> void:
	# ponytail: Load the numbered city backgrounds on demand.
	var background_path := "res://assets/backgrounds/city_%02d.png" % stage
	_map_background.texture = load(background_path) as Texture2D


func _show_city_story(stage: int, copy: String, next: Callable) -> void:
	_show_screen(null)
	_set_city_background(stage)
	_map_background.show()
	_story.dismissed.connect(next, CONNECT_ONE_SHOT)
	_story.display(copy, _map_background)


func _show_map() -> void:
	_set_city_background(_city_stage())
	var map_view := MAP.instantiate() as MapView
	_show_screen(map_view)
	map_view.display(_run, encounters, _available_encounters(), enemy_pool)
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
	var battle := BattleState.new(_run, encounter, enemy_pool)
	_show_screen(battle_view)
	battle_view.display(battle)
	battle_view.finished.connect(_on_battle_finished.bind(encounter))
	if _run.cleared_encounters.is_empty():
		battle_view.process_mode = Node.PROCESS_MODE_DISABLED
		_story.dismissed.connect(
			func() -> void: battle_view.process_mode = Node.PROCESS_MODE_INHERIT, CONNECT_ONE_SHOT
		)
		_story.display(STORY_BOX.FIRST_FIGHT, null, true)


func _on_battle_finished(won: bool, encounter: EncounterDefinition) -> void:
	if won:
		_run.cleared_encounters.append(encounter)
		if encounter.is_boss:
			var stage := _city_stage()
			_show_city_story(stage, STORY_BOX.AFTER_BOSS[stage - 1], _show_map)
			return
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
	elif screen != null:
		_world.add_child(screen)
