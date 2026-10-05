class_name ZoneLayout
extends RefCounted
## Plan d'une zone générée (ou dessinée à la main) : ce que ZoneGenerator produit et
## qu'ExpeditionZone affiche. Coordonnées locales (0, 0) en haut à gauche ; `origin` est
## la case du monde correspondante.

var origin := Vector2i.ZERO
var size := Vector2i.ZERO
## Cases où l'on peut marcher (locales) -> vrai.
var walkable := {}
## Tuile de sol de chaque case (locale -> case du tileset).
var ground := {}
## Tuile posée par-dessus le sol (détails à fond transparent).
var overlay := {}
## Image des tuiles de `ground` et `overlay` (null : le tileset).
var sheet: Texture2D
## Hautes herbes en 3D posées sur chaque case de `encounter` (null : en tuiles).
var encounter_mesh: Mesh
## Décors debout : [{"cell": coin haut-gauche de l'emprise (local), "prop": ExpeditionProp}].
var props: Array[Dictionary] = []
## Hautes herbes (locale -> vrai).
var encounter := {}
## Dresseurs : [{"cell": locale, "facing": Vector2i}].
var trainers: Array[Dictionary] = []
## Case d'arrivée, et cases de départ vers la sortie (en avançant vers le bas).
var entry := Vector2i.ZERO
var exit_cells: Array[Vector2i] = []


func to_world(cell: Vector2i) -> Vector2i:
	return origin + cell


func to_local(cell: Vector2i) -> Vector2i:
	return cell - origin


func is_walkable(local: Vector2i) -> bool:
	return walkable.has(local)


func in_bounds(local: Vector2i) -> bool:
	return local.x >= 0 and local.y >= 0 and local.x < size.x and local.y < size.y


## Cases de marche atteignables depuis `from`, sans passer par `blocked`.
func reachable(from: Vector2i, blocked := {}) -> Dictionary:
	var seen := {}
	if not walkable.has(from) or blocked.has(from):
		return seen
	var queue: Array[Vector2i] = [from]
	seen[from] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + dir
			if walkable.has(next) and not blocked.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen
