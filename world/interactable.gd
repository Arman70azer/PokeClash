class_name Interactable
extends Node3D
## Ce que le joueur peut utiliser avec « interact » en se plaçant devant : un PNJ (Npc), un
## PC, un panneau… À placer sous Objects dans une carte (GameMap) ; régler `cell` plutôt
## que la position.
##
## Déroulement (voir PlayerInteraction) : on_interact_started(), puis les répliques
## (dialogue_lines) dans la boîte de dialogue, puis on_interact_finished() quand le joueur
## a tout lu. Les sous-classes redéfinissent ces trois points d'extension.

## Case de la carte où se trouve l'objet.
@export var cell := Vector2i.ZERO
## Nom affiché dans la boîte de dialogue (vide : pas de nom).
@export var display_name := ""
## Répliques, affichées l'une après l'autre.
@export_multiline var lines: PackedStringArray = []
## Distance (en cases) d'où l'on peut l'utiliser : plus de 1 pour parler par-dessus un
## comptoir.
@export var talk_reach := 1
## Bloque sa case (personnage). Faux pour un objet déjà dans le décor (le PC du modèle).
@export var blocks_movement := true

## Carte qui contient l'objet.
var _map: GameMap


func _ready() -> void:
	add_to_group("interactables")
	if blocks_movement:
		add_to_group("map_objects")
	_map = _find_map()


func blocks(target: Vector2i) -> bool:
	return blocks_movement and target == cell


## Carte qui contient l'objet.
func current_map() -> GameMap:
	return _map


## Répliques à afficher quand `player` l'utilise (point d'extension).
func dialogue_lines(_player: Player) -> PackedStringArray:
	return lines


## Le joueur commence à l'utiliser, en venant de la direction `from` (point d'extension).
func on_interact_started(_player: Player, _from: Vector2i) -> void:
	pass


## Le joueur a lu toutes les répliques (point d'extension).
func on_interact_finished(_player: Player) -> void:
	pass


func _find_map() -> GameMap:
	var node := get_parent()
	while node != null and not node is GameMap:
		node = node.get_parent()
	return node as GameMap
