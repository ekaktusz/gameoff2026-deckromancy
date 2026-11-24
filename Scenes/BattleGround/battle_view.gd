class_name BattleView
extends Node2D
## The battle board. Every unit on the board has one persistent Card2D that is
## moved by tweens. Battle events are applied as their animations play.

signal finished(won: bool)

const CARD_SCENE := preload("res://Scenes/Card/card_2d.tscn")
## Picks one of the generated hit sounds with a random pitch each time.
const HIT_SFX := preload("res://assets/sfx/hit.tres")
const SHIFT_SFX := preload("res://assets/sfx/shift.tres")
const SELECT_SFX := preload("res://assets/sfx/select.wav")
## An attack that lands in an empty slot (either side).
const EMPTY_HIT_SFX := preload("res://assets/sfx/empty_hit.tres")
const RIP_GAIN_SFX := preload("res://assets/sfx/rip_gain.wav")
const RIP_LOSS_SFX := preload("res://assets/sfx/rip_loss.wav")
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
@onready var _sacrifice: Button = $HUD/Sacrifice


func display(battle: BattleState) -> void:
	_battle = battle
	_title.text = battle.encounter.title
	_status.text = "Drag your cards to arrange them, or click two slots to swap."
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
		card.clickable = is_ally and not _busy
		card.draggable = arranging and card.clickable
		card.hover_enabled = not _busy
		card.selected = _selected_column != -1 and _battle.allies[_selected_column] == unit

	var targets: Array[int] = []
	if arranging and _selected_column != -1 and not _busy:
		for column in BattleState.COLUMN_COUNT:
			if column != _selected_column:
				targets.append(column)
	_ally_slots.highlighted = targets

	_refresh_rip()
	_graveyard.visible = not arranging
	_graveyard.interactions_enabled = not _busy
	if not arranging:
		_graveyard.display(_battle.run, _battle.graveyard)

	_sacrifice.visible = not arranging
	_sacrifice.disabled = _busy or _selected_column == -1
	_sacrifice.text = (
		"Sacrifice %s" % _battle.allies[_selected_column].title()
		if not _sacrifice.disabled
		else "Sacrifice ally"
	)
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
	_rip.text = "RiP  %d/%d" % [_battle.run.rp, DeckRun.MAX_RP]


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


func _add_card(unit: UnitState, side: int, at: Vector2) -> Card2D:
	var card := CARD_SCENE.instantiate() as Card2D
	_card_layer.add_child(card)
	card.global_position = at
	card.display(unit, _look(side))
	card.clicked.connect(_on_card_clicked.bind(unit))
	if side == ALLY:
		card.dragged.connect(_on_ally_dragged.bind(unit))
		card.dropped.connect(_on_ally_dropped.bind(unit))
		card.drag_cancelled.connect(_clear_drop_target)
	_cards[unit] = card
	return card


func _on_card_clicked(unit: UnitState) -> void:
	if _busy:
		return
	var column := _battle.allies.find(unit)
	if column == -1:
		return
	if _battle.round_number == 0:
		_select_slot(column)
	else:
		_selected_column = -1 if _selected_column == column else column
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	if _busy or _battle == null or _battle.round_number != 0 or _selected_column == -1:
		return
	var point := get_canvas_transform().affine_inverse() * button.position
	var column := _ally_slots.column_at(point)
	if column != -1 and _battle.allies[column] == null:
		get_viewport().set_input_as_handled()
		SoundManager.play_sfx(SELECT_SFX)
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

	_swap_slots(_selected_column, column)


func _on_ally_dragged(point: Vector2, unit: UnitState) -> void:
	_selected_column = -1
	for card: Card2D in _cards.values():
		card.selected = false
	var column := _ally_slots.column_at(point)
	_highlight_drop_target(column if column != -1 and _battle.allies[column] != unit else -1)


func _on_ally_dropped(point: Vector2, unit: UnitState) -> void:
	_clear_drop_target()
	var first := _battle.allies.find(unit)
	var column := _ally_slots.column_at(point)
	if _busy or _battle.round_number != 0 or column == -1 or first == column:
		(_cards[unit] as Card2D).restore_drag_position()
		return
	_swap_slots(first, column)


func _clear_drop_target() -> void:
	_ally_slots.highlighted = []


func _highlight_drop_target(column: int) -> void:
	var targets: Array[int] = []
	if column != -1:
		targets.append(column)
	_ally_slots.highlighted = targets


func _swap_slots(first: int, column: int) -> void:
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
	SoundManager.play_sfx(SHIFT_SFX)
	await _wait_all(tweens)
	_busy = false
	_refresh()


func _on_graveyard_dragged(_unit: UnitState, point: Vector2) -> void:
	var column := _ally_slots.column_at(point)
	_highlight_drop_target(column if _battle.can_raise_at(column) else -1)


