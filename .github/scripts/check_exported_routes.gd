extends SceneTree
## Run from the exported Web pack so route data is checked after serialization.


func _initialize() -> void:
	_check_routes.call_deferred()


func _check_routes() -> void:
	var scene := load("res://game_loop.tscn") as PackedScene
	var rules = load("res://Gameplay/deck_run.gd")
	if scene == null or rules == null:
		_fail("Could not load the city routes from the exported game")
		return

	var game := scene.instantiate()
	var route: Array = game.get("encounters")
	game.free()
	if route.is_empty() or route[0].map_stage != 1:
		_fail("The exported city map has no starting encounter")
		return

	var last_stage := 0
	for encounter in route:
		last_stage = maxi(last_stage, encounter.map_stage)

	var visited := {}
	var pending: Array = [route[0]]
	while not pending.is_empty():
		var encounter: Resource = pending.pop_back()
		if visited.has(encounter):
			continue
		visited[encounter] = true
		var exits: Array = rules.route_successors(encounter, route)
		if exits.is_empty() and encounter.map_stage < last_stage:
			_fail("The exported encounter %s has no exits" % encounter.title)
			return
		pending.append_array(exits)

	if visited.size() != route.size():
		_fail("Only %d of %d exported encounters are reachable" % [visited.size(), route.size()])
		return
	print("Verified all %d exported city encounters" % route.size())
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
