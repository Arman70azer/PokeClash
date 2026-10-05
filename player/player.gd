class_name Player
extends Node3D
## Joueur en déplacement case par case sur la grille de sa carte, relief compris,
## affiché comme un sprite 2D dans la scène 3D.
## Le serveur fait autorité : le client demande un pas, le serveur valide
## (murs, autres joueurs, passages) puis diffuse le résultat à tout le monde.
## Les conversations (PNJ, combats, soins) sont gérées par PlayerInteraction, les
## passages de porte par WarpTransition.

const MOVE_TIME := 0.2
const REQUEST_INTERVAL := 0.1
const DIRECTIONS := {
	"move_up": Vector2i.UP,
	"move_down": Vector2i.DOWN,
	"move_left": Vector2i.LEFT,
	"move_right": Vector2i.RIGHT,
}

const IDLE_FRAME := CharacterSprite.IDLE_FRAME
## Planche et teinte de chaque joueur, dans l'ordre d'arrivée. Tous les joueurs
## partagent la même planche pour l'instant, distingués par une teinte.
const SLOT_LOOKS: Array[Dictionary] = [
	{"sheet": "ethan", "tint": Color.WHITE},
	{"sheet": "ethan", "tint": Color(0.75, 0.85, 1.25)},
	{"sheet": "ethan", "tint": Color(1.2, 1.15, 0.7)},
	{"sheet": "ethan", "tint": Color(1.1, 0.75, 1.2)},
]

var peer_id := 1
var slot := 0
## Carte où se trouve le joueur (GameMap.map_id).
var map_id: StringName
## Chez l'hôte : carte que l'ordinateur de ce joueur a fini de charger (vide pendant un
## passage). Les PNJ n'envoient leurs gestes qu'aux joueurs qui ont leur carte chargée.
var loaded_map: StringName
var cell := Vector2i.ZERO
var facing := Vector2i.DOWN
var moving := false

var _tween: Tween
var _cooldown := 0.0
var _frame := IDLE_FRAME
var _left_foot := false
var _sprite: CharacterSprite

@onready var world: World = Game.world


func _ready() -> void:
	var look: Dictionary = SLOT_LOOKS[slot % SLOT_LOOKS.size()]
	_sprite = CharacterSprite.new()
	add_child(_sprite)
	_sprite.setup(look["sheet"], look["tint"])
	_set_frame(_frame)
	var interaction := PlayerInteraction.new()
	interaction.name = "Interaction"
	add_child(interaction)
	if is_local():
		world.show_map(map_id)
		confirm_map_loaded()
	_snap_to_cell()
	update_visibility()
	if not multiplayer.is_server():
		# Récupère la position actuelle (utile si on rejoint en cours de partie).
		_request_state.rpc_id(1)


func _process(_delta: float) -> void:
	if is_local():
		world.focus_camera(position)


## Carte du joueur, si elle est chargée sur cet ordinateur.
func current_map() -> GameMap:
	return world.map(map_id)


## Vrai pour le joueur de cet ordinateur.
func is_local() -> bool:
	return Network.active and peer_id == multiplayer.get_unique_id()


## Visible seulement s'il est sur la carte affichée par cet ordinateur.
func update_visibility() -> void:
	visible = map_id == world.current_map


## Points opaques du sprite affiché (voir CharacterSprite.vision_points).
func vision_points() -> Array[Vector2]:
	return _sprite.vision_points() if _sprite != null else []


## Halo de vision de ce joueur (voir CameraRig.is_hiding).
func update_vision_halo(hidden: bool, delta: float) -> void:
	if _sprite != null:
		_sprite.update_vision_halo(hidden, delta)


## Vrai si le joueur ne peut pas bouger : conversation ou combat en cours.
func is_busy() -> bool:
	var box := Game.dialogue
	var battles := Game.battles
	var menu := Game.menu
	if menu != null and menu.is_open():
		return true
	if Game.shop != null and Game.shop.is_open():
		return true
	if Game.pc != null and Game.pc.is_open():
		return true
	if Game.expedition_screen != null and Game.expedition_screen.is_open():
		return true
	return (box != null and box.is_open()) or (battles != null and battles.is_in_battle(peer_id))


func _physics_process(delta: float) -> void:
	if not is_local() or moving or is_busy():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	for action in DIRECTIONS:
		if Input.is_action_pressed(action):
			_cooldown = REQUEST_INTERVAL
			var dir: Vector2i = DIRECTIONS[action]
			if multiplayer.is_server():
				_server_move(dir)
			else:
				_request_move.rpc_id(1, dir)
			return


# --- Chez l'hôte ----------------------------------------------------------------------

func _server_move(dir: Vector2i) -> void:
	var battles := Game.battles
	if moving or not dir in DIRECTIONS.values() or (battles != null and battles.is_in_battle(peer_id)):
		return
	var here := current_map()
	if here == null:
		return
	var target := cell + dir
	var warp := here.warp_at(target, dir)
	if warp != null:
		var destination := warp.destination_map(map_id)
		# L'hôte garde chargée toute carte où se trouve un joueur.
		if world.load_map(destination) == null:
			return
		loaded_map = &""
		_apply_warp.rpc(warp.name, destination, warp.target_cell, warp.target_facing, dir)
		return
	if here.can_step(cell, target):
		_apply_move.rpc(target, dir)
		if Game.profiles != null:
			Game.profiles.on_player_stepped(peer_id)
		if Game.expeditions != null:
			Game.expeditions.on_player_stepped(self)
	else:
		_apply_face.rpc(dir)


