class_name ExpeditionService
extends Node
## Les expéditions : le gardien d'Accumula envoie le groupe dans une zone tirée au hasard
## (voir ZoneGenerator), où l'on rencontre des Pokémon sauvages du type de la zone et des
## dresseurs, avec 20 lancers de Poké Ball au plus par joueur.
##
## Une seule expédition à la fois, partagée par tous : le premier joueur qui parle au
## gardien choisit la zone, les autres le rejoignent en lui parlant tant que quelqu'un est
## encore dans la zone. L'hôte décide de tout (graine, niveau, rencontres, Balls
## restantes) et envoie le plan de la zone à chacun avant qu'il n'y entre : tous les
## ordinateurs construisent ainsi exactement la même carte.
## À placer une fois dans la scène principale (même chemin chez tous les joueurs).

## Le plan de l'expédition en cours a changé (chez tout le monde).
signal plan_changed

const MAP_ID := &"expedition"
const BIOMES_DIR := "res://data/expeditions/"
## Ordre des zones dans le menu du gardien.
const BIOME_IDS: Array[StringName] = [&"aquatique", &"volcan", &"foret", &"jungle", &"desert", &"montagne", &"cimetiere"]
## Case du monde du coin haut-gauche des zones (loin des autres cartes).
const ORIGIN := Vector2i(600, 0)
## Retour : devant le gardien, à Accumula.
const RETURN_MAP := &"accumula"
const RETURN_CELL := Vector2i(-16, -9)
const RETURN_FACING := Vector2i.LEFT
## Lancers de Poké Ball permis par joueur et par expédition.
const BALL_LIMIT := 20
## Pokémon sauvages : écart de niveau autour du niveau de la zone (voir WildPokemon).
const LEVEL_SPREAD := Vector2i(-3, 1)
## Distance à laquelle un dresseur voit le joueur.
const SIGHT := 4
## Délai pendant lequel une expédition qui vient de commencer reste ouverte même vide
## (le temps que les joueurs y entrent).
const GRACE_TIME := 4.0

## Expédition en cours : {"biome": id, "seed": int, "level": int}, vide sinon.
var plan := {}

var _biome: ExpeditionBiome
var _balls := {}  # chez l'hôte : identifiant réseau -> lancers restants
var _defeated := {}  # identifiant réseau -> noms de dresseurs battus
var _grace := 0.0
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	Game.register(&"expeditions", self)


func _ready() -> void:
	_rng.randomize()
	Network.session_ended.connect(_on_session_ended)
	if Game.battles != null:
		Game.battles.battle_finished.connect(_on_battle_finished)


func _process(delta: float) -> void:
	if plan.is_empty() or not (Network.active and multiplayer.is_server()):
		return
	_grace -= delta
	# Plus personne dans la zone (ni en route) : l'expédition est finie.
	if _grace <= 0.0 and Game.world != null and Game.world.players_on(MAP_ID).is_empty():
		_end()


func is_running() -> bool:
	return not plan.is_empty()


func biome() -> ExpeditionBiome:
	return _biome


static func load_biome(id: StringName) -> ExpeditionBiome:
	return load(BIOMES_DIR + String(id) + ".tres") as ExpeditionBiome


## Plan de la zone en cours (le même sur tous les ordinateurs), ou null.
func layout() -> ZoneLayout:
	if _biome == null:
		return null
	return ZoneGenerator.new().generate(_biome, plan["seed"], ORIGIN)


## Ce joueur a-t-il battu ce dresseur pendant l'expédition ?
func has_defeated(peer_id: int, trainer_name: String) -> bool:
	return trainer_name in _defeated.get(peer_id, [])


## Le joueur de cet ordinateur choisit une zone (ou rejoint l'expédition en cours si
## `biome_id` est vide).
func request_start(biome_id: StringName) -> void:
	if multiplayer.is_server():
		_start_or_join(multiplayer.get_unique_id(), biome_id)
	else:
		_request_start.rpc_id(1, biome_id)


# --- Chez l'hôte -----------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request_start(biome_id: StringName) -> void:
	if multiplayer.is_server():
		_start_or_join(multiplayer.get_remote_sender_id(), biome_id)


func _start_or_join(peer_id: int, biome_id: StringName) -> void:
	var player := Game.world.player(peer_id) if Game.world != null else null
	if player == null or player.map_id == MAP_ID:
		return
	if plan.is_empty():
		if not biome_id in BIOME_IDS:
			return
		# Nouvelle zone : on oublie l'ancienne carte s'il en reste une.
		Game.world.unload_map(MAP_ID)
		_set_plan.rpc({"biome": biome_id, "seed": _rng.randi(), "level": _group_level()})
		_balls.clear()
		_defeated.clear()
		_announce.rpc("%s part en expédition : %s ! Parlez au gardien pour le rejoindre." % [
			Game.profiles.data(peer_id).player_name if Game.profiles.data(peer_id) != null else "Un joueur", _biome.name])
	elif peer_id != multiplayer.get_unique_id():
		# Un joueur qui rejoint reçoit d'abord le plan (il a pu se connecter après le départ).
		_set_plan.rpc_id(peer_id, plan)
	_grace = GRACE_TIME
	_balls[peer_id] = _balls.get(peer_id, BALL_LIMIT)
	if Game.world.load_map(MAP_ID) == null:
		return
	player.teleport(MAP_ID, _arrival_cell(), Vector2i.UP)


