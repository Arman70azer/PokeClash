extends SceneTree
## Test des intérieurs : lance la partie en hôte et entre dans chaque bâtiment d'Accumula,
## du quartier bourgeois et du port par sa porte, monte à l'étage et en redescend, puis
## ressort par le tapis. Vérifie aussi que chaque carte se charge vite.
##
##   godot --headless --path . -s res://tools/tests/test_interiors.gd

## Les types du jeu (Player, Npc…) ne sont pas nommés ici : ce script est compilé avant
## l'autoload Network dont ils dépendent.

const MAIN_SCENE := "res://main.tscn"
const PORT := 7793
const TEST_NAME := "test_interieurs"
const TEST_SAVE := "user://saves/test_interieurs.json"
## Chargement d'une carte intérieure (instanciation, grille, matériaux), en millisecondes.
const MAX_LOAD_MS := 150.0

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load(MAIN_SCENE).instantiate()
	root.add_child(main)
	await _frames(5)
	DirAccess.remove_absolute(TEST_SAVE)
	root.get_node("Game").profiles.local_name = TEST_NAME
	_check(root.get_node("Network").host(PORT) == OK, "l'hôte démarre")
	await _frames(10)
	var world: Node = root.get_node("Game").world
	var player: Node = world.player(1)
	if player == null:
		_check(false, "le joueur de l'hôte apparaît")
		return _finish()
	var town: Node = world.map(&"accumula")
	var entries := town.get_node("Warps").get_children().filter(
		func(w: Node) -> bool: return w.name != &"EnterPokemonCenter")
	_check(entries.size() == 14, "quatorze bâtiments ont une entrée (%d)" % entries.size())
	_test_layouts(world, entries)
	# La ville est libérée à chaque entrée : on reprend le passage dans la ville rechargée.
	var names := entries.map(func(w: Node) -> StringName: return w.name)
	for warp_name in names:
		await _visit(world, player, world.map(&"accumula").warp(warp_name))
	_test_regions(world)
	DirAccess.remove_absolute(TEST_SAVE)
	_finish()


## Sans y entrer : chaque carte se charge vite, ses passages et son habitant sont à leur
## place, et tout est atteignable depuis le tapis d'entrée.
func _test_layouts(world: Node, entries: Array) -> void:
	var visited := {}
	var queue: Array[StringName] = []
	for warp in entries:
		queue.append(warp.target_map)
	while not queue.is_empty():
		var id: StringName = queue.pop_front()
		if visited.has(id):
			continue
		visited[id] = true
		var start := Time.get_ticks_usec()
		var map: Node = world.load_map(id)
		var elapsed := (Time.get_ticks_usec() - start) / 1000.0
		_check(map != null, "%s : la carte existe" % id)
		if map == null:
			continue
		_check(elapsed < MAX_LOAD_MS, "%s : chargée en %.0f ms" % [id, elapsed])
		var arrivals: Array[Vector2i] = []
		for warp in map.get_node("Warps").get_children():
			var from: Vector2i = warp.trigger_cells[0] - warp.direction
			arrivals.append(from)
			_check(map.zone_at(from) != null, "%s : on peut se placer devant %s" % [id, warp.name])
			if warp.target_map != &"accumula":
				queue.append(warp.target_map)
		var reached := _reachable(map, arrivals[0])
		for cell in arrivals:
			_check(reached.has(cell), "%s : %s est atteignable" % [id, cell])
		for npc in map.get_node("Objects").get_children():
			# Dans la pièce, ou derrière un comptoir : on lui parle d'en face.
			var talkable := reached.has(npc.cell)
			for k in range(1, npc.talk_reach + 1):
				talkable = talkable or reached.has(npc.cell + npc.facing * k)
			_check(talkable, "%s : on peut parler à %s (%s)" % [id, npc.display_name, npc.cell])
		_check(reached.size() >= 30, "%s : assez de place (%d cases)" % [id, reached.size()])
		world.unload_map(id)


