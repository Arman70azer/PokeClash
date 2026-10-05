class_name StorageConfig
extends Resource
## Réglages du PC de stockage (data/config/storage.tres) : nombre de boîtes, places par
## boîte, disposition de la grille, noms et fonds par défaut. Rien de tout cela n'est écrit
## dans le code : changer ce fichier suffit.

## Nombre de boîtes d'un nouveau joueur. Une sauvegarde qui en a plus les garde.
@export_range(1, 64) var box_count := 8
## Places par boîte, et colonnes de la grille (les lignes s'en déduisent).
@export_range(1, 60) var box_capacity := 30
@export_range(1, 10) var columns := 6
## Nom par défaut : %d est remplacé par le numéro de la boîte.
@export var default_name := "Boîte %d"
## Longueur maximale d'un nom de boîte.
@export var name_max_length := 12
## Fond par défaut de chaque boîte (indice dans la planche des fonds, voir PcSprites).
## La boîte n reprend l'entrée n % taille.
@export var default_wallpapers := PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])
## Déposer un Pokémon dans une boîte le soigne (PV, PP, statut).
@export var heal_on_deposit := true


func default_box_name(index: int) -> String:
	return default_name % (index + 1)


func default_wallpaper(index: int) -> int:
	return default_wallpapers[index % default_wallpapers.size()] if not default_wallpapers.is_empty() else 0
