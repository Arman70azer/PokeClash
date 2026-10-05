class_name ExpeditionProp
extends Resource
## Un décor debout d'une zone d'expédition (arbre, rocher, colonne, tombe…), découpé dans
## le tileset (assets/tilesets/tileset_wide.png) ou dans sa propre image. Il bloque les
## cases de son emprise.

## Image où le découper (vide : le tileset).
@export var sheet: Texture2D
## Zone de l'image, en pixels.
@export var region := Rect2i()
## Cases bloquées (largeur, hauteur), alignées sur le bas du sprite et centrées sous lui.
@export var footprint := Vector2i.ONE
## Chance d'être choisi par rapport aux autres décors.
@export var weight := 1.0
## Sert à remplir les bords et les murs de la zone.
@export var walls := true
## Peut être posé seul au milieu des passages.
@export var scatter := true
