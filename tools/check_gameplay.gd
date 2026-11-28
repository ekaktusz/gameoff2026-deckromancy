extends SceneTree
## Run after importing: godot --headless --script tools/check_gameplay.gd

var _failed := false


func _initialize() -> void:
	_check_gameplay.call_deferred()


func _check_gameplay() -> void:
	_check_portraits()
	_check_abilities()
	_check_deaths()
	var game_scene := load("res://game_loop.tscn") as PackedScene
	_check_map_backgrounds(game_scene)
	var game = game_scene.instantiate()
	var route: Array[EncounterDefinition] = game.encounters
	var darius := route.back() as EncounterDefinition
	_expect(darius.title == "Darius" and darius.is_boss, "Darius must be the final boss")
	_expect(DeckRun.route_successors(route[-2], route) == [darius], "Citadel must lead to Darius")

	var enemy := UnitDefinition.new()
	enemy.ability = UnitDefinition.Ability.GRAVEYARD
	var encounter := EncounterDefinition.new()
	encounter.title = "Regression fight"
	encounter.enemies.assign([enemy, enemy])
	game.encounters.assign([encounter])
	var rook := load("res://Gameplay/Units/rook_captain.tres") as UnitDefinition
	var hound := load("res://Gameplay/Units/grave_hound.tres") as UnitDefinition
	game.starting_units.assign([hound, rook])
	root.add_child(game)
	root.get_node("MusicPlayer/AudioStreamPlayer").stop()
	var yard = game.get_node("World/GraveyardScene")
	var starters: Array[UnitState] = game.get("_starting_graveyard").duplicate()
	var first_card: Vector2 = yard.card_global_position(starters[0])
	var run: DeckRun = game.get("_run")
	_pointer(first_card, first_card)
	_expect(run.army.is_empty(), "Clicking a starting card must not raise it")
	var drop_zone := yard.get_node("ArmyDropZone") as Panel
	for unit in starters:
		_pointer(yard.card_global_position(unit), drop_zone.get_global_rect().get_center())
	var guard := load("res://Gameplay/Units/silt_guard.tres") as UnitDefinition
	run.army.append(UnitState.new(guard))
	yard.continue_requested.emit()
	var map := game.get_node("Screen/MapScene") as Control
	_expect(map.get_node("ArmyCards").get_child_count() == 3, "Map must show the army's cards")
	_expect(not map.get_node("Retry").visible, "There should be no extra start button")
	map.get_node("Graph").get_child(0).pressed.emit()
	_expect(not game.get_node("MapBackground").visible, "Map background must hide in battle")
	var battle_view: Node = game.get_node("World/BattleGround")
	var battle: BattleState = battle_view.get("_battle")
	var action := battle_view.get_node("HUD/Action") as Button
	var cards: Dictionary = battle_view.get("_cards")
	var enemy_ability := cards[battle.enemies[2]].get_node("Ability") as Label
	_expect(enemy_ability.text.is_empty(), "Enemy cards must hide their graveyard ability")
	var popups: Array[String] = []
	battle_view.get_node("Fx").child_entered_tree.connect(
		func(label: Label) -> void: popups.append(label.text)
	)
	Engine.time_scale = 8.0
	await _wait_for_action(action)
	await battle_view._swap_slots(2, 4)
	battle.graveyard.append(UnitState.new(UnitDefinition.new()))
	action.pressed.emit()
	await _wait_for_action(action)
	_expect(battle.round_number == 1 and battle.last_shift_count == 2, "Round one must shift")
	_expect(popups.count("+1/+1") == 2, "Hound and Silt Guard both show +1/+1")
	_expect(popups.count("+2/+2") == 1, "Rook Captain shows +2/+2 with two allies to its right")
	_expect(popups.count("+1 RiP") == 1, "Only the enemy death should award RiP")
	_expect(battle.run.rp == 2 and not popups.has("-1 RiP"), "Empty hits must leave RiP unchanged")
	var fallen := starters[0]
	fallen.hp = 1
	action.pressed.emit()
	await _wait_for_action(action)
	_expect(battle.round_number == 2 and battle.last_shift_count == 0, "Hound must not shift alone")
	_expect(popups.count("+1/+1") == 2, "The second graveyard bonus must show its full amount")
	_expect(popups.count("+2/+2") == 2, "Silt Guard shows +2/+2 in the second round")
	_expect(battle.enemies_defeated() and battle.run.rp == 3, "Last enemy death must award RiP")
	_expect(battle.graveyard.has(fallen) and fallen.marks == 1, "Fallen ally must enter the yard")
	await _check_battle_yard(battle_view, battle, action, fallen, starters[1])
	if not _failed:
		print("Verified map backgrounds, MARK layers, faction abilities, and round playback")
	await create_timer(0.5, true, false, true).timeout
	quit(int(_failed))


