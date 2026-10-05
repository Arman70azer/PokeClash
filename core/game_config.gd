class_name GameConfig
extends RefCounted
## Réglages communs à tout le jeu : échelle du monde et rendu pixel.
## La résolution elle-même reste dans project.godot (352 × 264, échelle entière ×2,
## filtre nearest) : on la lit ici plutôt que de la recopier.

## Taille d'une case, en unités du monde. À l'endroit visé par la caméra, 1 unité = 1 pixel.
const TILE := 16
## Différence de hauteur maximale entre deux cases voisines de zones différentes pour
## passer de l'une à l'autre.
const ZONE_STEP_HEIGHT := 6.0


## Taille de l'image du jeu, en pixels, avant la mise à l'échelle de la fenêtre.
static func screen_size() -> Vector2i:
	return Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
