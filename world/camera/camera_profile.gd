class_name CameraProfile
extends Resource
## Réglages d'une caméra du monde : inclinaison, champ de vision, cadrage.
## Le profil par défaut (data/config/camera/overworld.tres) reprend la vue façon DS du jeu.
## D'autres profils (intérieur, cinématique…) pourront être créés sans toucher au code.

## Inclinaison sous l'horizontale, en degrés.
@export_range(10.0, 90.0) var pitch := 45.0
## Champ de vision vertical : plus il est grand, plus la perspective est marquée.
@export_range(5.0, 90.0) var fov := 35.0
## Hauteur visible (en unités) au niveau du point visé. 0 : la hauteur de l'écran du jeu,
## pour que 1 unité = 1 pixel et que les sprites restent nets. Pour dézoomer sans flou,
## augmenter la résolution du projet plutôt que cette valeur.
@export var view_height := 0.0
## Le point visé est un peu au-dessus des pieds de la cible.
@export var target_lift := 8.0
## Plan proche éloigné : la caméra est toujours loin de la scène, et cela garde une bonne
## précision de profondeur.
@export var near := 50.0
@export var far := 4000.0


func effective_view_height() -> float:
	return view_height if view_height > 0.0 else float(GameConfig.screen_size().y)


## Distance entre la caméra et le point visé pour cadrer `effective_view_height()` unités.
func distance() -> float:
	return effective_view_height() / (2.0 * tan(deg_to_rad(fov) / 2.0))
