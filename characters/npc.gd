class_name Npc
extends Interactable
## Personnage non joueur, à qui l'on peut parler (voir Interactable : case, nom, répliques,
## portée).
## Il occupe une case (bloquante) et se tourne vers le joueur qui lui adresse la parole.
## À placer sous Objects dans une carte (GameMap) ; régler `cell` plutôt que la position.
##
## Pour donner vie à la ville, il se tourne de temps en temps et fait quelques pas autour
## de sa case de départ, sans s'en éloigner de plus de `wander_radius` cases. C'est l'hôte
## qui décide de ces mouvements et les annonce aux joueurs présents sur sa carte : tout
## le monde voit donc le PNJ au même endroit. Il s'arrête un moment quand quelqu'un lui parle.

const MOVE_TIME := 0.35
## Attente entre deux gestes, en secondes (tirée au hasard dans cet intervalle).
const IDLE_TIME := Vector2(2.0, 5.0)
## Durée pendant laquelle il reste immobile après qu'on lui a parlé.
const TALK_PAUSE := 8.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]

## Direction regardée au départ.
@export var facing := Vector2i.DOWN
## Personnage utilisé : nom d'un fichier de data/characters (voir CharacterSheet).
@export var sheet := "ethan"
## Teinte appliquée au sprite, pour distinguer le PNJ d'un joueur utilisant la même planche.
@export var tint := Color.WHITE
## Distance maximale, en cases, à laquelle il s'éloigne de sa case de départ.
## 0 : il ne se déplace pas, mais se tourne quand même de temps en temps.
@export var wander_radius := 2
## Se tourne de temps en temps. Faux : garde sa direction (vendeur derrière un comptoir).
@export var looks_around := true
## Dresseur : après ses répliques, il propose un combat (voir BattleService). Vide = simple habitant.
@export var trainer: TrainerData
## Infirmière : après ses répliques, elle soigne l'équipe du joueur.
@export var heals_party := false
## Vendeur : après ses répliques, il ouvre sa boutique (achat et vente).
@export var shop: ShopData

var moving := false

var _home := Vector2i.ZERO
var _home_facing := Vector2i.DOWN
var _sprite: CharacterSprite
var _tween: Tween
var _left_foot := false
var _wait := 0.0
var _pause := 0.0



func _ready() -> void:
	super._ready()
	add_to_group("npcs")
	_home = cell
	_home_facing = facing
	position = _map.cell_to_3d(cell)
	_sprite = CharacterSprite.new()
	add_child(_sprite)
	_sprite.setup(sheet, tint)
	_sprite.set_pose(facing, CharacterSprite.IDLE_FRAME)
	_wait = randf_range(IDLE_TIME.x, IDLE_TIME.y)
	Network.session_started.connect(_on_session_started)
	Network.session_ended.connect(_on_session_ended)
	if Network.active and not multiplayer.is_server():
		# Carte chargée en cours de partie : position actuelle auprès de l'hôte.
		_request_state.rpc_id(1)


func _process(delta: float) -> void:
	# Seul l'hôte décide des gestes des PNJ.
	if not (Network.active and multiplayer.is_server()) or moving:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = randf_range(IDLE_TIME.x, IDLE_TIME.y)
	var dir: Vector2i = DIRECTIONS.pick_random()
	var target := cell + dir
	var near_home := absi(target.x - _home.x) <= wander_radius and absi(target.y - _home.y) <= wander_radius
	if wander_radius > 0 and randf() < 0.5 and near_home and _map.can_step(cell, target):
		_broadcast(&"_apply_move", [target, dir])
	elif dir != facing and looks_around:
		_broadcast(&"_apply_face", [dir])


## Il se tourne vers le joueur qui lui parle et s'arrête un moment.
func on_interact_started(_player: Player, from: Vector2i) -> void:
	talk_to(from)


## Après ses répliques : boutique, combat ou soins selon son rôle.
func on_interact_finished(_player: Player) -> void:
	if shop != null and Game.shop != null:
		Game.shop.open(shop)
		return
	var battles := Game.battles
	if battles == null:
		return
	if trainer != null and can_battle(multiplayer.get_unique_id()):
		battles.request_trainer_battle(self)
	elif heals_party:
		battles.request_heal()


## Appelé par le joueur qui lui parle : il se tourne vers lui et s'arrête un moment.
## Ce dresseur accepte-t-il de se battre contre ce joueur ? (Point d'extension : un
## dresseur d'expédition déjà battu refuse.)
func can_battle(_peer_id: int) -> bool:
	return trainer != null


func talk_to(direction: Vector2i) -> void:
	_show_facing(direction)
	if multiplayer.is_server():
		_on_talked(direction)
	else:
		_talked.rpc_id(1, direction)


func _show_facing(direction: Vector2i) -> void:
	facing = direction
	if not moving:
		_sprite.set_pose(facing, CharacterSprite.IDLE_FRAME)


func _on_talked(direction: Vector2i) -> void:
	_pause = TALK_PAUSE
	if not moving:
		_broadcast(&"_apply_face", [direction])


func _on_session_started() -> void:
	if not multiplayer.is_server():
		# Récupère la position actuelle auprès de l'hôte (utile en cours de partie).
		_request_state.rpc_id(1)


func _on_session_ended() -> void:
	# Hors session, chacun retrouve sa place de départ.
	if _tween != null:
		_tween.kill()
	moving = false
	cell = _home
	facing = _home_facing
	position = _map.cell_to_3d(cell)
	_sprite.set_pose(facing, CharacterSprite.IDLE_FRAME)


@rpc("any_peer", "call_remote", "reliable")
func _talked(direction: Vector2i) -> void:
	if multiplayer.is_server():
		_on_talked(direction)


@rpc("any_peer", "call_remote", "reliable")
func _request_state() -> void:
	if multiplayer.is_server():
		_apply_state.rpc_id(multiplayer.get_remote_sender_id(), cell, facing)


@rpc("authority", "call_local", "reliable")
func _apply_move(new_cell: Vector2i, dir: Vector2i) -> void:
	cell = new_cell
	facing = dir
	moving = true
	# Un pas sur deux avec l'autre pied, puis retour à la pose de repos.
	_left_foot = not _left_foot
	_sprite.set_pose(facing, 0 if _left_foot else 2)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_position, position, _map.cell_to_3d(cell), MOVE_TIME)
	_tween.parallel().tween_callback(_sprite.set_pose.bind(facing, CharacterSprite.IDLE_FRAME)).set_delay(MOVE_TIME * 0.6)
	_tween.finished.connect(func() -> void: moving = false)


@rpc("authority", "call_local", "reliable")
func _apply_face(dir: Vector2i) -> void:
	_show_facing(dir)


@rpc("authority", "call_remote", "reliable")
func _apply_state(new_cell: Vector2i, new_facing: Vector2i) -> void:
	if _tween != null:
		_tween.kill()
	moving = false
	cell = new_cell
	facing = new_facing
	position = _map.cell_to_3d(cell)
	_sprite.set_pose(facing, CharacterSprite.IDLE_FRAME)


## Applique un geste chez l'hôte et chez les joueurs présents sur la carte du PNJ
## (les autres n'ont pas cette carte chargée).
func _broadcast(method: StringName, args: Array) -> void:
	callv(method, args)
	if Game.world == null:
		return
	for peer in Game.world.peers_on(_map.map_id):
		if peer != multiplayer.get_unique_id():
			rpc_id.callv([peer, method] + args)


func _set_position(pos: Vector3) -> void:
	# Position calée sur le pixel, pour que le sprite ne tremble pas.
	position = pos.round()
