extends SceneTree
## Test à deux joueurs : un hôte et un client, chacun dans son propre processus.
## Le client entre dans le Centre Pokémon pendant que l'hôte reste en ville : le client
## ne doit charger que la carte du Centre, l'hôte doit garder les deux cartes et ne plus
## voir le client. Lancer les deux rôles en même temps :
##
##   godot --headless --path . -s res://tools/tests/test_multiplayer.gd -- host
##   godot --headless --path . -s res://tools/tests/test_multiplayer.gd -- client
##
## Les types du jeu ne sont pas nommés ici (voir test_smoke.gd).

const PORT := 7792
const TIMEOUT := 20.0

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var role: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "host"
	root.add_child(load("res://main.tscn").instantiate())
	await _frames(5)
	var network := root.get_node("Network")
	var world: Node = root.get_node("Game").world
	var test_name := "test_" + role
	DirAccess.remove_absolute("user://saves/%s.json" % test_name)
	root.get_node("Game").profiles.local_name = test_name
	if role == "host":
		_check(network.host(PORT) == OK, "l'hôte démarre")
		await _until(func(): return world.player(2) != null or world.players.get_child_count() >= 2, TIMEOUT)
		var guest: Node = null
		for p in world.players.get_children():
			if p.peer_id != 1:
				guest = p
		_check(guest != null, "le client arrive")
		if guest != null:
			await _frames(30)
			# Place le client devant la porte du Centre.
			guest.cell = Vector2i(12, 2)
			guest._apply_state.rpc(guest.map_id, guest.cell, guest.facing)
			guest._snap_to_cell()
			await _until(func(): return guest.map_id == &"accumula_pokemon_center", TIMEOUT)
			await _frames(30)
			_check(guest.map_id == &"accumula_pokemon_center", "chez l'hôte, le client est dans le Centre")
			_check(world.map(&"accumula") != null and world.map(&"accumula_pokemon_center") != null,
				"l'hôte garde les deux cartes chargées")
			_check(world.current_map == &"accumula", "l'hôte affiche toujours la ville")
			_check(not guest.visible, "l'hôte ne voit plus le client")
			# Expédition : l'hôte part dans le désert, le client le rejoint.
			var expeditions: Node = root.get_node("Game").expeditions
			var me: Node = world.player(1)
			expeditions.request_start(&"desert")
			await _until(func(): return me.map_id == &"expedition" and not me.moving, TIMEOUT)
			_check(me.map_id == &"expedition" and expeditions.is_running(), "l'hôte part en expédition")
			await _until(func(): return guest.map_id == &"expedition", TIMEOUT)
			await _frames(30)
			_check(guest.map_id == &"expedition" and guest.visible, "le client rejoint l'expédition, l'hôte le voit")
			# Laisse les PNJ bouger un moment pendant que le client est ailleurs.
			await _until(func(): return world.players.get_child_count() < 2, TIMEOUT)
	else:
		_check(network.join("127.0.0.1", PORT) == OK, "le client se connecte")
		await _until(func(): return world.local_player() != null, TIMEOUT)
		var me: Node = world.local_player()
		_check(me != null, "le joueur du client apparaît")
		if me != null:
			await _until(func(): return me.cell == Vector2i(12, 2), TIMEOUT)
			await _frames(10)
			me._request_move.rpc_id(1, Vector2i.UP)
			await _until(func(): return me.map_id == &"accumula_pokemon_center" and not me.moving, TIMEOUT)
			await _frames(10)
			_check(world.current_map == &"accumula_pokemon_center", "le client affiche le Centre")
			_check(world.map(&"accumula") == null, "le client a déchargé la ville")
			var nurse: Node = me.current_map().interactable_facing(Vector2i(239, -5), Vector2i.UP)
			_check(nurse != null, "le client voit l'infirmière")
			# Menu du jeu : le client demande une copie de ses données à l'hôte.
			var received := []
			var profiles: Node = root.get_node("Game").profiles
			profiles.snapshot_received.connect(func(data): received.append(data))
			profiles.request_snapshot()
			await _until(func(): return not received.is_empty(), TIMEOUT)
			_check(not received.is_empty() and received[0].party.size() == 1 and received[0].player_name == "test_client",
				"le menu du client reçoit son équipe de l'hôte")
			var answers := []
			profiles.request_answered.connect(func(message): answers.append(message))
			profiles.request_use_item("res://data/items/potion.tres", 0)
			await _until(func(): return not answers.is_empty(), TIMEOUT)
			_check(not answers.is_empty(), "l'hôte répond à l'utilisation d'un objet (%s)" % [answers])
			# PC de stockage : l'hôte refuse de déposer le seul Pokémon du client.
			answers.clear()
			received.clear()
			profiles.request_pc_move(Vector2i(-1, 0), Vector2i(0, 1))
			await _until(func(): return not answers.is_empty(), TIMEOUT)
			_check(not answers.is_empty() and not received.is_empty() and received[-1].party.size() == 1
				and received[-1].storage.boxes.size() == 8, "le PC du client passe par l'hôte (%s)" % [answers])
			# Reste un peu : les gestes des PNJ de la ville ne doivent pas lui être envoyés.
			await _wait(6.0)
			# L'hôte est parti en expédition : on le rejoint.
			var expeditions: Node = root.get_node("Game").expeditions
			await _until(func(): return expeditions.is_running(), TIMEOUT)
			_check(expeditions.is_running() and expeditions.plan["biome"] == &"desert", "le client reçoit le plan de l'expédition")
			expeditions.request_start(&"")
			await _until(func(): return me.map_id == &"expedition" and not me.moving, TIMEOUT)
			await _frames(20)
			var zone_map: Node = world.map(&"expedition")
			_check(zone_map != null and zone_map.display_name == "Désert", "le client construit la zone du désert")
			if zone_map != null:
				_check(zone_map.is_walkable(me.cell) or zone_map.zone_at(me.cell) != null, "il arrive sur une case praticable de sa zone (même plan que l'hôte)")
				var host_player: Node = world.player(1)
				_check(host_player != null and host_player.visible, "le client voit l'hôte dans la zone")
				_check(zone_map.get_node("Objects").get_child_count() == zone_map.get_node("Zone").layout.trainers.size(), "les dresseurs sont placés")
		network.leave()
	await _frames(5)
	DirAccess.remove_absolute("user://saves/%s.json" % test_name)
	if role == "host":
		# L'hôte a aussi sauvegardé le client à son départ.
		await _frames(5)
		DirAccess.remove_absolute("user://saves/test_client.json")
	print("Test à deux joueurs (%s) : %d réussis, %d ratés" % [role, _passed, _failed])
	quit(1 if _failed > 0 else 0)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _until(condition: Callable, timeout: float) -> void:
	var end := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < end:
		await process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  ÉCHEC : ", label)
