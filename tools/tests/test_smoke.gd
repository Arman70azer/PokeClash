extends SceneTree
## Test de fumée de la partie : lance la scène principale en hôte, fait marcher le joueur,
## passe la porte du Centre Pokémon, se fait soigner, puis lance le combat contre Lyra.
## Sert de garde-fou pendant la refactorisation : il doit rester vert après chaque étape.
##
##   godot --headless --path . -s res://tools/tests/test_smoke.gd

## Les types du jeu (Player, Npc…) ne sont pas nommés ici : ce script est compilé avant
## l'autoload Network dont ils dépendent.

const MAIN_SCENE := "res://main.tscn"
const PORT := 7791
## Pseudo de test : sa sauvegarde est effacée avant et après le test.
const TEST_NAME := "test_fumee"
const TEST_SAVE := "user://saves/test_fumee.json"

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
	_check(_network().host(PORT) == OK, "l'hôte démarre")
	await _frames(10)

	var player := _local_player()
	_check(player != null, "le joueur de l'hôte apparaît")
	if player == null:
		return _finish()
	var world: Node = player.world
	var town: Node = world.map(&"accumula")
	_check(player.map_id == &"accumula" and player.cell == town.spawn_cells[0], "il apparaît sur la première case de départ")
	_check(InputMap.has_action("move_up") and InputMap.has_action("interact"), "les touches du jeu existent")
	# La vue façon DS ne doit pas bouger : 35° de champ, 45° d'inclinaison, 1 unité = 1 pixel.
	var camera := root.get_viewport().get_camera_3d()
	_check(camera != null and is_equal_approx(camera.fov, 35.0) and is_equal_approx(camera.rotation_degrees.x, -45.0),
		"la caméra garde ses réglages")
	if camera != null:
		var expected: Vector3 = player.position + Vector3(0, 8, 0) + Vector3(0, sin(PI / 4), cos(PI / 4)) * (264.0 / (2.0 * tan(deg_to_rad(35.0) / 2.0)))
		_check(camera.position.distance_to(expected) < 0.01, "la caméra cadre le joueur comme avant")

	# Un pas vers le bas.
	var start: Vector2i = player.cell
	player._server_move(Vector2i.DOWN)
	await _until(func(): return not player.moving)
	_check(player.cell == start + Vector2i.DOWN, "il fait un pas")

	# Entrée dans le Centre Pokémon.
	_teleport(player, Vector2i(12, 2))
	player._server_move(Vector2i.UP)
	await _until(func(): return not player.moving, 6.0)
	_check(player.map_id == &"accumula_pokemon_center" and player.cell == Vector2i(239, 3), "il entre dans le Centre Pokémon (%s %s)" % [player.map_id, player.cell])
	_check(world.map(&"accumula") == null and world._scenes.has(&"accumula"),
		"la ville quittée est libérée, mais sa scène reste prête : le retour ne la relit pas")
	_check(world.current_map == &"accumula_pokemon_center", "la carte du Centre est affichée")

	# L'infirmière, derrière son comptoir.
	_teleport(player, Vector2i(239, -5))
	var nurse = player.current_map().interactable_facing(player.cell, Vector2i.UP)
	_check(nurse != null and nurse.heals_party, "l'infirmière répond derrière le comptoir")
	var service := _battle_service()
	var data = root.get_node("Game").profiles.data(player.peer_id)
	_check(data != null and data.player_name == TEST_NAME and data.party.size() == 1, "nouvelle partie : un Pokémon de départ")
	var pokemon = data.party[0]
	pokemon.current_hp = 1
	service.request_heal()
	await _frames(2)
	_check(pokemon.hp() == pokemon.max_hp(), "l'équipe est soignée")
	_check(root.get_node("Game").dialogue.is_open(), "l'infirmière l'annonce dans la boîte de dialogue")
	_close_dialogue()

	# Boutique : on marche le long du comptoir (plus de murs invisibles sur les tapis),
	# et les vendeurs répondent depuis l'autre côté.
	var shop_map: Node = player.current_map()
	var floor_ok := true
	for y in range(1, 4):
		floor_ok = floor_ok and shop_map.can_step(Vector2i(241, y), Vector2i(242, y))
	floor_ok = floor_ok and shop_map.can_step(Vector2i(242, 0), Vector2i(242, 1)) and shop_map.can_step(Vector2i(242, 2), Vector2i(242, 3))
	_check(floor_ok, "le sol devant le comptoir est praticable")
	_check(not shop_map.can_step(Vector2i(242, 2), Vector2i(243, 2)), "le comptoir reste infranchissable")
	_check(shop_map.interactable_facing(Vector2i(242, 1), Vector2i.RIGHT) != null, "le vendeur répond derrière le comptoir")
	_check(shop_map.interactable_facing(Vector2i(242, 2), Vector2i.RIGHT) != null, "un vendeur répond aussi entre les deux postes")
	_teleport(player, Vector2i(242, 3))
	var clerk = player.current_map().interactable_facing(player.cell, Vector2i.RIGHT)
	_check(clerk != null and clerk.shop != null, "la vendeuse répond derrière le comptoir")
	var profiles: Node = root.get_node("Game").profiles
	var ball := "res://data/items/poke_ball.tres"
	var money_before: int = data.money
	var balls_before: int = data.bag.count(load(ball))
	profiles.request_buy(clerk.shop.resource_path, ball, 3)
	await _frames(2)
	_check(data.money == money_before - 600 and data.bag.count(load(ball)) == balls_before + 3, "achat de 3 Poké Balls")
	profiles.request_sell(ball, 1)
	await _frames(2)
	_check(data.money == money_before - 500 and data.bag.count(load(ball)) == balls_before + 2, "revente d'une Poké Ball à moitié prix")
	profiles.request_buy(clerk.shop.resource_path, ball, 99)
	await _frames(2)
	_check(data.bag.count(load(ball)) == balls_before + 2, "pas d'achat sans assez d'argent")
	_close_dialogue()

	# PC de stockage : le terminal du Centre, dépôt et retrait par l'hôte.
	var pc_map: Node = player.current_map()
	_check(pc_map.can_step(Vector2i(235, -4), Vector2i(235, -5)) and pc_map.can_step(Vector2i(236, -5), Vector2i(236, -6))
		and pc_map.can_step(Vector2i(237, -5), Vector2i(237, -6)), "on peut se placer devant le PC et à côté")
	_check(pc_map.interactable_facing(Vector2i(234, -6), Vector2i.RIGHT) != null
		and pc_map.interactable_facing(Vector2i(236, -6), Vector2i.LEFT) != null, "le PC répond aussi de côté")
	_teleport(player, Vector2i(235, -5))
	var terminal = player.current_map().interactable_facing(player.cell, Vector2i.UP)
	_check(terminal != null and terminal.get_class() == "Node3D" and terminal.has_method("dialogue_lines") and not terminal.blocks_movement,
		"le PC répond devant le terminal")
	var game: Node = root.get_node("Game")
	var pc_profiles: Node = game.profiles
	var lead = data.party[0]
	_check(data.storage.boxes[0].slots[0] != null and data.storage.boxes[0].slots[0].species.id == &"bulbasaur",
		"nouvelle partie : un Bulbizarre attend dans le PC")
	pc_profiles.request_pc_move(Vector2i(-1, 0), Vector2i(0, 1))
	await _frames(2)
	_check(data.party.size() == 1 and data.party[0] == lead, "refus : déposer le dernier Pokémon")
	data.storage.boxes[0].slots[4] = PokemonInstance.create(load("res://data/pokemon/bulbasaur.tres"), 7)
	pc_profiles.request_pc_move(Vector2i(0, 4), Vector2i(-1, 1))
	await _frames(2)
	_check(data.party.size() == 2 and data.storage.boxes[0].slots[4] == null, "retrait d'un Pokémon du PC vers l'équipe")
	pc_profiles.request_pc_move(Vector2i(-1, 1), Vector2i(2, 10))
	await _frames(2)
	_check(data.party.size() == 1 and data.storage.boxes[2].slots[10] != null, "dépôt dans la boîte 3")
	var saved_pc = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	_check(saved_pc is Dictionary and saved_pc["version"] == 2 and saved_pc["player"]["storage"]["boxes"][2]["pokemon"].size() == 1,
		"le PC est sauvegardé (format 2)")
	game.pc.open()
	await _until(func(): return game.pc.visible, 2.0)
	_check(game.pc.is_open() and player.is_busy(), "le PC s'ouvre et bloque le joueur")
	game.pc.close()
	await _frames(20)
	_check(not game.pc.is_open() and not player.is_busy(), "le PC se ferme et rend la main")

	# Sortie du Centre.
	_teleport(player, Vector2i(239, 4))
	player._server_move(Vector2i.DOWN)
	await _until(func(): return not player.moving, 6.0)
	_check(player.map_id == &"accumula" and player.cell == Vector2i(12, 2), "il ressort du Centre (%s %s)" % [player.map_id, player.cell])
	_check(world.current_map == &"accumula", "la ville est de nouveau affichée")

	# Expédition : le gardien au bout de la rue du haut, une forêt générée, une rencontre
	# sauvage avec capture, puis le retour.
	await _test_expedition(player, world)

	# Combat contre Lyra (la ville a été rechargée en ressortant du Centre).
	town = world.map(&"accumula")
	var lyra = null
	for npc in get_nodes_in_group("npcs"):
		if npc.trainer != null:
			lyra = npc
	_check(lyra != null, "Lyra est sur la carte")
	if lyra != null:
		lyra.wander_radius = 0
		var side := _free_neighbour(town, lyra.cell)
		_check(side != Vector2i.ZERO, "une case libre à côté de Lyra")
		_teleport(player, lyra.cell + side)
		service.request_trainer_battle(lyra)
		await _frames(2)
		_check(service.is_in_battle(player.peer_id), "le combat contre Lyra commence")

	var saved_cell: Vector2i = player.cell
	_network().leave()
	await _frames(5)

	# Sauvegarde : écrite en quittant, et rechargée à la session suivante.
	_check(FileAccess.file_exists(TEST_SAVE), "la partie est sauvegardée en quittant")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	_check(saved is Dictionary and saved["player"]["party"].size() == 1 and saved["player"]["map_id"] == "accumula",
		"la sauvegarde contient l'équipe et la carte")
	_check(_network().host(PORT) == OK, "l'hôte redémarre")
	await _frames(10)
	player = _local_player()
	_check(player != null and player.map_id == &"accumula" and player.cell == saved_cell,
		"le joueur reprend là où il s'était arrêté")
	_network().leave()
	await _frames(5)
	DirAccess.remove_absolute(TEST_SAVE)
	_finish()


