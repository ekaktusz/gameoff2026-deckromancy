extends SceneTree
## Run after importing: godot --headless --script tools/check_gameplay.gd

const DEFAULT_GRADIENT := preload("res://assets/units/unit_gradient.tres")
const BATTLE_TEXTURE := preload("res://assets/backgrounds/battle_bg.png")
const BONE_WARD := preload("res://Gameplay/Units/bone_ward.tres")

var _failed := false


func _initialize() -> void:
	_check_gameplay.call_deferred()


func _check_gameplay() -> void:
	_check_portraits()
	_check_abilities()
	_check_deaths()
	var game_scene := load("res://game_loop.tscn") as PackedScene
	await _check_map_backgrounds(game_scene)
	var game = game_scene.instantiate()
	var route: Array[EncounterDefinition] = game.encounters
	_check_encounter_lineups(route, game.enemy_pool)
	var darius := route.back() as EncounterDefinition
	_expect(darius.title == "Darius" and darius.is_boss, "Darius must be the final boss")
	_expect(DeckRun.route_successors(route[-2], route) == [darius], "Citadel must lead to Darius")

	var enemy := UnitDefinition.new()
	enemy.ability = UnitDefinition.Ability.GRAVEYARD
	enemy.faction = UnitDefinition.Faction.BUG
	var encounter := EncounterDefinition.new()
	encounter.title = "Regression fight"
	encounter.is_boss = true
	encounter.enemies.assign([enemy, enemy])
	encounter.portrait_gradient = GradientTexture1D.new()
	encounter.portrait_gradient.gradient = Gradient.new()
	encounter.portrait_gradient.gradient.set_color(0, Color.DARK_GREEN)
	encounter.portrait_gradient.gradient.set_color(1, Color.GOLD)
	var next_encounter := EncounterDefinition.new()
	next_encounter.title = "Next regression fight"
	next_encounter.enemies.append(enemy)
	next_encounter.portrait_gradient = GradientTexture1D.new()
	next_encounter.portrait_gradient.gradient = Gradient.new()
	next_encounter.portrait_gradient.gradient.set_color(0, Color.AQUAMARINE)
	next_encounter.portrait_gradient.gradient.set_color(1, Color.BLACK)
	game.encounters.assign([encounter, next_encounter])
	var rook := load("res://Gameplay/Units/rook_captain.tres") as UnitDefinition
	var hound := load("res://Gameplay/Units/grave_hound.tres") as UnitDefinition
	var guard := load("res://Gameplay/Units/silt_guard.tres") as UnitDefinition
	var spare := BONE_WARD
	game.enemy_pool.assign([hound, rook, guard, spare])
	root.add_child(game)
	root.get_node("MusicPlayer/AudioStreamPlayer").stop()
	await process_frame
	_dismiss_story(game)
	_dismiss_story(game)
	var yard = game.get_node("World/GraveyardScene")
	var offer: Dictionary[UnitDefinition, UnitState] = {}
	for unit: UnitState in game.get("_starting_graveyard"):
		offer[unit.definition] = unit
	var starters: Array[UnitState] = [offer[hound], offer[rook]]
	var continue_button := yard.get_node("Continue") as Button
	var first_card: Vector2 = yard.card_global_position(starters[0])
	var run: DeckRun = game.get("_run")
	_pointer(first_card, first_card)
	_expect(run.army.is_empty(), "Clicking a starting card must not raise it")
	var army_slots = yard.get_node("ArmySlots")
	_pointer(yard.card_global_position(starters[1]), army_slots.slot_position(1))
	_pointer(yard.card_global_position(starters[0]), army_slots.slot_position(1))
	_expect(run.army.size() == 1, "An occupied starting slot must reject a drop")
	_pointer(yard.card_global_position(starters[0]), army_slots.slot_position(0))
	_pointer(army_slots.slot_position(1), army_slots.slot_position(3))
	_expect(run.starting_slots[starters[1]] == 3, "A raised card can move to an empty slot")
	_pointer(army_slots.slot_position(3), army_slots.slot_position(0))
	_expect(run.starting_slots[starters[0]] == 3, "Raised cards can swap starting slots")
	_pointer(army_slots.slot_position(0), army_slots.slot_position(3))
	_pointer(army_slots.slot_position(3), army_slots.slot_position(1))
	_expect(run.rp == 1, "Rearranging starting slots must not spend RiP")
	_expect(continue_button.disabled, "Two starters cannot enter the city")
	_pointer(yard.card_global_position(offer[guard]), army_slots.slot_position(2))
	_expect(not continue_button.disabled, "Three starters can enter the city")
	_pointer(yard.card_global_position(offer[spare]), army_slots.slot_position(4))
	_expect(run.army.size() == 3 and not run.army.has(offer[spare]), "Pick only three starters")
	_expect(run.rp == 0, "Each starting card costs one RiP")
	# Give the combat fixture enough RiP to exercise three more revivals.
	run.add_rp(1)
	continue_button.pressed.emit()
	var map := game.get_node("Screen/MapScene") as Control
	_expect(map.get_node("ArmyCards").get_child_count() == 3, "Map must show the army's cards")
	_expect(not map.get_node("Retry").visible, "There should be no extra start button")
	var button := map.get_node("Graph").get_child(0) as Button
	_expect(button.tooltip_text == "2× Bug", "Map preview must show enemy types and counts")
	var preview := button.call("_make_custom_tooltip", button.tooltip_text) as Label
	_expect(preview.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Center enemy types")
	preview.free()
	button.pressed.emit()
	_expect(not game.get_node("MapBackground").visible, "Map background must hide in battle")
	_expect(_story_text(game).begins_with("Every creature"), "Show the first fight tutorial")
	var battle_view: Node = game.get_node("World/BattleGround")
	var battle: BattleState = battle_view.get("_battle")
	var action := battle_view.get_node("HUD/Action") as Button
	var yard_title := battle_view.get_node("Graveyard/Title") as Label
	var yard_status := battle_view.get_node("Graveyard/Status") as Label
	_expect(yard_title.is_visible_in_tree(), "Show the graveyard heading before the first round")
	_expect(
		yard_status.is_visible_in_tree() and yard_status.text.contains("No creatures to raise"),
		"Show the empty graveyard status before the first round"
	)
	var battle_art := battle_view.get_node("Background") as Sprite2D
	_expect(
		battle_art.texture == BATTLE_TEXTURE, "First fight uses the dedicated battle background"
	)
	var battle_tint := battle_art.self_modulate
	_expect(battle_tint != Color.WHITE, "Keep the battle background dimmed")
	_expect(not battle_view.can_process(), "Block battle input during the tutorial")
	await process_frame
	var tutorial_panel := game.get_node("StoryBox/Margin/Panel") as Control
	var panel_center := tutorial_panel.get_global_rect().get_center()
	var screen_center := root.get_visible_rect().get_center()
	_expect(
		panel_center.distance_to(screen_center) <= 1.0,
		"Center the battle tutorial (%s vs %s)" % [panel_center, screen_center]
	)
	var action_point := action.get_global_rect().get_center()
	_pointer(action_point, action_point)
	_expect(
		battle.round_number == 0 and game.get_node("StoryBox").visible,
		"A click behind the tutorial cannot start combat or dismiss the story"
	)
	_dismiss_story(game)
	_expect(battle_view.can_process(), "Restore battle input after dismissing")
	_expect(battle_art.self_modulate == battle_tint, "Keep the same battle tint after dismissing")
	var recruit := battle.enemies[1]
	var cards: Dictionary = battle_view.get("_cards")
	var enemy_ability := cards[battle.enemies[2]].get_node("Ability") as Label
	_expect(enemy_ability.text.is_empty(), "Enemy cards must hide their graveyard ability")
	_expect(
		_card_gradient(cards[recruit]) == encounter.portrait_gradient,
		"New enemies must use the encounter gradient"
	)
	_expect(
		_card_gradient(cards[starters[0]]) == DEFAULT_GRADIENT,
		"Starting cards must keep the default gradient"
	)
	var popups: Array[String] = []
	battle_view.get_node("Fx").child_entered_tree.connect(
		func(label: Label) -> void: popups.append(label.text)
	)
	Engine.time_scale = 8.0
	await _wait_for_action(action)
	_expect(battle.allies[1] == starters[1], "The first battle honors the chosen starting slots")
	var ally_slots = battle_view.get_node("AllySlots")
	var source: Vector2 = ally_slots.slot_position(2)
	var destination: Vector2 = ally_slots.slot_position(4)
	_pointer(source, source)
	_pointer(destination, destination)
	_expect(battle.allies[4] == null, "Clicking slots cannot swap cards")
	_pointer(source, destination)
	await _wait_for_action(action)
	_expect(battle.allies[4] != null, "Dragging to an open slot moves the card")
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
	await _check_next_battle(game, battle_view, recruit)
	if not _failed:
		print("Verified story scenes, map backgrounds, MARK layers, abilities, and round playback")
	await create_timer(0.5, true, false, true).timeout
	quit(int(_failed))


func _check_next_battle(game: Node, view: Node, recruit: UnitState) -> void:
	var yard = view.get_node("Graveyard")
	_expect(not yard.get_node("Background/Plants").is_visible_in_tree(), "Hide plants in battle")
	var yard_cards: Dictionary = yard.get("_cards")
	_expect(_card_gradient(yard_cards[recruit]) == recruit.portrait_gradient, "Enemy keeps its art")
	var slots = view.get_node("AllySlots")
	var action := view.get_node("HUD/Action") as Button
	_pointer(yard.card_global_position(recruit), slots.slot_position(3))
	await _wait_for_action(action)
	action.pressed.emit()
	_dismiss_story(game)
	var previews := game.get_node("Screen/MapScene/ArmyCards")
	var preview := previews.get_child(previews.get_child_count() - 1).get_child(0)
	_expect(_card_gradient(preview) == recruit.portrait_gradient, "Map shows the recruited palette")
	_check_stat_color(preview, Color.GOLD)
	game.get_node("Screen/MapScene/Graph").get_child(1).pressed.emit()
	_expect(not game.get_node("StoryBox").visible, "Tutorial appears only in the first fight")
	var next_view := game.get_node("World/BattleGround") as Node2D
	var battle: BattleState = next_view.get("_battle")
	var cards: Dictionary = next_view.get("_cards")
	_expect(
		_card_gradient(cards[recruit]) == recruit.portrait_gradient, "Recruit keeps its gradient"
	)
	_expect(
		_card_gradient(cards[battle.enemies[2]]) == battle.encounter.portrait_gradient,
		"New enemies use the next encounter's gradient"
	)
	_check_stat_color(cards[recruit], Color.GOLD)
	_check_stat_color(cards[battle.enemies[2]], Color.AQUAMARINE)
	var background := next_view.get_node("Background") as Sprite2D
	_expect(
		background.texture == BATTLE_TEXTURE, "Later fights use the dedicated battle background"
	)
	var viewport := next_view.get_viewport_rect()
	var art_rect := background.transform * background.get_rect()
	_expect(viewport.encloses(art_rect), "Show the entire battle background")
	_expect(art_rect.get_center().is_equal_approx(viewport.get_center()), "Center the battle art")
	await _wait_for_action(next_view.get_node("HUD/Action") as Button)


func _card_gradient(card: Node) -> GradientTexture1D:
	var portrait := card.get_node("Portrait") as Sprite2D
	return (portrait.material as ShaderMaterial).get_shader_parameter("gradient_map")


func _check_stat_color(card: Node, expected: Color) -> void:
	card.dimmed = true
	_expect(card.modulate == Color.WHITE, "Dimming must not tint the whole card")
	for name in ["Attack", "HP"]:
		var label := card.get_node(name) as Label
		_expect(label.get_theme_color("font_color") == expected, "%s uses the card palette" % name)
		_expect(label.modulate == Color.WHITE, "%s stays bright on a dimmed card" % name)
	card.dimmed = false


func _check_map_backgrounds(scene: PackedScene) -> void:
	var game = scene.instantiate()
	root.add_child(game)
	root.get_node("MusicPlayer/AudioStreamPlayer").stop()
	await process_frame
	var background := game.get_node("MapBackground") as TextureRect
	var city_start := load("res://assets/backgrounds/city_00.png") as Texture2D
	_expect(background.visible and background.texture == city_start, "Intro must show city 00")
	_expect(background.self_modulate == Color.WHITE, "Show the intro at full brightness")
	var intro := _story_text(game)
	_expect(intro.begins_with("This City"), "Show intro after Start")
	var copy := game.get_node("StoryBox/Margin/Panel/Content/Copy") as RichTextLabel
	_expect(copy.size.y >= copy.get_content_height(), "Fit the full intro into the story box")
	var panel := game.get_node("StoryBox/Margin/Panel") as Control
	_expect(panel.position == Vector2(40, 32), "Story box belongs at the top left")
	var mark_color := Color(0.65, 1.0, 0.36).to_html(false)
	_expect(copy.text.contains("[color=#%s]City[/color]" % mark_color), "Use the MARK green")
	var centre := root.get_visible_rect().get_center()
	_pointer(centre, centre)
	_expect(_story_text(game) == intro, "A single click cannot dismiss story")
	_dismiss_story(game)
	_expect(_story_text(game).begins_with("I got some"), "Show the cemetery story next")
	_expect(
		_story_text(game).contains("RESURRECTION POINTS (RiP)"), "Show resurrection instructions"
	)
	_expect(not background.visible, "City background must be hidden in the starting graveyard")
	var yard_art := game.get_node("World/GraveyardScene/Background") as Sprite2D
	_expect(yard_art.self_modulate == Color.WHITE, "Show the cemetery story at full brightness")
	var plants := yard_art.get_node("Plants") as Sprite2D
	var graveyard := load("res://assets/backgrounds/temeto_00.png") as Texture2D
	var plant_art := load("res://assets/backgrounds/temeto_00_noveny.png") as Texture2D
	_expect(yard_art.is_visible_in_tree() and yard_art.texture == graveyard, "Show graveyard art")
	_expect(plants.is_visible_in_tree() and plants.texture == plant_art, "Show the plant layer")
	_expect(plants.get_rect() == yard_art.get_rect(), "Plant art aligns with the graveyard")
	_expect(
		(yard_art.global_transform * yard_art.get_rect()).encloses(yard_art.get_viewport_rect()),
		"Graveyard art fills the view"
	)
	_expect(not game.get_node("World/GraveyardScene/Continue").visible, "Story comes before draft")
	_dismiss_story(game)
	_expect(yard_art.self_modulate != Color.WHITE, "Restore the normal cemetery background")
	_expect(
		game.get_node("World/GraveyardScene/Continue").visible, "Dismiss story to start drafting"
	)
	var offered_definitions: Array[UnitDefinition] = []
	for unit: UnitState in game.get("_starting_graveyard"):
		_expect(game.enemy_pool.has(unit.definition), "Starters come from the base unit pool")
		_expect(not offered_definitions.has(unit.definition), "Starters must be distinct")
		offered_definitions.append(unit.definition)
	_expect(offered_definitions.size() == 4, "Offer four starters per run")
	game._show_map()
	_expect(background.visible and background.texture == city_start, "Map must begin with city 00")
	_expect(background.self_modulate != Color.WHITE, "Restore the normal map background")
	var stage := 0
	var boss_openings := [
		"I knew I was on", "I kept pushing", "I knew I was getting", "I was exhausted"
	]
	for encounter: EncounterDefinition in game.encounters:
		stage += int(encounter.is_boss)
		game._on_battle_finished(true, encounter)
		var texture := load("res://assets/backgrounds/city_%02d.png" % stage) as Texture2D
		_expect(background.texture == texture, "Wrong map background after %s" % encounter.title)
		_expect(game.get_node("StoryBox").visible == encounter.is_boss, "Story follows each boss")
		if encounter.is_boss:
			_expect(background.self_modulate == Color.WHITE, "Show boss stories at full brightness")
			_expect(_story_text(game).begins_with(boss_openings[stage - 1]), "Match boss story")
			_expect(
				not game.has_node("Screen/MapScene"), "Show victory art before returning to map"
			)
			_dismiss_story(game)
	_expect(stage == 4, "Darius must unlock city 04")
	game.get_node("Screen/MapScene").retry_requested.emit()
	_dismiss_story(game)
	game._show_map()
	_expect(background.texture == city_start, "A new run must restore city 00")
	root.remove_child(game)
	game.queue_free()


func _story_text(game: Node) -> String:
	var copy := game.get_node("StoryBox/Margin/Panel/Content/Copy") as RichTextLabel
	return copy.get_parsed_text()


func _dismiss_story(game: Node) -> void:
	var story := game.get_node("StoryBox") as Control
	_expect(story.visible, "Expected a story to dismiss")
	var centre := root.get_visible_rect().get_center()
	_pointer(centre, centre, true)


func _check_encounter_lineups(
	route: Array[EncounterDefinition], pool: Array[UnitDefinition]
) -> void:
	_expect(pool.size() == 9, "The random pool must contain the nine basic units")
	var run := DeckRun.new()
	for encounter in route:
		var preview := run.enemy_lineup(encounter, pool)
		var battle := BattleState.new(run, encounter, pool)
		if encounter.is_boss:
			_expect(battle.enemies_remaining() == encounter.enemies.size(), "Fixed boss lineup")
			continue
		_expect(encounter.enemies.is_empty(), "Regular fights must draw their entire lineup")
		_expect(encounter.random_enemy_count > 0, "Regular fights need a configured enemy count")
		_expect(battle.enemies_remaining() == encounter.random_enemy_count, "Random lineup size")
		var actual: Array[UnitDefinition] = []
		for enemy in battle.enemies:
			if enemy != null:
				_expect(pool.has(enemy.definition), "Random enemies must come from the basic pool")
				actual.append(enemy.definition)
		_expect(actual == preview, "The lineup seen on the map must match the fight")
	var final_battle := BattleState.new(DeckRun.new(), route.back(), pool)
	var names: Array[String] = []
	for enemy in final_battle.enemies:
		if enemy != null:
			names.append(enemy.title())
	_expect(names == ["Gatekeeper", "Darius", "Inner Gatekeeper"], "Darius needs both Gatekeepers")


func _check_battle_yard(
	view: Node, battle: BattleState, action: Button, fallen: UnitState, ally: UnitState
) -> void:
	var yard = view.get_node("Graveyard")
	var slots = view.get_node("AllySlots")
	var yard_cards: Dictionary = yard.get("_cards")
	_expect(
		_card_gradient(yard_cards[fallen]) == DEFAULT_GRADIENT,
		"Fallen starting cards keep the default gradient"
	)
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


func _pointer(from: Vector2, to: Vector2, double_click: bool = false) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.double_click = double_click
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
	_check_stat_color(card, DEFAULT_GRADIENT.gradient.get_color(1))
	var title := card.get_node("Name") as Label
	var font := load("res://assets/fonts/HoldMoney-Regular.ttf") as Font
	var title_font := title.get_theme_font("font") as FontVariation
	_expect(
		font != null and title_font != null and title_font.base_font == font,
		"Cards must use Hold Money"
	)
	_check_card_labels(card)
	var portrait := card.get_node("Portrait") as Sprite2D
	_check_card_frames(card, portrait)
	var plant := portrait.get_node("PlantOverlay") as Sprite2D
	var material := portrait.material as ShaderMaterial
	var gradient := DEFAULT_GRADIENT as GradientTexture1D
	_expect(gradient != null and gradient.gradient != null, "Portrait gradient must be editable")
	_expect(
		material != null and material.get_shader_parameter("gradient_map") == gradient,
		"The shared portrait must use the unit gradient"
	)
	_expect(plant.material == null and not plant.use_parent_material, "Plant keeps its colors")
	var poop_portrait := load("res://assets/units/poop_warrior.png") as Texture2D
	var units := [
		"silt_guard",
		"shell_mender",
		"carapace_hexer",
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
		var original_fit := portrait.transform
		_expect(not plant.visible, "%s must show no plant before a MARK" % name)
		unit.revive()
		card.display(unit, card.look)
		_expect(portrait.transform == original_fit, "%s stays aligned when marked" % name)
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
	legacy.portrait = load("res://assets/units/legacy/frog.png") as Texture2D
	legacy.marked_portrait = load("res://assets/units/legacy/frog_marked.png") as Texture2D
	var marked := UnitState.new(legacy)
	marked.revive()
	card.display(marked, card.look)
	_expect(not plant.visible and portrait.texture == legacy.marked_portrait, "Legacy MARK art")
	marked.marks = UnitState.POOP_MARKS - 1
	marked.revive()
	card.display(marked, card.look)
	_expect(portrait.texture == poop_portrait, "Poop Warrior replaces legacy MARK art too")
	card.free()


func _check_card_labels(card: Node2D) -> void:
	var ability := card.get_node("Ability") as Label
	var faction := card.get_node("Faction") as Label
	var ability_height := ability.size.y
	for description: String in UnitDefinition.ABILITY_DESCRIPTIONS.values():
		ability.text = description
		_expect(ability.get_minimum_size().y <= ability_height, "Text must fit: %s" % description)
	var title := card.get_node("Name") as Label
	for file in DirAccess.get_files_at("res://Gameplay/Units"):
		if not file.ends_with(".tres"):
			continue
		var unit := load("res://Gameplay/Units/" + file) as UnitDefinition
		card.fit_name(unit.title)
		var font_size := title.get_theme_font_size("font_size")
		var width := (
			title
			. get_theme_font("font")
			. get_string_size(unit.title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			. x
		)
		_expect(width <= title.size.x, "Name must fit: %s" % unit.title)
	_expect(faction.position.y >= ability.position.y + ability_height, "Faction goes below ability")
	_expect(is_zero_approx(faction.get_rect().get_center().x), "Faction must be centered")
	var attack := card.get_node("Attack") as Label
	var hp := card.get_node("HP") as Label
	_expect(attack.get_rect().get_center() == Vector2(-89, 133), "Attack aligns with its plaque")
	_expect(hp.get_rect().get_center() == Vector2(89, 133), "HP aligns with its plaque")


func _check_card_frames(card: Node2D, portrait: Sprite2D) -> void:
	var backing := card.get_node("Backing") as Sprite2D
	var frame := card.get_node("Frame") as Sprite2D
	var material := backing.material as ShaderMaterial
	var gradient := load("res://assets/cards/card_gradient.tres") as GradientTexture1D
	_expect(
		(
			material != null
			and frame.material == material
			and material.get_shader_parameter("gradient_map") == gradient
		),
		"Backing and frame share the card gradient"
	)
	_expect(
		backing.get_index() < portrait.get_index() and portrait.get_index() < frame.get_index(),
		"Layers must draw backing, portrait, then frame"
	)
	_expect(backing.texture != null and backing.scale == frame.scale, "Card layers must align")
	var unit := UnitState.new(UnitDefinition.new())
	var frames := ["", "", " broken", " broken 2", " broken 3", " broken 3"]
	var card_look: int = card.get("look")
	for marks in frames.size():
		unit.marks = marks
		card.display(unit, card_look)
		var path := "res://assets/cards/card bg own transparent middle%s.png" % frames[marks]
		_expect(frame.texture != null and frame.texture == load(path), "Frame at %d MARKs" % marks)
	unit.marks = 3
	card.display(unit, card_look, true)
	var broken_3 := load("res://assets/cards/card bg own transparent middle broken 3.png")
	_expect(frame.texture == broken_3, "Revival preview must show the upcoming MARK frame")
	card._set_hovered(true, true)
	_expect(frame.self_modulate == Color.WHITE, "Hover must preserve frame colors")
	card._set_hovered(false, true)


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
	_expect(run.army[1].battle_bonus == 2, "Shell Mender counts only its allies' MARKs")
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
	var stationary := BONE_WARD
	var ram := load("res://Gameplay/Units/gutter_ram.tres") as UnitDefinition
	var doomed := load("res://Gameplay/Units/doomed_jackdaw.tres") as UnitDefinition
	var encounter := EncounterDefinition.new()
	for holder in [stationary, ram]:
		encounter.enemies.assign([holder, doomed])
		var run := DeckRun.new()
		run.army.append(UnitState.new(stationary))
		var battle := BattleState.new(run, encounter)
		var shifts := battle.begin_round()
		_expect(shifts.size() == 1 and battle.enemies[0].definition == doomed, "Jackdaw jumps left")
		_expect(battle.enemies[1].definition == holder, "Jump leaves the stationary unit in place")
		_expect(battle.plan_shift_deaths(shifts).is_empty(), "Successful jump saves the Jackdaw")

	for marks in [0, 1]:
		var doomed_column := 3
		if marks == 0:
			encounter.enemies.assign([stationary, stationary, doomed])
		else:
			encounter.enemies.assign([stationary, doomed, stationary, stationary, stationary])
			doomed_column = 1
		var run := DeckRun.new()
		var poop := UnitState.new(doomed)
		for mark in UnitState.POOP_MARKS:
			poop.revive()
		run.army.append(poop)
		var battle := BattleState.new(run, encounter)
		battle.enemies[doomed_column].marks = marks
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