func _check_map_backgrounds(scene: PackedScene) -> void:
	var game = scene.instantiate()
	root.add_child(game)
	root.get_node("MusicPlayer/AudioStreamPlayer").stop()
	var background := game.get_node("MapBackground") as TextureRect
	_expect(not background.visible, "City background must be hidden in the starting graveyard")
	game.get_node("World/GraveyardScene").continue_requested.emit()
	var city_start := load("res://assets/city_00.png") as Texture2D
	_expect(background.visible and background.texture == city_start, "Map must begin with city 00")
	var stage := 0
	for encounter: EncounterDefinition in game.encounters:
		stage += int(encounter.is_boss)
		game._on_battle_finished(true, encounter)
		var texture := load("res://assets/city_%02d.png" % stage) as Texture2D
		_expect(background.texture == texture, "Wrong map background after %s" % encounter.title)
	_expect(stage == 4, "Darius must unlock city 04")
	game.get_node("Screen/MapScene").retry_requested.emit()
	game.get_node("World/GraveyardScene").continue_requested.emit()
	_expect(background.texture == city_start, "A new run must restore city 00")
	game.queue_free()


func _check_battle_yard(
	view: Node, battle: BattleState, action: Button, fallen: UnitState, ally: UnitState
) -> void:
	var yard = view.get_node("Graveyard")
	var slots = view.get_node("AllySlots")
	var from: Vector2 = yard.card_global_position(fallen)
	var occupied: Vector2 = slots.slot_position(0)
	_pointer(from, from)
	_pointer(from, occupied)
	_expect(battle.run.rp == 3 and battle.graveyard.has(fallen), "Invalid drops must keep the card")
	_expect(yard.card_global_position(fallen) == from, "Invalid drops must restore the card")
	_pointer(from, slots.slot_position(2))
	await _wait_for_action(action)
	_expect(
		battle.allies[2] == fallen and fallen.marks == 2, "Valid drop must raise the fallen ally"
	)
	_pointer(occupied, occupied)
	var sacrifice := view.get_node("HUD/Sacrifice") as Button
	_expect(not sacrifice.disabled, "Clicking a living ally must still select it")
	sacrifice.pressed.emit()
	await _wait_for_action(action)
	_expect(
		battle.graveyard.has(ally) and ally.marks == 2, "Sacrifice must send the ally and add MARK"
	)
	_expect(
		battle.allies[0] == null and battle.run.rp == 2, "Sacrifice must clear the slot without RiP"
	)
	_pointer(yard.card_global_position(ally), occupied)
	await _wait_for_action(action)
	_expect(battle.allies[0] == ally and ally.marks == 3, "Sacrificed allies can be raised again")


