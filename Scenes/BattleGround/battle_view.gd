class_name BattleView
extends Node2D
## The battle board. Every unit on the board has one persistent Card2D that is
## moved by tweens. BattleState resolves a whole round at once and returns
## BattleEvents, which are played back here one by one.

signal finished(won: bool)

const CARD_SCENE := preload("res://Scenes/Card/card_2d.tscn")
const ALLY := BattleEvent.Side.ALLY
const ENEMY := BattleEvent.Side.ENEMY
## Multiplies the speed of every battle animation. Raise it to speed up playtests.
const ANIM_SPEED := 1.0
const SWAP_ARC := 70.0
const DEAL_OFFSET := 760.0
const DAMAGE_COLOR := Color(1, 0.86, 0.74)
const RIP_GAIN_COLOR := Color(0.55, 1, 0.45)
const RIP_LOSS_COLOR := Color(1, 0.4, 0.35)

var _battle: BattleState
var _cards: Dictionary = {}
## Graveyard and RiP as the player has seen them so far; they lag behind the
## battle state while a round is being played back.
var _shown_dead: Array[UnitState] = []
var _shown_rp: int = 0
var _selected_column: int = -1
var _busy: bool = false

@onready var _enemy_slots: SlotRow = $EnemySlots
@onready var _ally_slots: SlotRow = $AllySlots
@onready var _card_layer: Node2D = $Cards
@onready var _graveyard: GraveyardView = $Graveyard
@onready var _fx: Node2D = $Fx
@onready var _title: Label = $HUD/Title
@onready var _status: Label = $HUD/Status
@onready var _rip: Label = $HUD/RiP
@onready var _action: Button = $HUD/Action


func display(battle: BattleState) -> void:
	_battle = battle
	_title.text = battle.encounter.title
	_status.text = "Click two of your slots to swap them, then resolve the round."
	_shown_rp = battle.run.rp
	_shown_dead = battle.graveyard.duplicate()
	for side: int in [ENEMY, ALLY]:
		var row := _row(side)
		for column in BattleState.COLUMN_COUNT:
			if row[column] != null:
				_add_card(row[column], side, _slot_position(side, column))
	await _deal_in()