func _on_graveyard_dropped(unit: UnitState, point: Vector2) -> void:
	_clear_drop_target()
	var column := _ally_slots.column_at(point)
	if _busy or not _battle.can_raise_at(column):
		_graveyard.restore_drag_position(unit)
		return
	_on_raise_requested(unit, column)


func _on_raise_requested(unit: UnitState, target_column: int = -1) -> void:
	if _busy:
		return
	var from := _graveyard.card_global_position(unit)
	var column := _battle.try_raise(unit, target_column)
	if column == -1:
		return

	_busy = true
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


func _on_sacrifice_pressed() -> void:
	if _busy:
		return
	var event := _battle.sacrifice(_selected_column)
	if event == null:
		return
	_selected_column = -1
	_busy = true
	_refresh()
	await _play_death(event)
	_status.text = "%s was sacrificed." % event.unit.title()
	_busy = false
	_refresh()


func _on_action_pressed() -> void:
	if _busy:
		return
	if _battle.run.army.is_empty():
		_battle.clear_bonuses()
		finished.emit(false)
		return
	if _battle.enemies_defeated():
		_battle.clear_bonuses()
		finished.emit(true)
		return

	var previous_rp := _battle.run.rp
	var previous_dead := _battle.graveyard.size()
	_selected_column = -1
	_busy = true
	_refresh()
	_status.text = "Round %d" % (_battle.round_number + 1)
	var shifts := _battle.begin_round()
	await _play_shifts(shifts)
	for card: Card2D in _cards.values():
		card.display(card.unit, card.look)
	await _play(_battle.plan_bonuses(shifts))
	await _play(_battle.plan_attacks())

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
	for event in events:
		await _play_event(event)


## All shifts of a round slide at once. Cards trading places arc past each other.
func _play_shifts(shifts: Array[BattleEvent]) -> void:
	if shifts.is_empty():
		return
	var tweens: Array[Tween] = []
	for event in shifts:
		var card: Card2D = _cards[event.unit]
		var arc := 0.0
		if event.swapped:
			arc = SWAP_ARC if event.to_column > event.column else -SWAP_ARC
		tweens.append(card.move_to(_slot_position(event.side, event.to_column), _t(0.3), arc))
	if not tweens.is_empty():
		SoundManager.play_sfx(SHIFT_SFX)
	await _wait_all(tweens)


func _play_event(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.ATTACK:
			await _play_attack(event)
		BattleEvent.Kind.DEATH:
			await _play_death(event)
		BattleEvent.Kind.RIP:
			await _play_rip(event)
		BattleEvent.Kind.BONUS:
			event.unit.set_battle_bonus(event.amount)
			(_cards[event.unit] as Card2D).display(event.unit, _look(event.side))


func _play_attack(event: BattleEvent) -> void:
	var attacker: Card2D = _cards.get(event.unit)
	if attacker == null:
		return
	var defender: Card2D = _cards.get(event.target) if event.target != null else null
	var point := _slot_position(ENEMY if event.side == ALLY else ALLY, event.to_column)
	var on_impact := func() -> void:
		if defender == null:
			SoundManager.play_sfx(EMPTY_HIT_SFX)
			return
		event.target.take_damage(event.amount)
		defender.hit(event.target.combat_hp(), _t(0.3))
		SoundManager.play_sfx(HIT_SFX)
		var above := defender.global_position + Vector2(0, -70)
		FloatingText.spawn(_fx, "-%d" % event.amount, DAMAGE_COLOR, above, Vector2.INF, _t(0.8))
	await _wait(attacker.lunge(point, _t(0.4), on_impact))


func _play_death(event: BattleEvent) -> void:
	var card: Card2D = _cards.get(event.unit)
	if card != null:
		_cards.erase(event.unit)
		await _wait(card.die(_t(0.35)))
		card.queue_free()
	_battle.apply_death(event)
	_graveyard.visible = true
	_graveyard.display(_battle.run, _battle.graveyard)


func _play_rip(event: BattleEvent) -> void:
	if event.rewards_column:
		_battle.rewarded_columns.append(event.column)
	var before := _battle.run.rp
	var amount := clampi(before + event.amount, 0, DeckRun.MAX_RP) - before
	if amount == 0:
		return
	var from := _slot_position(event.side, event.column)
	var color := RIP_GAIN_COLOR if amount > 0 else RIP_LOSS_COLOR
	var to := _rip.global_position + _rip.size / 2
	await _wait(FloatingText.spawn(_fx, "%+d RiP" % amount, color, from, to, _t(0.7)))
	SoundManager.play_sfx(RIP_GAIN_SFX if amount > 0 else RIP_LOSS_SFX)
	_battle.run.add_rp(amount)
	_refresh_rip()
	if _graveyard.visible:
		_graveyard.display(_battle.run, _battle.graveyard)


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