## Niveau de la zone : moyenne du meilleur niveau de l'équipe de chaque joueur.
func _group_level() -> int:
	var total := 0
	var count := 0
	for peer_id in [multiplayer.get_unique_id()] + Array(multiplayer.get_peers()):
		var data := Game.profiles.data(peer_id) if Game.profiles != null else null
		if data == null or data.party.is_empty():
			continue
		var best := 1
		for pokemon in data.party:
			best = maxi(best, pokemon.level)
		total += best
		count += 1
	return clampi(total / maxi(1, count), 2, 100)


## Case libre au plus près de l'entrée de la zone.
func _arrival_cell() -> Vector2i:
	var map := Game.world.map(MAP_ID)
	var zone := map.get_node_or_null("Zone") as ExpeditionZone if map != null else null
	if zone == null:
		return ORIGIN
	var start := zone.layout.to_world(zone.layout.entry)
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if map.is_cell_free(cell):
			return cell
		for dir in ZoneGenerator.DIRS:
			var next: Vector2i = cell + dir
			if not seen.has(next) and map.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return start


func _end() -> void:
	_set_plan.rpc({})
	_balls.clear()
	_defeated.clear()


## Un joueur vient de faire un pas dans la zone : dresseur qui le voit, ou rencontre dans
## les hautes herbes.
func on_player_stepped(player: Player) -> void:
	if plan.is_empty() or player.map_id != MAP_ID or not multiplayer.is_server():
		return
	if Game.battles.is_in_battle(player.peer_id):
		return
	var map := player.current_map()
	var trainer := _trainer_seeing(map, player)
	if trainer != null:
		trainer.challenge(player)
		Game.battles.start_trainer_battle(player.peer_id, trainer.trainer)
		return
	var zone := map.get_node_or_null("Zone") as ExpeditionZone
	if zone == null or not zone.is_encounter(player.cell):
		return
	if _balls.get(player.peer_id, BALL_LIMIT) == 0:
		return
	if _rng.randf() >= _biome.encounter_rate:
		return
	var wild := wild_pokemon(_rng)
	if wild != null:
		Game.battles.start_wild_battle(player.peer_id, wild, _balls.get(player.peer_id, BALL_LIMIT))


func _trainer_seeing(map: GameMap, player: Player) -> ExpeditionTrainer:
	for node in map.get_node("Objects").get_children():
		var trainer := node as ExpeditionTrainer
		if trainer == null or has_defeated(player.peer_id, trainer.trainer.name):
			continue
		for distance in range(1, SIGHT + 1):
			var cell := trainer.cell + trainer.facing * distance
			if cell == player.cell:
				return trainer
			if not map.is_walkable(cell):
				break
	return null


## Pokémon sauvage de la zone, au niveau de la zone (à quelques niveaux près).
func wild_pokemon(rng: RandomNumberGenerator) -> PokemonInstance:
	var level := clampi(int(plan["level"]) + rng.randi_range(LEVEL_SPREAD.x, LEVEL_SPREAD.y), 2, 100)
	var pokemon := WildPokemon.create(_biome.type, level, rng)
	if pokemon != null:
		pokemon.met_location = _biome.name
	return pokemon


func _on_battle_finished(peer_id: int, outcome: int, engine: BattleEngine, trainer: TrainerData) -> void:
	if plan.is_empty():
		return
	var player := Game.world.player(peer_id) if Game.world != null else null
	if player == null or player.map_id != MAP_ID:
		return
	if engine.is_wild:
		var left := engine.sides[0].balls_left
		var before: int = _balls.get(peer_id, BALL_LIMIT)
		_balls[peer_id] = left
		if left == 0 and before != 0:
			_send_to(peer_id, &"_notify", ["Vous avez lancé vos %d Poké Balls : les Pokémon sauvages vous laissent tranquille. Les dresseurs vous attendent encore !" % BALL_LIMIT])
	elif trainer != null and outcome == BattleEngine.Outcome.WIN:
		var list: Array = _defeated.get(peer_id, [])
		list.append(trainer.name)
		_defeated[peer_id] = list
		if peer_id != multiplayer.get_unique_id():
			_mark_defeated.rpc_id(peer_id, trainer.name)
	# Tous K.O. : retour devant le gardien (l'équipe est déjà soignée).
	if outcome == BattleEngine.Outcome.LOSS:
		send_home(player)


## Ramène un joueur devant le gardien.
func send_home(player: Player) -> void:
	if Game.world.load_map(RETURN_MAP) != null:
		player.teleport(RETURN_MAP, RETURN_CELL, RETURN_FACING)


func _on_session_ended() -> void:
	plan = {}
	_biome = null
	_balls.clear()
	_defeated.clear()


## Appelle une méthode chez un joueur : directement si c'est l'hôte lui-même.
func _send_to(peer_id: int, method: StringName, args: Array) -> void:
	if peer_id == multiplayer.get_unique_id():
		callv(method, args)
	else:
		rpc_id.callv([peer_id, method] + args)


# --- Chez tout le monde ------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_plan(new_plan: Dictionary) -> void:
	plan = new_plan
	_biome = load_biome(plan["biome"]) if not plan.is_empty() else null
	if not multiplayer.is_server():
		_defeated.clear()
	plan_changed.emit()


@rpc("authority", "call_local", "reliable")
func _announce(text: String) -> void:
	Events.message_requested.emit("Gardien", PackedStringArray([text]))


@rpc("authority", "call_remote", "reliable")
func _notify(text: String) -> void:
	Events.message_requested.emit("", PackedStringArray([text]))


@rpc("authority", "call_remote", "reliable")
func _mark_defeated(trainer_name: String) -> void:
	var me := multiplayer.get_unique_id()
	var list: Array = _defeated.get(me, [])
	if not trainer_name in list:
		list.append(trainer_name)
	_defeated[me] = list
