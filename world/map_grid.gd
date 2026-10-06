class_name MapGrid
extends Resource
## Grille de déplacement d'une zone 3D : pour chaque case, la hauteur du sol et
## les passages possibles. Calculée une fois par tools/maps/bake_map_grid.gd à partir du
## modèle de la zone, puis enregistrée : tous les joueurs utilisent ainsi exactement
## les mêmes collisions.

const STANDABLE := 1  ## on peut se tenir sur la case
const EAST := 2       ## on peut passer de cette case à sa voisine de droite (x + 1)
const SOUTH := 4      ## on peut passer de cette case à sa voisine du bas (y + 1)

## Case correspondant au premier élément des tableaux (coin haut-gauche).
@export var origin := Vector2i.ZERO
## Taille de la grille, en cases.
@export var size := Vector2i.ZERO
## Hauteur du sol au centre de chaque case, en unités.
@export var heights := PackedFloat32Array()
## Drapeaux STANDABLE / EAST / SOUTH de chaque case.
@export var flags := PackedByteArray()
## Cases bloquées à la main, pour corriger le calcul automatique (eau, décor...).
@export var blocked: Array[Vector2i] = []
## Cases rendues praticables à la main (sol pris pour un obstacle, par exemple un tapis
## au pied d'un comptoir). Leurs passages vers les voisines s'ouvrent avec `opened`.
@export var walkable: Array[Vector2i] = []
## Décalage d'affichage de certaines cases, en unités (x vers la droite, y vers le bas de
## la carte) : un personnage qui s'y tient est dessiné un peu à côté du centre, par exemple
## collé à un comptoir sans le chevaucher. N'a aucun effet sur les déplacements.
@export var offsets: Dictionary = {}
## Passages ouverts à la main entre deux cases voisines, pour corriger le calcul
## automatique (petit décor franchissable pris pour un obstacle). Chaque élément est
## (x1, y1, x2, y2) : les deux cases, dans n'importe quel ordre.
@export var opened: Array[Vector4i] = []
## Cases utilisables (vide : toute la grille). Écarte le plancher qui entoure certains
## intérieurs (l'hôtel de Driftveil est posé sur une grande dalle).
@export var bounds := Rect2i()


func rect() -> Rect2i:
	return Rect2i(origin, size)


func _index(cell: Vector2i) -> int:
	var local := cell - origin
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return -1
	return local.y * size.x + local.x


func offset(cell: Vector2i) -> Vector2:
	return offsets.get(cell, Vector2.ZERO)


func height(cell: Vector2i) -> float:
	var i := _index(cell)
	return heights[i] if i != -1 else 0.0


func is_standable(cell: Vector2i) -> bool:
	var i := _index(cell)
	if i == -1 or cell in blocked or (bounds.has_area() and not bounds.has_point(cell)):
		return false
	return flags[i] & STANDABLE != 0 or cell in walkable


## Vrai si l'on peut passer d'une case à une case voisine (haut, bas, gauche, droite).
func can_move(from: Vector2i, to: Vector2i) -> bool:
	if not is_standable(from) or not is_standable(to):
		return false
	if Vector4i(from.x, from.y, to.x, to.y) in opened or Vector4i(to.x, to.y, from.x, from.y) in opened:
		return true
	var step := to - from
	if step == Vector2i.RIGHT:
		return flags[_index(from)] & EAST != 0
	if step == Vector2i.LEFT:
		return flags[_index(to)] & EAST != 0
	if step == Vector2i.DOWN:
		return flags[_index(from)] & SOUTH != 0
	if step == Vector2i.UP:
		return flags[_index(to)] & SOUTH != 0
	return false


## Copie de la grille décalée de `shift` cases : un même intérieur sert à plusieurs cartes,
## chacune à sa place dans le monde (voir MapZone.cell_offset).
func shifted(shift: Vector2i) -> MapGrid:
	var copy := duplicate() as MapGrid
	copy.origin = origin + shift
	if bounds.has_area():
		copy.bounds = Rect2i(bounds.position + shift, bounds.size)
	copy.blocked.assign(blocked.map(func(c: Vector2i) -> Vector2i: return c + shift))
	copy.walkable.assign(walkable.map(func(c: Vector2i) -> Vector2i: return c + shift))
	copy.opened.assign(opened.map(func(o: Vector4i) -> Vector4i: return o + Vector4i(shift.x, shift.y, shift.x, shift.y)))
	copy.offsets = {}
	for cell: Vector2i in offsets:
		copy.offsets[cell + shift] = offsets[cell]
	return copy