func _deal_in() -> void:
	_busy = true
	_refresh()
	var tweens: Array[Tween] = []
	var index := 0
	for unit: UnitState in _cards:
		var card: Card2D = _cards[unit]
		var home := card.global_position
		var offset := -DEAL_OFFSET if card.look == Card2D.Look.ENEMY else DEAL_OFFSET
		card.global_position = home + Vector2(0, offset)
		var tween := card.create_tween()
		tween.tween_interval(_t(0.08) * index)
		(
			tween
			. tween_property(card, "global_position", home, _t(0.5))
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
		tweens.append(tween)
		index += 1
	await _wait_all(tweens)
	_busy = false
	_refresh()


func _refresh() -> void:
	var arranging := _battle.round_number == 0
	for unit: UnitState in _cards:
		var card: Card2D = _cards[unit]
		var is_ally := card.look == Card2D.Look.ALLY
		card.clickable = arranging and is_ally and not _busy
		card.selected = (
			arranging and _selected_column != -1 and _battle.allies.find(unit) == _selected_column
		)

	var targets: Array[int] = []
	if arranging and _selected_column != -1:
		for column in BattleState.COLUMN_COUNT:
			if column != _selected_column:
				targets.append(column)
	_ally_slots.highlighted = targets

	_refresh_rip()
	_graveyard.visible = not arranging
	if not arranging:
		_graveyard.display(_battle.run, _shown_dead)

	_action.disabled = _busy
	if arranging:
		_action.text = "Resolve round"
	elif _battle.run.army.is_empty():
		_action.text = "End run"
	elif _battle.enemies_defeated():
		_action.text = "Return to the city"
	else:
		_action.text = "Next round"


func _refresh_rip() -> void:
	_rip.text = "RiP  %d/%d" % [_shown_rp, DeckRun.MAX_RP]


## Snaps every card to the battle state: adds missing cards, frees cards of
## units that left the board and resets any leftover animation state.
func _sync() -> void:
	var on_board := {}
	for side: int in [ALLY, ENEMY]:
		var row := _row(side)
		for column in BattleState.COLUMN_COUNT:
			var unit := row[column]
			if unit == null:
				continue
			on_board[unit] = true
			var card: Card2D = _cards.get(unit)
			if card == null:
				card = _add_card(unit, side, _slot_position(side, column))
			card.global_position = _slot_position(side, column)
			card.rotation = 0.0
			card.scale = card.base_scale
			card.z_index = 0
			card.dimmed = false
			card.display(unit, _look(side))
	for unit: UnitState in _cards.keys():
		if not on_board.has(unit):
			(_cards[unit] as Card2D).queue_free()
			_cards.erase(unit)
	_shown_dead = _battle.graveyard.duplicate()
	_shown_rp = _battle.run.rp


func _add_card(unit: UnitState, side: int, at: Vector2) -> Card2D:
	var card := CARD_SCENE.instantiate() as Card2D
	_card_layer.add_child(card)
	card.global_position = at
	card.display(unit, _look(side))
	card.clicked.connect(_on_card_clicked.bind(unit))
	_cards[unit] = card
	return card


func _on_card_clicked(unit: UnitState) -> void:
	if _busy or _battle.round_number != 0:
		return
	var column := _battle.allies.find(unit)
	if column != -1:
		_select_slot(column)


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _busy or _battle == null or _battle.round_number != 0 or _selected_column == -1:
		return
	var column := _ally_slots.column_at(get_global_mouse_position())
	if column != -1 and _battle.allies[column] == null:
		get_viewport().set_input_as_handled()
		_select_slot(column)


## First click picks a slot holding a card; the second swaps it with any slot.
func _select_slot(column: int) -> void:
	if _selected_column == -1:
		if _battle.allies[column] != null:
			_selected_column = column
		_refresh()
		return
	if column == _selected_column:
		_selected_column = -1
		_refresh()
		return

	var first := _selected_column
	_selected_column = -1
	_battle.swap_allies(first, column)
	_busy = true
	_refresh()
	var tweens: Array[Tween] = []
	for slot: int in [first, column]:
		var unit := _battle.allies[slot]
		if unit != null:
			var arc := SWAP_ARC if slot == column else -SWAP_ARC
			tweens.append(
				(_cards[unit] as Card2D).move_to(_slot_position(ALLY, slot), _t(0.3), arc)
			)
	await _wait_all(tweens)
	_busy = false
	_refresh()


func _on_raise_requested(unit: UnitState) -> void:
	if _busy:
		return
	var from := _graveyard.card_global_position(unit)
	var column := _battle.try_raise(unit)
	if column == -1:
		return

	_busy = true
	_shown_dead = _battle.graveyard.duplicate()
	_shown_rp = _battle.run.rp
	var card := _add_card(unit, ALLY, from)
	card.scale = Vector2.ONE * _graveyard.card_scale
	card.z_index = 10
	_refresh()
	var grow := card.create_tween()
	grow.tween_property(card, "scale", card.base_scale, _t(0.4))
	await _wait(card.move_to(_slot_position(ALLY, column), _t(0.4)))
	await _wait(card.pop(_t(0.25)))
	card.z_index = 0
	_busy = false
	_refresh()


func _on_action_pressed() -> void:
	if _busy:
		return
	if _battle.run.army.is_empty():
		finished.emit(false)
		return
	if _battle.enemies_defeated():
		finished.emit(true)
		return

	var previous_rp := _battle.run.rp
	var previous_dead := _battle.graveyard.size()
	_selected_column = -1
	_busy = true
	_action.disabled = true
	_ally_slots.highlighted = []
	for unit: UnitState in _cards:
		(_cards[unit] as Card2D).clickable = false
		(_cards[unit] as Card2D).selected = false

	var events := _battle.resolve_round()
	await _play(events)

	_status.text = (
		"Round %d  ·  %d shifted  ·  %d fallen  ·  %+d RiP"
		% [
			_battle.round_number,
			_battle.last_shift_count,
			_battle.graveyard.size() - previous_dead,
			_battle.run.rp - previous_rp,
		]
	)
	_sync()
	_busy = false
	_refresh()


func _play(events: Array[BattleEvent]) -> void:
	var index := 0
	var shifts: Array[BattleEvent] = []
	while index < events.size() and events[index].kind == BattleEvent.Kind.SHIFT:
		shifts.append(events[index])
		index += 1
	await _play_shifts(shifts)
	while index < events.size():
		await _play_event(events[index])
		index += 1


## All shifts of a round slide at once. A unit can shift twice (its pattern,
## then the stalemate fallback), so each card only travels to its last column.
## Cards trading places arc past each other.
func _play_shifts(shifts: Array[BattleEvent]) -> void:
	if shifts.is_empty():
		return
	var last_move := {}
	for event in shifts:
		last_move[event.unit] = event
	var tweens: Array[Tween] = []
	for unit: UnitState in last_move:
		var event: BattleEvent = last_move[unit]
		var card: Card2D = _cards.get(unit)
		if card == null:
			continue
		var arc := 0.0
		for other in shifts:
			var trades_places := (
				other.side == event.side
				and other.column == event.to_column
				and other.to_column == event.column
			)
			if other != event and trades_places:
				arc = SWAP_ARC if event.to_column > event.column else -SWAP_ARC
		tweens.append(card.move_to(_slot_position(event.side, event.to_column), _t(0.3), arc))
	await _wait_all(tweens)


func _play_event(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.ATTACK:
			await _play_attack(event)
		BattleEvent.Kind.DEATH:
			await _play_death(event)
		BattleEvent.Kind.RIP:
			await _play_rip(event)


func _play_attack(event: BattleEvent) -> void:
	var attacker: Card2D = _cards.get(event.unit)
	if attacker == null:
		return
	var defender: Card2D = _cards.get(event.target) if event.target != null else null
	var point := _slot_position(ENEMY if event.side == ALLY else ALLY, event.column)
	var on_impact := func() -> void:
		if defender == null:
			return
		defender.hit(event.amount, _t(0.3))
		var above := defender.global_position + Vector2(0, -70)
		FloatingText.spawn(_fx, "-%d" % event.amount, DAMAGE_COLOR, above, Vector2.INF, _t(0.8))
	await _wait(attacker.lunge(point, _t(0.4), on_impact))


func _play_death(event: BattleEvent) -> void:
	var card: Card2D = _cards.get(event.unit)
	if card != null:
		_cards.erase(event.unit)
		await _wait(card.die(_t(0.35)))
		card.queue_free()
	_shown_dead.append(event.unit)
	_graveyard.visible = true
	_graveyard.display(_battle.run, _shown_dead)


func _play_rip(event: BattleEvent) -> void:
	var from := _slot_position(event.side, event.column)
	var color := RIP_GAIN_COLOR if event.amount > 0 else RIP_LOSS_COLOR
	var to := _rip.global_position + _rip.size / 2
	await _wait(FloatingText.spawn(_fx, "%+d RiP" % event.amount, color, from, to, _t(0.7)))
	_shown_rp += event.amount
	_refresh_rip()


func _row(side: int) -> Array[UnitState]:
	return _battle.allies if side == ALLY else _battle.enemies


func _slot_position(side: int, column: int) -> Vector2:
	var slots := _ally_slots if side == ALLY else _enemy_slots
	return slots.slot_position(column)


func _look(side: int) -> Card2D.Look:
	return Card2D.Look.ALLY if side == ALLY else Card2D.Look.ENEMY


func _t(seconds: float) -> float:
	return seconds / ANIM_SPEED


## Awaits a tween, unless it already finished (awaiting a signal that will never
## fire again would hang the battle).
func _wait(tween: Tween) -> void:
	if tween != null and tween.is_valid() and tween.is_running():
		await tween.finished


func _wait_all(tweens: Array[Tween]) -> void:
	for tween in tweens:
		await _wait(tween)
