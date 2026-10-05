class_name BattleService
extends Node
## Lance les combats et les fait tourner en multijoueur : l'hôte fait autorité.
##
## - L'hôte garde un BattleEngine par combat en cours ; les données des joueurs
##   (équipe, sac, argent) viennent de PlayerProfiles.
## - Un joueur demande un combat (en parlant à un dresseur), choisit ses actions et les
##   envoie à l'hôte ; l'hôte résout le tour et lui renvoie les évènements à jouer.
## - Un combat par joueur : les autres continuent d'explorer pendant ce temps.
## À placer une fois dans la scène principale (même chemin chez tous les joueurs).

## Fin d'un combat, chez l'hôte : `outcome` (BattleEngine.Outcome) et le moteur, pour
## qui veut en tirer quelque chose (expéditions : Balls lancées, dresseurs battus).
signal battle_finished(peer_id: int, outcome: int, engine: BattleEngine, trainer: TrainerData)

var _battles := {}  # identifiant réseau -> {"engine": BattleEngine, "trainer": TrainerData}
var _screen: BattleScreen


func _enter_tree() -> void:
	Game.register(&"battles", self)


func _ready() -> void:
	Network.session_ended.connect(_on_session_ended)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_screen = Game.battle_screen
	if _screen == null:
		push_error("BattleService : aucun BattleScreen dans la scène")
		return
	_screen.action_chosen.connect(_on_action_chosen)
	_screen.replacement_chosen.connect(_on_replacement_chosen)


## Vrai si ce joueur est en combat (chez l'hôte : d'après les combats en cours).
func is_in_battle(peer_id: int) -> bool:
	# Le joueur de cet ordinateur reste en combat tant que l'écran joue la fin du combat.
	if peer_id == multiplayer.get_unique_id() and _screen != null and _screen.is_open():
		return true
	return multiplayer.is_server() and _battles.has(peer_id)


## Données d'un joueur (chez l'hôte uniquement), ou null.
func player_data(peer_id: int) -> PlayerData:
	return Game.profiles.data(peer_id) if Game.profiles != null else null


## Demande un combat contre le dresseur représenté par ce PNJ.
func request_trainer_battle(npc: Npc) -> void:
	if npc == null or npc.trainer == null:
		push_error("BattleService : ce PNJ n'est pas un dresseur")
		return
	if multiplayer.is_server():
		_start_trainer_battle(multiplayer.get_unique_id(), npc)
	else:
		_request_trainer_battle.rpc_id(1, npc.get_path())


## Demande à l'infirmière de soigner l'équipe du joueur de cet ordinateur.
func request_heal() -> void:
	if multiplayer.is_server():
		_heal(multiplayer.get_unique_id())
	else:
		_request_heal.rpc_id(1)


# --- Chez l'hôte -----------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_heal() -> void:
	if multiplayer.is_server():
		_heal(multiplayer.get_remote_sender_id())


func _heal(peer_id: int) -> void:
	if _battles.has(peer_id):
		return
	var data := player_data(peer_id)
	if data == null:
		return
	data.heal_party()
	Game.profiles.save(peer_id)
	_send_to(peer_id, &"_show_healed", [])


@rpc("authority", "call_remote", "reliable")
func _show_healed() -> void:
	Events.message_requested.emit("Infirmière Joëlle", PackedStringArray([
		"…", "Merci d'avoir attendu. Vos Pokémon sont en pleine forme !", "À bientôt !"]))

@rpc("any_peer", "call_remote", "reliable")
func _request_trainer_battle(npc_path: NodePath) -> void:
	if not multiplayer.is_server():
		return
	var npc := get_node_or_null(npc_path) as Npc
	if npc == null:
		push_warning("BattleService : PNJ introuvable %s" % npc_path)
		return
	_start_trainer_battle(multiplayer.get_remote_sender_id(), npc)


func _start_trainer_battle(peer_id: int, npc: Npc) -> void:
	if _battles.has(peer_id) or npc.trainer == null or not npc.can_battle(peer_id):
		return
	if not _is_next_to(peer_id, npc):
		push_warning("BattleService : le joueur %d n'est pas à côté de %s" % [peer_id, npc.display_name])
		return
	start_trainer_battle(peer_id, npc.trainer)


## Chez l'hôte : combat de ce joueur contre un dresseur (ses conditions, comme la
## proximité, sont vérifiées par l'appelant).
func start_trainer_battle(peer_id: int, trainer: TrainerData) -> bool:
	var problems := trainer.validate()
	if not problems.is_empty():
		push_error("BattleService : dresseur %s invalide : %s" % [trainer.name, ", ".join(problems)])
		return false
	# Le dresseur se bat avec une copie de son équipe : il est en pleine forme à chaque combat.
	var team: Array[PokemonInstance] = []
	for pokemon in trainer.team:
		team.append(pokemon.duplicate(true))
	return _start(peer_id, team, trainer.full_name(), BattleAI.create(trainer.ai), trainer, false, -1)


