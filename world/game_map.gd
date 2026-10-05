class_name GameMap
extends Node3D
## Une carte du jeu (une ville et ses abords, l'intérieur d'un bâtiment…) : une scène
## maps/<map_id>/<map_id>.tscn dont ce nœud est la racine.
##
## Enfants attendus :
## - des zones (MapZone, TileZone, ou des scènes de zone instanciées) ;
## - Doors : les portes animées (Door) ;
## - Warps : les passages vers d'autres cases ou d'autres cartes (Warp) ;
## - Objects : les PNJ (Npc) et objets 3D posés en plus des zones.
##
## Chaque carte occupe sa propre région du monde (l'intérieur du Centre Pokémon est à
## environ +4000 unités de la ville) : l'hôte garde toutes les cartes chargées pour
## valider les déplacements, et elles ne doivent pas se superposer.
## La carte répond aux questions de déplacement : sol, hauteurs, obstacles, PNJ, passages.

const TILE := GameConfig.TILE

## Identifiant de la carte, égal au nom de son dossier dans maps/.
@export var map_id: StringName
## Nom affiché (panneau d'entrée, sauvegarde…).
@export var display_name := ""
## Cases où apparaissent les nouveaux joueurs, dans l'ordre d'arrivée.
@export var spawn_cells: Array[Vector2i] = []


## Zones de la carte : les nœuds qui ont une grille de déplacement.
func zones() -> Array[Node]:
	var found: Array[Node] = []
	for child in get_children():
		if child.has_method("grid"):
			found.append(child)
	return found


## Zone où l'on peut se tenir sur cette case, ou null.
func zone_at(cell: Vector2i) -> Node:
	for zone in zones():
		var g: MapGrid = zone.grid()
		if g != null and g.is_standable(cell):
			return zone
	return null


## Hauteur du sol d'une case.
func height(cell: Vector2i) -> float:
	var zone := zone_at(cell)
	return zone.grid().height(cell) if zone != null else 0.0


## Centre d'une case, posé sur le sol (avec le décalage d'affichage de la case, voir
## MapGrid.offsets).
func cell_to_3d(cell: Vector2i) -> Vector3:
	var zone := zone_at(cell)
	var shift: Vector2 = zone.grid().offset(cell) if zone != null else Vector2.ZERO
	return Vector3(cell.x * TILE + TILE / 2.0 + shift.x, height(cell), cell.y * TILE + TILE / 2.0 + shift.y)


## Vrai si l'on peut passer d'une case à sa voisine d'après les grilles des zones
## (sans tenir compte des personnages).
func can_move(from: Vector2i, to: Vector2i) -> bool:
	var a := zone_at(from)
	var b := zone_at(to)
	if a == null or b == null:
		return false
	if a == b:
		return a.grid().can_move(from, to)
	# D'une zone à l'autre : seulement entre deux sols de même niveau.
	return absf(height(from) - height(to)) <= GameConfig.ZONE_STEP_HEIGHT


## Vrai si l'on peut se tenir sur la case : sol praticable et aucun objet ou PNJ dessus.
func is_walkable(cell: Vector2i) -> bool:
	if zone_at(cell) == null:
		return false
	for obj in get_tree().get_nodes_in_group("map_objects"):
		if is_ancestor_of(obj) and obj.blocks(cell):
			return false
	return true


## Vrai si la case est praticable et qu'aucun joueur de cette carte ne s'y trouve.
func is_cell_free(cell: Vector2i) -> bool:
	if not is_walkable(cell):
		return false
	var world := Game.world
	if world != null:
		for p in world.players_on(map_id):
			if p.cell == cell:
				return false
	return true


## Vrai si un personnage peut faire un pas d'une case à sa voisine.
func can_step(from: Vector2i, to: Vector2i) -> bool:
	return can_move(from, to) and is_cell_free(to)


## Passage déclenché en avançant sur `cell` dans la direction `move`, ou null.
func warp_at(cell: Vector2i, move: Vector2i) -> Warp:
	var warps := get_node_or_null("Warps")
	if warps == null:
		return null
	for warp in warps.get_children():
		if warp is Warp and warp.triggers(cell, move):
			return warp
	return null


## Passage nommé de cette carte, ou null.
func warp(warp_name: StringName) -> Warp:
	return get_node_or_null(NodePath("Warps/" + warp_name)) as Warp


## Porte nommée de cette carte, ou null.
func door(door_name: StringName) -> Door:
	if door_name.is_empty():
		return null
	return get_node_or_null(NodePath("Doors/" + door_name)) as Door


## Ce que le joueur utilise depuis `cell` en regardant vers `facing` (PNJ, PC… voir
## Interactable) : sur la case voisine, ou plus loin par-dessus un comptoir (talk_reach).
## Un PNJ derrière un comptoir répond aussi au client placé une case à côté de lui.
func interactable_facing(cell: Vector2i, facing: Vector2i) -> Interactable:
	var side := Vector2i(facing.y, facing.x)
	for distance in range(1, 4):
		var ahead := cell + facing * distance
		var npc := interactable_at(ahead)
		if npc != null and distance <= npc.talk_reach:
			return npc
		if distance == 1 and can_move(cell, cell + facing):
			return null
		if distance > 1:
			for neighbour in [interactable_at(ahead + side), interactable_at(ahead - side)]:
				if neighbour != null and neighbour.talk_reach > 1 and distance <= neighbour.talk_reach:
					return neighbour
	return null


## Objet utilisable (PNJ, PC…) sur une case, ou null.
func interactable_at(cell: Vector2i) -> Interactable:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node.cell == cell and is_ancestor_of(node):
			return node
	return null


## Met à jour le fondu de niveau des zones d'après le joueur de cet ordinateur
## (null : aucun joueur sur cette carte).
func update_fade(local: Player, delta: float) -> void:
	for zone in get_children():
		if zone is MapZone:
			if local != null:
				zone.update_fade(local.cell, local.position.y, true, delta)
			else:
				zone.update_fade(Vector2i.ZERO, 0.0, false, delta)