## Entre par la porte, visite l'étage, ressort.
func _visit(world: Node, player: Node, warp: Node) -> void:
	# Le passage disparaît avec la ville quand on entre : on garde ce qu'il faut.
	var label := String(warp.name)
	var target: StringName = warp.target_map
	var arrival: Vector2i = warp.target_cell
	var front: Vector2i = warp.trigger_cells[0] + Vector2i.DOWN
	var door: Node = warp.source()
	_check(warp.source_door.is_empty() or (door != null and door.is_inside_tree()), "%s : la porte existe" % label)
	_teleport(player, front)
	player.facing = Vector2i.UP
	player._server_move(Vector2i.UP)
	await _until(func(): return player.map_id == target and not player.moving, 6.0)
	_check(player.map_id == target and player.cell == arrival, "%s : on entre (%s %s)" % [label, player.map_id, player.cell])
	var inside: Node = player.current_map()
	if inside == null or player.map_id != target:
		return
	_check(world.current_map == target and inside.visible, "%s : l'intérieur est affiché" % label)
	# Étage : on monte, puis on redescend.
	var up: Node = inside.warp(&"GoUp")
	if up != null:
		var upper: StringName = up.target_map
		var upper_cell: Vector2i = up.target_cell
		await _take(player, inside, up)
		_check(player.map_id == upper and player.cell == upper_cell, "%s : on monte à l'étage" % label)
		var down: Node = player.current_map().warp(&"GoDown") if player.current_map() != null else null
		_check(down != null, "%s : l'étage redescend" % label)
		if down != null:
			await _take(player, player.current_map(), down)
			_check(player.map_id == target, "%s : on redescend" % label)
	inside = player.current_map()
	var leave: Node = inside.warp(&"Leave") if inside != null else null
	_check(leave != null, "%s : l'intérieur a une sortie" % label)
	if leave == null:
		return
	var door_name: StringName = leave.target_door
	var warp_name := String(door_name)
	await _take(player, inside, leave)
	_check(player.map_id == &"accumula" and player.cell == front and player.facing == Vector2i.DOWN,
		"%s : on ressort devant la porte (%s %s)" % [warp_name, player.map_id, player.cell])
	var back: Node = world.map(&"accumula").door(door_name) if world.map(&"accumula") != null else null
	if back != null and back.has_method("_amount"):
		await _frames(40)
		_check(not back._hinges.is_empty() and is_zero_approx(back._amount(0)), "%s : la porte se referme derrière" % warp_name)


## Emprunte un passage depuis la case qui le précède.
func _take(player: Node, map: Node, warp: Node) -> void:
	var target: StringName = warp.target_map
	_teleport(player, warp.trigger_cells[0] - warp.direction)
	player._server_move(warp.direction)
	await _until(func(): return player.map_id == target and not player.moving, 6.0)


## Les intérieurs ne se chevauchent pas, et restent loin de la ville et du Centre Pokémon.
func _test_regions(world: Node) -> void:
	var regions := {}
	for warp in world.load_map(&"accumula").get_node("Warps").get_children():
		regions[warp.target_map] = true
	var rects := []
	for id in regions:
		if id == &"accumula_pokemon_center":
			continue
		for map_id in [id, StringName(String(id) + "_etage"), StringName(String(id) + "_suite")]:
			if not ResourceLoader.exists("res://maps/%s/%s.tscn" % [map_id, map_id]):
				continue
			var map: Node = world.load_map(map_id)
			var grid = map.get_node("Interior").grid()
			rects.append([map_id, grid.rect()])
			if map_id != world.current_map:
				world.unload_map(map_id)
	var apart := true
	for i in rects.size():
		apart = apart and rects[i][1].position.x > 260
		for j in range(i + 1, rects.size()):
			apart = apart and not rects[i][1].intersects(rects[j][1])
	_check(apart and rects.size() == 20, "vingt intérieurs, chacun à sa place dans le monde (%d)" % rects.size())


func _reachable(map: Node, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + dir
			if not seen.has(next) and map.can_move(cell, next):
				seen[next] = true
				todo.append(next)
	return seen


func _teleport(player: Node, cell: Vector2i) -> void:
	player.cell = cell
	player.position = player.current_map().cell_to_3d(cell)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _until(condition: Callable, timeout := 3.0) -> void:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < end:
		await process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  ÉCHEC : ", label)


func _finish() -> void:
	print("Test des intérieurs : %d réussis, %d ratés" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