## Chez l'hôte : combat de ce joueur contre un Pokémon sauvage. `balls_left` : Balls
## qu'il peut encore lancer (-1 : sans limite).
func start_wild_battle(peer_id: int, wild: PokemonInstance, balls_left := -1) -> bool:
	var team: Array[PokemonInstance] = [wild]
	return _start(peer_id, team, "", BattleAI.create(&"random"), null, true, balls_left)


func _start(peer_id: int, foe_team: Array[PokemonInstance], foe_name: String, ai: BattleAI, trainer: TrainerData,
		wild: bool, balls_left: int) -> bool:
	if _battles.has(peer_id):
		return false
	var data := player_data(peer_id)
	if data == null:
		return false
	if not data.has_usable_pokemon():
		_send_to(peer_id, &"_show_notice", ["Tes Pokémon sont trop fatigués pour se battre."])
		return false
	var engine := BattleEngine.new()
	engine.is_wild = wild
	engine.can_run = wild
	var own := engine.add_side("Joueur %d" % peer_id, data.party, true)
	var foe := engine.add_side(foe_name, foe_team, false, ai)
	if own == null or foe == null:
		return false
	own.peer_id = peer_id
	own.bag = data.bag
	own.balls_left = balls_left
	foe.trainer = trainer
	engine.start()
	_battles[peer_id] = {"engine": engine, "trainer": trainer}
	_flush(peer_id, true)
	return true


func _handle_action(peer_id: int, action_data: Dictionary) -> void:
	var battle: Dictionary = _battles.get(peer_id, {})
	if battle.is_empty():
		return
	var engine: BattleEngine = battle["engine"]
	var action := BattleAction.from_dict(action_data)
	if action == null:
		return
	action.side = 0  # un joueur ne joue que pour son propre camp
	var refused := engine.submit_action(action)
	if not refused.is_empty():
		engine.emit(&"say", {"text": refused})
	_flush(peer_id, false)


func _handle_replacement(peer_id: int, team_index: int) -> void:
	var battle: Dictionary = _battles.get(peer_id, {})
	if battle.is_empty():
		return
	var engine: BattleEngine = battle["engine"]
	var refused := engine.submit_replacement(0, team_index)
	if not refused.is_empty():
		engine.emit(&"say", {"text": refused})
	_flush(peer_id, false)


## Envoie au joueur les évènements produits et l'état à jour ; termine le combat s'il
## est fini.
func _flush(peer_id: int, opening: bool) -> void:
	var battle: Dictionary = _battles[peer_id]
	var engine: BattleEngine = battle["engine"]
	if engine.phase == BattleEngine.Phase.FINISHED:
		_conclude(peer_id, battle)
	var events := engine.take_events()
	var snapshot := engine.snapshot(0)
	var trainer_look := _trainer_look(battle["trainer"]) if opening else {}
	if engine.phase == BattleEngine.Phase.FINISHED:
		_battles.erase(peer_id)
		battle_finished.emit(peer_id, engine.outcome, engine, battle["trainer"])
	_send_to(peer_id, &"_receive_battle", [opening, snapshot, events, trainer_look])


## Ce qu'il faut au joueur pour dessiner le dresseur adverse (vide : Pokémon sauvage). Un
## dresseur créé en jeu (expéditions) n'a pas de fichier : on envoie son sprite.
static func _trainer_look(trainer: TrainerData) -> Dictionary:
	if trainer == null or trainer.battle_sheet == null:
		return {}
	return {"name": trainer.full_name(), "sheet": trainer.battle_sheet.resource_path, "region": trainer.front_region,
		"colors": trainer.sheet_background_colors}


