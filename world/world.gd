class_name World
extends Node3D
## Le monde du jeu en « fausse 3D » façon DS : des cartes (GameMap) vues par une caméra
## inclinée en perspective, sur lesquelles les personnages sont des sprites 2D.
##
## Cartes : chaque carte est une scène maps/<id>/<id>.tscn, placée sous Maps et nommée
## par son identifiant (mêmes chemins de nœuds chez tous les joueurs).
## - L'hôte charge toutes les cartes où se trouvent des joueurs, pour valider leurs
##   déplacements, et n'affiche que celle de son propre joueur.
## - Un client ne charge que la carte où se trouve son joueur.
## Les joueurs sont sous Players (hors des cartes) : le MultiplayerSpawner les fait
## apparaître chez tout le monde ; chacun ne voit que ceux de sa carte. L'hôte fait
## apparaître un joueur dès que ses données sont chargées (PlayerProfiles.profile_ready),
## là où il s'était arrêté.
## Unités : 16 unités = 1 case. X vers la droite, Z vers le bas de la carte, Y vers le haut.

const TILE := GameConfig.TILE
const PLAYER_SCENE := preload("res://player/player.tscn")
const MAPS_DIR := "res://maps/"

## Carte affichée au lancement et où commencent les nouveaux joueurs.
@export var start_map: StringName = &"accumula"
## Réglages de la caméra (vide : la vue par défaut, data/config/camera/overworld.tres).
@export var camera_profile: CameraProfile

var _slots := {}  # peer_id -> numéro de joueur (0 à 3), côté serveur
## Scènes des cartes déjà chargées, gardées pour toute la partie. Une carte quittée est
## libérée (la ville, en entrant dans le Centre Pokémon) ; sans ce cache, ses ressources
## le seraient aussi et seraient relues sur le disque au retour (plusieurs secondes pour
## le TileSet du quartier bourgeois).
var _scenes := {}  # identifiant de carte -> PackedScene
## Cartes voisines en cours de chargement en arrière-plan (voir _preload_neighbours).
var _pending := {}  # identifiant de carte -> chemin de sa scène
var _camera: CameraRig
## Carte affichée sur cet ordinateur (celle de son joueur).
var current_map: StringName

@onready var maps: Node3D = $Maps
@onready var players: Node3D = $Players
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner


func _enter_tree() -> void:
	Game.register(&"world", self)


func _ready() -> void:
	InputSetup.install()
	_camera = CameraRig.new(camera_profile)
	add_child(_camera)
	_camera.make_current()
	show_map(start_map)
	var spawn := map(start_map).spawn_cells
	focus_camera(map(start_map).cell_to_3d(spawn[0] if not spawn.is_empty() else Vector2i.ZERO))
	spawner.spawn_function = _spawn_player
	Network.session_ended.connect(_on_session_ended)
	if Game.profiles != null:
		Game.profiles.profile_ready.connect(_on_profile_ready)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(delta: float) -> void:
	var local := local_player()
	var shown := map(current_map)
	if shown != null:
		shown.update_fade(local if local != null and local.map_id == current_map else null, delta)
	# Halo de vision : quand le décor cache entièrement ce joueur, on le voit à travers.
	if local != null and local.map_id == current_map:
		local.update_vision_halo(_camera.is_hiding(local.position, local.vision_points()), delta)


# --- Cartes ---------------------------------------------------------------------------

## Carte chargée, ou null.
func map(map_id: StringName) -> GameMap:
	return maps.get_node_or_null(NodePath(String(map_id))) as GameMap


## Charge une carte si elle ne l'est pas encore.
func load_map(map_id: StringName) -> GameMap:
	var loaded := map(map_id)
	if loaded != null:
		return loaded
	if not _scenes.has(map_id):
		var path := _scene_path(map_id)
		var preloaded: PackedScene = null
		if _pending.has(map_id):
			# Déjà lue en arrière-plan (ou presque : on attend la fin de la lecture).
			preloaded = ResourceLoader.load_threaded_get(_pending[map_id]) as PackedScene
			_pending.erase(map_id)
		if preloaded != null:
			_scenes[map_id] = preloaded
		elif not ResourceLoader.exists(path):
			push_error("World : carte introuvable %s" % path)
			return null
		else:
			_scenes[map_id] = load(path)
	loaded = (_scenes[map_id] as PackedScene).instantiate() as GameMap
	loaded.name = map_id
	maps.add_child(loaded)
	return loaded


func _scene_path(map_id: StringName) -> String:
	return MAPS_DIR + map_id + "/" + map_id + ".tscn"