## Chez l'hôte : emmène le joueur ailleurs (expédition, retour), avec le même fondu
## qu'un passage de porte.
func teleport(destination: StringName, target_cell: Vector2i, target_facing: Vector2i) -> void:
	if world.load_map(destination) == null:
		return
	loaded_map = &""
	_apply_teleport.rpc(destination, target_cell, target_facing)


@rpc("any_peer", "call_remote", "reliable")
func _request_move(dir: Vector2i) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id:
		_server_move(dir)


## Indique à l'hôte que cet ordinateur a chargé la carte de son joueur.
func confirm_map_loaded() -> void:
	if multiplayer.is_server():
		loaded_map = map_id
	else:
		_map_loaded.rpc_id(1, map_id)


@rpc("any_peer", "call_remote", "reliable")
func _map_loaded(loaded: StringName) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id and loaded == map_id:
		loaded_map = loaded


@rpc("any_peer", "call_remote", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_apply_state.rpc_id(multiplayer.get_remote_sender_id(), map_id, cell, facing)


# --- Chez tout le monde ---------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _apply_move(new_cell: Vector2i, dir: Vector2i) -> void:
	cell = new_cell
	facing = dir
	var here := current_map()
	if here == null:
		# Carte non chargée ici : le joueur n'est pas visible, seule sa case compte.
		return
	moving = true
	# Un pas sur deux avec l'autre pied, puis retour à la pose de repos.
	_left_foot = not _left_foot
	_set_frame(0 if _left_foot else 2)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_position, position, here.cell_to_3d(cell), MOVE_TIME)
	_tween.parallel().tween_callback(_set_frame.bind(IDLE_FRAME)).set_delay(MOVE_TIME * 0.6)
	_tween.finished.connect(_on_move_finished)
	# Herbes qui bougent, sable qui vole… (zones d'expédition).
	var zone := here.zone_at(cell)
	if zone != null and zone.has_method("on_step"):
		zone.on_step(self, cell, MOVE_TIME)


## Passage par une porte ou un tapis de sortie, éventuellement vers une autre carte.
@rpc("authority", "call_local", "reliable")
func _apply_warp(warp_name: StringName, destination: StringName, target_cell: Vector2i, target_facing: Vector2i, dir: Vector2i) -> void:
	moving = true
	facing = dir
	var source_map := current_map()
	var warp: Warp = source_map.warp(warp_name) if source_map != null else null
	await WarpTransition.play(self, warp, destination, target_cell, target_facing, dir)
	moving = false
	_cooldown = 0.0


@rpc("authority", "call_local", "reliable")
func _apply_teleport(destination: StringName, target_cell: Vector2i, target_facing: Vector2i) -> void:
	if _tween != null:
		_tween.kill()
	moving = true
	await WarpTransition.play(self, null, destination, target_cell, target_facing, Vector2i.ZERO)
	moving = false
	_cooldown = 0.0


@rpc("authority", "call_local", "reliable")
func _apply_face(dir: Vector2i) -> void:
	facing = dir
	_set_frame(_frame)


@rpc("authority", "call_remote", "reliable")
func _apply_state(new_map: StringName, new_cell: Vector2i, new_facing: Vector2i) -> void:
	if _tween != null:
		_tween.kill()
	moving = false
	var changed := new_map != map_id
	map_id = new_map
	cell = new_cell
	facing = new_facing
	if changed and is_local():
		world.show_map(map_id)
		confirm_map_loaded()
	_snap_to_cell()
	update_visibility()
	_set_frame(IDLE_FRAME)


## Arrivée sur une case, sans animation (warp, état reçu de l'hôte).
func place(new_map: StringName, new_cell: Vector2i, new_facing: Vector2i) -> void:
	map_id = new_map
	cell = new_cell
	facing = new_facing
	_set_frame(IDLE_FRAME)
	_snap_to_cell()
	update_visibility()


func step_frame() -> void:
	_left_foot = not _left_foot
	_set_frame(0 if _left_foot else 2)


func idle_frame() -> void:
	_set_frame(IDLE_FRAME)


func _snap_to_cell() -> void:
	var here := current_map()
	if here != null:
		_set_position(here.cell_to_3d(cell))


func _set_position(pos: Vector3) -> void:
	# Position calée sur le pixel, et caméra déplacée dans la même image :
	# sans cela le personnage tremble d'un pixel à chaque pas.
	position = pos.round()
	if is_local():
		world.focus_camera(position)


func _set_frame(frame: int) -> void:
	_frame = frame
	if _sprite != null:
		_sprite.set_pose(facing, _frame)


func _on_move_finished() -> void:
	moving = false
	_cooldown = 0.0