## Fin du combat : argent gagné, répliques du dresseur, Pokémon capturé, évolutions,
## soins après une défaite.
func _conclude(peer_id: int, battle: Dictionary) -> void:
	var engine: BattleEngine = battle["engine"]
	var trainer: TrainerData = battle["trainer"]
	var data := player_data(peer_id)
	if data == null:
		return
	match engine.outcome:
		BattleEngine.Outcome.WIN:
			if trainer != null:
				engine.emit(&"say", {"text": "Vous avez battu %s !" % trainer.full_name()})
				if not trainer.defeat_line.is_empty():
					engine.emit(&"say", {"text": trainer.defeat_line})
				if trainer.prize_money > 0:
					data.money += trainer.prize_money
					engine.emit(&"say", {"text": "Vous remportez %d Pokédollars." % trainer.prize_money})
		BattleEngine.Outcome.CAUGHT:
			var pokemon := engine.caught
			pokemon.original_trainer = data.player_name
			pokemon.met_level = pokemon.level
			if pokemon.met_location.is_empty():
				pokemon.met_location = _location_of(peer_id)
			engine.emit(&"say", {"text": "Et hop ! %s est attrapé !" % pokemon.display_name()})
			engine.emit(&"say", {"text": data.receive_pokemon(pokemon)})
		BattleEngine.Outcome.LOSS:
			if trainer != null and not trainer.victory_line.is_empty():
				engine.emit(&"say", {"text": trainer.victory_line})
			engine.emit(&"say", {"text": "Vous n'avez plus de Pokémon en forme… Vos Pokémon sont soignés."})
			data.heal_party()
	if engine.outcome != BattleEngine.Outcome.CANCELLED:
		_evolve(engine, data)
	Game.profiles.save(peer_id)


## Après le combat, les Pokémon qui ont atteint le niveau de leur évolution évoluent.
func _evolve(engine: BattleEngine, data: PlayerData) -> void:
	for pokemon in engine.leveled_up:
		if not pokemon in data.party or pokemon.is_fainted():
			continue
		var next := pokemon.ready_evolution()
		if next == null:
			continue
		var before := pokemon.display_name()
		engine.emit(&"evolution", {"from": pokemon.species.resource_path, "to": next.resource_path, "name": before})
		var learned := pokemon.evolve_into(next)
		engine.emit(&"say", {"text": "Félicitations ! Votre %s a évolué en %s !" % [before, next.name]})
		for move in learned:
			engine.emit(&"say", {"text": "%s apprend %s !" % [pokemon.display_name(), move.name]})


## Nom du lieu où se trouve le joueur (lieu de capture).
func _location_of(peer_id: int) -> String:
	var player := Game.world.player(peer_id) if Game.world != null else null
	var here := player.current_map() if player != null else null
	return here.display_name if here != null and "display_name" in here and not here.display_name.is_empty() else ""


func _is_next_to(peer_id: int, npc: Npc) -> bool:
	var player := Game.world.player(peer_id) if Game.world != null else null
	if player == null or player.map_id != npc.current_map().map_id:
		return false
	return (player.cell - npc.cell).length_squared() == 1


func _on_session_ended() -> void:
	for battle in _battles.values():
		(battle["engine"] as BattleEngine).cancel()
	_battles.clear()
	if _screen != null:
		_screen.force_close()


func _on_peer_disconnected(peer_id: int) -> void:
	if _battles.has(peer_id):
		(_battles[peer_id]["engine"] as BattleEngine).cancel()
		_battles.erase(peer_id)


# --- Communication -------------------------------------------------------------------

## Appelle une méthode chez un joueur : directement si c'est l'hôte lui-même.
func _send_to(peer_id: int, method: StringName, args: Array) -> void:
	if peer_id == multiplayer.get_unique_id():
		callv(method, args)
	else:
		rpc_id.callv([peer_id, method] + args)


@rpc("authority", "call_remote", "reliable")
func _receive_battle(opening: bool, snapshot: Dictionary, events: Array, trainer_look: Dictionary) -> void:
	if _screen == null:
		return
	if opening:
		var trainer: TrainerData = null
		if not trainer_look.is_empty() and ResourceLoader.exists(trainer_look["sheet"]):
			trainer = TrainerData.new()
			trainer.name = trainer_look["name"]
			trainer.battle_sheet = load(trainer_look["sheet"])
			trainer.front_region = trainer_look["region"]
			trainer.sheet_background_colors.assign(trainer_look["colors"])
		_screen.open(snapshot, events, trainer)
	else:
		_screen.receive(snapshot, events)


@rpc("authority", "call_remote", "reliable")
func _show_notice(text: String) -> void:
	Events.message_requested.emit("", PackedStringArray([text]))


func _on_action_chosen(action: Dictionary) -> void:
	if multiplayer.is_server():
		_handle_action(multiplayer.get_unique_id(), action)
	else:
		_submit_action.rpc_id(1, action)


func _on_replacement_chosen(team_index: int) -> void:
	if multiplayer.is_server():
		_handle_replacement(multiplayer.get_unique_id(), team_index)
	else:
		_submit_replacement.rpc_id(1, team_index)


@rpc("any_peer", "call_remote", "reliable")
func _submit_action(action: Dictionary) -> void:
	if multiplayer.is_server():
		_handle_action(multiplayer.get_remote_sender_id(), action)


@rpc("any_peer", "call_remote", "reliable")
func _submit_replacement(team_index: int) -> void:
	if multiplayer.is_server():
		_handle_replacement(multiplayer.get_remote_sender_id(), team_index)
