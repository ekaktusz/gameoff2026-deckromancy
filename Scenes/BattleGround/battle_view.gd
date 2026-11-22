class_name BattleView
extends VBoxContainer

signal finished(won: bool)

const CARD_SCENE := preload("res://Scenes/Card/card_scene.tscn")

var _battle: BattleState
var _selected_column: int = -1
var _ally_cards: Array[CardView] = []
var _enemy_cards: Array[CardView] = []

@onready var _title: Label = $Title
@onready var _status: Label = $Status
@onready var _allies: HBoxContainer = $Allies
@onready var _enemies: HBoxContainer = $Enemies
@onready var _graveyard: GraveyardView = $Graveyard
@onready var _action: Button = $Action


func _ready() -> void:
	for column in BattleState.COLUMN_COUNT:
		var enemy := CARD_SCENE.instantiate() as CardView
		enemy.disabled = true
		_enemies.add_child(enemy)
		_enemy_cards.append(enemy)

		var ally := CARD_SCENE.instantiate() as CardView
		ally.disabled = true
		ally.toggle_mode = true
		ally.pressed.connect(_on_ally_pressed.bind(column))
		_allies.add_child(ally)
		_ally_cards.append(ally)


func display(battle: BattleState) -> void:
	_battle = battle
	_title.text = battle.encounter.title
	_status.text = "%d/%d RiP  ·  Select two slots to swap their positions." % [
		battle.run.rp,
		DeckRun.MAX_RP,
	]
	_refresh()


func _refresh() -> void:
	var arranging := _battle.round_number == 0
	for column in BattleState.COLUMN_COUNT:
		_enemy_cards[column].display(_battle.enemies[column])
		_ally_cards[column].display(_battle.allies[column])
		_ally_cards[column].disabled = not arranging
		_ally_cards[column].set_pressed_no_signal(arranging and column == _selected_column)

	_action.disabled = false
	_graveyard.visible = not arranging
	if arranging:
		_action.text = "Resolve round"
		return

	_graveyard.display(_battle.run, _battle.graveyard)
	if _battle.run.army.is_empty():
		_action.text = "End run"
	elif _battle.enemies_defeated():
		_action.text = "Return to the city"
	else:
		_action.text = "Next round"


func _on_ally_pressed(column: int) -> void:
	if _selected_column == -1:
		_selected_column = column
	else:
		_battle.swap_allies(_selected_column, column)
		_selected_column = -1
	_refresh()


func _on_raise_requested(unit: UnitState) -> void:
	if _battle.try_raise(unit):
		_refresh()


func _on_action_pressed() -> void:
	if _battle.run.army.is_empty():
		finished.emit(false)
		return
	if _battle.enemies_defeated():
		finished.emit(true)
		return

	var previous_rp := _battle.run.rp
	var previous_dead := _battle.graveyard.size()
	_battle.resolve_round()
	_status.text = "Round %d  ·  %d shifted  ·  %d fallen  ·  %+d RiP" % [
		_battle.round_number,
		_battle.last_shift_count,
		_battle.graveyard.size() - previous_dead,
		_battle.run.rp - previous_rp,
	]
	_refresh()
