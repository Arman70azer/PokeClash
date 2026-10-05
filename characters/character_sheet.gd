class_name CharacterSheet
extends Resource
## Planche d'un personnage du monde (joueur ou PNJ) : où trouver ses 12 images et quelle
## couleur de fond rendre transparente. Un fichier par personnage dans data/characters/,
## dont le nom sert d'identifiant (Npc.sheet, Player.SLOT_LOOKS).
##
## Deux dispositions :
## - FRAMES : 3 rectangles (pas, repos, pas) par direction, n'importe où sur la planche ;
## - DS_TRAINER_CELL : une case de 96 × 128 pixels de la planche des dresseurs, avec ses
##   12 images de 32 × 32 dans l'ordre des jeux DS (voir DS_FRAMES).

enum Layout { FRAMES, DS_TRAINER_CELL }

## Taille d'une case de la planche des dresseurs.
const DS_CELL_SIZE := Vector2i(96, 128)
## Dans une case de dresseur, 12 images de 32 × 32 (3 colonnes, 4 rangées) : 0 dos,
## 1 droite, 2 dos (pas), 3 gauche (pas), 4 droite (pas), 5 face, 6 gauche, 7 droite (pas),
## 8 face (pas), 9 gauche (pas), 10 dos (pas), 11 face (pas). Les poses au repos (0, 1, 5,
## 6) sont celles où les jambes sont serrées. Ici : images (pas, repos, pas) par direction.
const DS_FRAMES := {
	Vector2i.DOWN: [8, 5, 11],
	Vector2i.LEFT: [3, 6, 9],
	Vector2i.UP: [2, 0, 10],
	Vector2i.RIGHT: [4, 1, 7],
}

@export var texture: Texture2D
## Couleur de fond unie, rendue transparente au chargement.
@export var background := Color.BLACK
@export var layout := Layout.FRAMES
## DS_TRAINER_CELL : coin haut-gauche de la case du personnage, recalé au pixel près (la
## grille de la planche n'est pas parfaitement régulière).
@export var cell_origin := Vector2i.ZERO
@export_group("Images (disposition FRAMES)")
## 3 rectangles par direction, en pixels sur la planche : pas, repos, pas.
@export var down: Array[Rect2] = []
@export var left: Array[Rect2] = []
@export var up: Array[Rect2] = []
@export var right: Array[Rect2] = []


## Partie de la planche utilisée par ce personnage.
func source_region() -> Rect2i:
	if layout == Layout.DS_TRAINER_CELL:
		return Rect2i(cell_origin, DS_CELL_SIZE)
	return Rect2i(Vector2i.ZERO, texture.get_size())


## {direction: [3 rectangles]}, en pixels dans source_region().
func frames() -> Dictionary:
	if layout == Layout.DS_TRAINER_CELL:
		var result := {}
		for facing in DS_FRAMES:
			var rects := []
			for index: int in DS_FRAMES[facing]:
				rects.append(Rect2((index % 3) * 32, (index / 3) * 32, 32, 32))
			result[facing] = rects
		return result
	return {Vector2i.DOWN: down, Vector2i.LEFT: left, Vector2i.UP: up, Vector2i.RIGHT: right}