func _test_expedition(player: Node, world: Node) -> void:
	var game: Node = root.get_node("Game")
	var expeditions: Node = game.expeditions
	var town: Node = world.map(&"accumula")
	_check(town.interactable_facing(Vector2i(-16, -9), Vector2i.LEFT) != null, "le gardien répond au bout de la rue du haut")
	_check(not town.can_step(Vector2i(-16, -9), Vector2i(-17, -9)), "le gardien bouche le passage")
	_check(not town.can_step(Vector2i(-17, -9), Vector2i(-17, -10)) and town.zone_at(Vector2i(-18, -10)) == null,
		"murs de pierre de chaque côté du passage")
	_teleport(player, Vector2i(-16, -9))
	expeditions.request_start(&"foret")
	await _until(func(): return player.map_id == &"expedition" and not player.moving, 6.0)
	_check(player.map_id == &"expedition" and expeditions.is_running(), "départ en expédition dans la forêt")
	var zone_map: Node = world.map(&"expedition")
	var zone: Node = zone_map.get_node("Zone") if zone_map != null else null
	if zone == null:
		return
	var layout = zone.layout
	_check(zone_map.display_name == "Forêt" and zone_map.warp(&"Exit") != null, "la zone a son nom et sa sortie")
	_check(zone_map.get_node("Objects").get_child_count() >= 3, "des dresseurs attendent dans la zone")
	# Rencontre : chance de rencontre forcée, un pas dans les hautes herbes.
	expeditions.biome().encounter_rate = 1.0
	var watched := {}
	for trainer in zone_map.get_node("Objects").get_children():
		for d in range(1, 5):
			watched[trainer.cell + trainer.facing * d] = true
	var target := Vector2i.ZERO
	var from := Vector2i.ZERO
	for cell in layout.encounter:
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var here: Vector2i = layout.to_world(cell + dir)
			if from == Vector2i.ZERO and zone_map.is_cell_free(here) and not layout.encounter.has(cell + dir) 					and not watched.has(here) and not watched.has(layout.to_world(cell)):
				from = here
				target = layout.to_world(cell)
	player.facing = Vector2i.UP
	_teleport(player, from)
	player._server_move(target - from)
	await _frames(3)
	var service := _battle_service()
	_check(service.is_in_battle(player.peer_id), "un Pokémon sauvage surgit des hautes herbes")
	var data = game.profiles.data(player.peer_id)
	var balls_before: int = data.bag.count(load("res://data/items/poke_ball.tres"))
	var party_before: int = data.party.size() + data.storage.count()
	for i in 30:
		if not service._battles.has(player.peer_id):
			break
		var engine = service._battles[player.peer_id]["engine"]
		engine.sides[1].active().hp = 1
		service._handle_action(player.peer_id, {"kind": 2, "item": "poke_ball", "team_index": -1})
		await _frames(1)
	var thrown: int = balls_before - data.bag.count(load("res://data/items/poke_ball.tres"))
	_check(thrown >= 1, "des Poké Balls du sac ont été lancées (%d)" % thrown)
	_check(expeditions._balls[player.peer_id] == expeditions.BALL_LIMIT - thrown, "les lancers restants sont comptés")
	_check(data.party.size() + data.storage.count() == party_before + 1, "le Pokémon capturé rejoint l'équipe")
	var caught = data.party.back()
	_check(caught.species.types.has(11) and caught.met_location == "Forêt" and caught.original_trainer == TEST_NAME,
		"Pokémon Insecte capturé, avec son lieu de capture")
	# L'écran de combat attend qu'on fasse défiler ses messages : on le ferme.
	game.battle_screen.force_close()
	_close_dialogue()
	# Retour par la sortie : sous l'entrée de la zone.
	_teleport(player, layout.to_world(layout.exit_cells[0]))
	player.moving = false
	player._server_move(Vector2i.DOWN)
	await _until(func(): return player.map_id == &"accumula" and not player.moving, 6.0)
	_check(player.map_id == &"accumula" and player.cell == Vector2i(-16, -9), "retour devant le gardien (%s %s)" % [player.map_id, player.cell])
	expeditions._grace = 0.0
	await _frames(3)
	_check(not expeditions.is_running(), "l'expédition se termine quand la zone est vide")
	# La capture a ajouté un Pokémon : on le retire pour la suite du test.
	data.party.erase(caught)


func _local_player() -> Node:
	var world: Node = root.get_node("Game").world
	return world.player(1) if world != null else null


func _battle_service() -> Node:
	return root.get_node("Game").battles


func _teleport(player: Node, cell: Vector2i) -> void:
	player.cell = cell
	player.position = player.current_map().cell_to_3d(cell)


func _free_neighbour(world: Node, cell: Vector2i) -> Vector2i:
	for dir in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		if world.is_cell_free(cell + dir):
			return dir
	return Vector2i.ZERO


func _close_dialogue() -> void:
	var box: Node = root.get_node("Game").dialogue
	if box != null:
		for i in 20:
			if box.is_open():
				box.advance()


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
	print("Test de fumée : %d réussis, %d ratés" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Les autoloads ne sont pas accessibles par leur nom dans un script lancé avec -s.
func _network() -> Node:
	return root.get_node("Network")