func _pointer(from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = from
	root.push_input(press, true)
	if from != to:
		var move := InputEventMouseMotion.new()
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		move.position = to
		root.push_input(move, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = to
	root.push_input(release, true)


func _wait_for_action(action: Button) -> void:
	var timeout := create_timer(10.0)
	while action.disabled and timeout.time_left > 0:
		await process_frame
	_expect(not action.disabled, "Battle action must unlock after playback")


func _check_portraits() -> void:
	var scene := load("res://Scenes/Card/card_2d.tscn") as PackedScene
	var card = scene.instantiate()
	root.add_child(card)
	var portrait := card.get_node("Portrait") as Sprite2D
	var plant := portrait.get_node("PlantOverlay") as Sprite2D
	var poop_portrait := load("res://assets/poop_warrior.png") as Texture2D
	var units := [
		"ash_crow",
		"rook_captain",
		"doomed_jackdaw",
		"bone_ward",
		"grave_hound",
		"gutter_ram",
		"gatekeeper",
		"inner_gatekeeper",
		"citadel_lord",
		"darius",
	]
	for name in units:
		var definition := load("res://Gameplay/Units/%s.tres" % name) as UnitDefinition
		var unit := UnitState.new(definition)
		card.display(unit, card.look, true)
		_expect(not plant.visible, "%s must show no plant before a MARK" % name)
		unit.revive()
		card.display(unit, card.look)
		_expect(
			plant.visible and plant.texture == definition.mark_overlay, "%s needs a layer" % name
		)
		_expect(portrait.texture == definition.portrait, "%s must retain its base portrait" % name)
		_expect(
			plant.texture != null and plant.texture.get_size() == portrait.texture.get_size(),
			"%s plant needs the same canvas size" % name
		)
		unit.marks = UnitState.POOP_MARKS - 1
		card.display(unit, card.look, true)
		_expect(portrait.texture == poop_portrait and not plant.visible, "%s Poop preview" % name)
		unit.revive()
		card.display(unit, card.look)
		_expect(portrait.texture == poop_portrait and not plant.visible, "%s Poop art" % name)
	var legacy := UnitDefinition.new()
	legacy.portrait = load("res://assets/frog.png") as Texture2D
	legacy.marked_portrait = load("res://assets/frog_marked.png") as Texture2D
	var marked := UnitState.new(legacy)
	marked.revive()
	card.display(marked, card.look)
	_expect(not plant.visible and portrait.texture == legacy.marked_portrait, "Legacy MARK art")
	marked.marks = UnitState.POOP_MARKS - 1
	marked.revive()
	card.display(marked, card.look)
	_expect(portrait.texture == poop_portrait, "Poop Warrior replaces legacy MARK art too")
	card.free()


func _check_abilities() -> void:
	var run := DeckRun.new()
	for name in ["silt_guard", "shell_mender", "carapace_hexer", "gutter_ram", "ash_crow"]:
		var definition := load("res://Gameplay/Units/%s.tres" % name) as UnitDefinition
		run.army.append(UnitState.new(definition))
	run.army[1].marks = 1
	run.army[2].marks = 2
	var encounter := EncounterDefinition.new()
	encounter.enemies.append(UnitDefinition.new())
	var battle := BattleState.new(run, encounter)
	battle.enemies[2].marks = 3
	battle.graveyard.append(UnitState.new(UnitDefinition.new()))

	var crow := run.army[4]
	var ram := run.army[3]
	var shifts := battle.begin_round()
	_expect(
		shifts.size() == 2 and battle.allies[3] == crow, "Only the crow should initiate a shift"
	)
	_expect(battle.allies[4] == ram, "A bird can swap with the ram")
	for event in battle.plan_bonuses(shifts):
		event.unit.set_battle_bonus(event.amount)
	_expect(run.army[0].battle_bonus == 1, "Silt Guard counts graveyard cards")
	_expect(run.army[1].battle_bonus == 3, "Shell Mender counts MARKs on its side only")
	_expect(run.army[2].battle_bonus == 8, "Carapace Hexer gains four per own MARK")
	_expect(ram.battle_bonus == 0, "Gutter Ram skips growth in a round when it moves")

	var silt_guard := run.army[0]
	silt_guard.take_damage(2)
	var remaining_hp := silt_guard.hp
	for round_index in range(2, 4):
		shifts = battle.begin_round()
		_expect(silt_guard.battle_bonus == 0, "Previous graveyard bonuses expire each round")
		_expect(silt_guard.combat_hp() == remaining_hp, "Base HP damage persists")
		for event in battle.plan_bonuses(shifts):
			event.unit.set_battle_bonus(event.amount)
		_expect(silt_guard.combat_hp() == remaining_hp + 1, "Graveyard bonus HP refreshes")
		_expect(battle.allies[4 - round_index] == crow, "Ash Crow shifts left again each round")
		_expect(ram.battle_bonus == round_index - 1, "Gutter Ram grows each round it stays put")


func _check_deaths() -> void:
	var stationary := load("res://Gameplay/Units/bone_ward.tres") as UnitDefinition
	var doomed := load("res://Gameplay/Units/doomed_jackdaw.tres") as UnitDefinition
	var encounter := EncounterDefinition.new()
	encounter.enemies.assign([stationary, doomed])
	for marks in [0, 1]:
		var run := DeckRun.new()
		var poop := UnitState.new(doomed)
		for mark in UnitState.POOP_MARKS:
			poop.revive()
		run.army.append(poop)
		var battle := BattleState.new(run, encounter)
		battle.enemies[2].marks = marks
		var shifts := battle.begin_round()
		var deaths := battle.plan_shift_deaths(shifts)
		_expect(shifts.is_empty(), "Bone Ward and Poop Warrior must hold their slots")
		_expect(poop.combat_attack() == 1 and poop.combat_hp() == 1, "Poop Warrior must be 1/1")
		_expect(deaths.size() == 1, "Only the blocked enemy should die")
		for event in deaths:
			var gained := battle.apply_death(event)
			_expect(gained == int(marks == 0), "Only an unmarked enemy death should award RiP")
			_expect(battle.apply_death(event) == 0, "A death should pay out at most once")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
