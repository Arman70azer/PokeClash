class_name Warp
extends Node
## Passage d'un endroit à un autre (porte d'un bâtiment, tapis de sortie) : un joueur qui
## avance sur une des `trigger_cells` dans la direction `direction` est emmené sur
## `target_cell` de la carte `target_map`. Pour le joueur de cet ordinateur : la porte
## s'ouvre, il avance, l'écran passe au noir, puis il revient de l'autre côté.
## À placer sous le nœud Warps d'une carte (GameMap) ; le réseau le désigne par son nom.

## Cases qui déclenchent le passage (la porte elle-même peut être une case bloquée).
@export var trigger_cells: Array[Vector2i] = []
## Direction dans laquelle il faut avancer (vers le haut pour entrer par une porte).
@export var direction := Vector2i.UP
## Carte d'arrivée (identifiant, voir GameMap.map_id). Vide : la même carte.
@export var target_map: StringName
@export var target_cell := Vector2i.ZERO
@export var target_facing := Vector2i.DOWN
## Porte qui s'ouvre avant de partir (dans cette carte).
@export var source_door: NodePath
## Porte d'arrivée, ouverte puis refermée : son nom sous Doors dans la carte d'arrivée.
@export var target_door: StringName


func triggers(cell: Vector2i, move: Vector2i) -> bool:
	return move == direction and cell in trigger_cells


func source() -> Door:
	return get_node_or_null(source_door) as Door if not source_door.is_empty() else null


## Carte d'arrivée : `target_map`, ou celle du passage.
func destination_map(from_map: StringName) -> StringName:
	return target_map if not target_map.is_empty() else from_map
