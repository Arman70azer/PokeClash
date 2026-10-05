class_name CliffStyle
extends Resource
## Un style de falaise pour les murs d'une zone d'expédition (plateaux du désert…) : sa
## hauteur, la texture du dessus (une case de 16 × 16) et les bandes de sa paroi, de bas
## en haut, comme les falaises des cartes 3D des jeux.

## Hauteur du dessus, en unités (16 = une case).
@export var height := 16.0
@export var top: Texture2D
## Textures des bandes de la paroi, de bas en haut, et hauteur de chacune (16 de large).
@export var bands: Array[Texture2D] = []
@export var band_heights: PackedFloat32Array = PackedFloat32Array()
