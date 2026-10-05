class_name ItemData
extends Resource
## Un objet du sac. Classe de base : les objets utilisables en combat (Potion, Antidote,
## Poké Ball...) en héritent et redéfinissent can_use_on() et use_on(). Un fichier .tres
## par objet dans data/items.

enum Pocket {ITEMS, MEDICINE, BALLS, BATTLE_ITEMS, KEY_ITEMS}

@export var id: StringName
@export var name := ""
@export var pocket: Pocket = Pocket.ITEMS
@export var price := 0
## Utilisable depuis le menu Sac pendant un combat.
@export var usable_in_battle := false
## Icône du sac : planche et zone (le coin haut-gauche de la zone est rendu transparent).
@export var icon_sheet: Texture2D
@export var icon_region := Rect2i()
@export_multiline var description := ""


## Vide si l'objet peut être utilisé sur ce Pokémon, sinon la raison à afficher.
func can_use_on(_engine: BattleEngine, _target: BattlePokemon) -> String:
	return "Cet objet ne peut pas être utilisé maintenant."


## Hors combat (menu Sac) : vide si l'objet peut être utilisé sur ce Pokémon de
## l'équipe, sinon la raison à afficher.
func can_use_on_pokemon(_pokemon: PokemonInstance) -> String:
	return "Ce n'est pas le moment d'utiliser ça."


## Hors combat : utilise l'objet (après can_use_on_pokemon) ; renvoie le message à afficher.
func use_on_pokemon(_pokemon: PokemonInstance) -> String:
	return ""


## Utilise l'objet (après can_use_on). Produit ses propres évènements de combat.
func use_on(_engine: BattleEngine, _target: BattlePokemon) -> void:
	push_error("%s : use_on() n'est pas défini" % id)