## Lit en arrière-plan les scènes des cartes où mènent les passages de cette carte (les
## intérieurs de la ville) : franchir une porte n'a plus qu'à instancier la carte, sans
## lire son modèle et ses textures sur le disque au moment du passage.
func _preload_neighbours(shown: GameMap) -> void:
	var warps := shown.get_node_or_null("Warps") if shown != null else null
	if warps == null:
		return
	for warp in warps.get_children():
		var id: StringName = warp.target_map if warp is Warp else &""
		if id.is_empty() or _scenes.has(id) or _pending.has(id):
			continue
		var path := _scene_path(id)
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
			_pending[id] = path


## Retire une carte chargée (une zone d'expédition qu'on va retirer au hasard).
func unload_map(map_id: StringName) -> void:
	var loaded := map(map_id)
	if loaded != null:
		maps.remove_child(loaded)
		loaded.queue_free()


## Affiche une carte sur cet ordinateur (celle où se trouve son joueur). Chez un client,
## les autres cartes sont déchargées ; l'hôte les garde, cachées, tant qu'il y a quelqu'un.
func show_map(map_id: StringName) -> void:
	_preload_neighbours(load_map(map_id))
	current_map = map_id
	for child in maps.get_children():
		if child.name == map_id:
			child.visible = true
		elif _keep_loaded(child.name):
			child.visible = false
		else:
			child.queue_free()
	for p in players.get_children():
		if p is Player:
			p.update_visibility()


func _keep_loaded(map_id: StringName) -> bool:
	return Network.active and multiplayer.is_server() and not players_on(map_id).is_empty()


## Place la caméra pour viser un point (voir CameraRig).
func focus_camera(target: Vector3) -> void:
	_camera.focus(target)


# --- Joueurs --------------------------------------------------------------------------

## Joueur d'un pair réseau, ou null.
func player(peer_id: int) -> Player:
	for p in players.get_children():
		if p is Player and p.peer_id == peer_id and not p.is_queued_for_deletion():
			return p
	return null


## Joueur de cet ordinateur, ou null hors session.
func local_player() -> Player:
	return player(multiplayer.get_unique_id()) if Network.active else null


## Joueurs présents sur une carte.
func players_on(map_id: StringName) -> Array[Player]:
	var found: Array[Player] = []
	for p in players.get_children():
		if p is Player and p.map_id == map_id and not p.is_queued_for_deletion():
			found.append(p)
	return found


## Pairs réseau dont l'ordinateur a cette carte chargée (chez l'hôte) : ceux à qui
## envoyer ce qui s'y passe.
func peers_on(map_id: StringName) -> Array[int]:
	var found: Array[int] = []
	for p in players_on(map_id):
		if p.loaded_map == map_id:
			found.append(p.peer_id)
	return found


func _spawn_player(data: Variant) -> Node:
	var p: Player = PLAYER_SCENE.instantiate()
	p.name = str(data["id"])
	p.peer_id = data["id"]
	p.slot = data["slot"]
	p.map_id = data["map"]
	p.cell = data["cell"]
	p.facing = data.get("facing", Vector2i.DOWN)
	return p


func _add_player(id: int, profile: PlayerData) -> void:
	var slot := 0
	while slot in _slots.values():
		slot += 1
	_slots[id] = slot
	var map_id := start_map
	var cell := Vector2i.ZERO
	var facing := Vector2i.DOWN
	# Une carte de passage (expédition) n'existe plus d'une session à l'autre : on revient
	# là où elle ramène.
	if profile != null and profile.map_id == ExpeditionService.MAP_ID:
		profile.map_id = ExpeditionService.RETURN_MAP
		profile.cell = ExpeditionService.RETURN_CELL
		profile.facing = ExpeditionService.RETURN_FACING
	if profile != null and not profile.map_id.is_empty() and load_map(profile.map_id) != null:
		# Partie sauvegardée : là où il s'était arrêté.
		map_id = profile.map_id
		cell = profile.cell
		facing = profile.facing
	else:
		var spawn := map(start_map).spawn_cells
		cell = spawn[slot % spawn.size()] if not spawn.is_empty() else Vector2i.ZERO
	spawner.spawn({"id": id, "slot": slot, "map": map_id, "cell": cell, "facing": facing})


func _on_profile_ready(id: int) -> void:
	if Network.active and multiplayer.is_server() and player(id) == null:
		_add_player(id, Game.profiles.data(id))


func _on_session_ended() -> void:
	_slots.clear()
	for p in players.get_children():
		p.queue_free()
	show_map.call_deferred(start_map)


func _on_peer_disconnected(id: int) -> void:
	if not (Network.active and multiplayer.is_server()):
		return
	_slots.erase(id)
	var p := players.get_node_or_null(str(id))
	if p != null:
		p.queue_free()
