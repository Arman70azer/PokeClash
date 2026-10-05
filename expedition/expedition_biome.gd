class_name ExpeditionBiome
extends Resource
## Une zone d'expédition (Forêt, Désert…) : son type, ses tuiles, ses décors et ses
## dresseurs. ZoneGenerator s'en sert pour tirer une carte au hasard. Un fichier .tres par
## zone dans data/expeditions. Les tuiles sont des cases de 16 × 16 du tileset
## assets/tilesets/tileset_wide.png (colonne, rangée).

const NONE := Vector2i(-1, -1)

@export var id: StringName
@export var name := ""
## Type des Pokémon sauvages et des dresseurs de la zone (les Pokémon à deux types
## comptent s'ils ont celui-ci).
@export var type: PokemonType.Type = PokemonType.Type.NORMAL
## Phrase du gardien quand on choisit cette zone.
@export var description := ""

@export_group("Sol")
## Tuile de base, et quelques variantes mêlées au hasard.
@export var ground := Vector2i.ZERO
@export var ground_variants: Array[Vector2i] = []
@export_range(0.0, 1.0) var variant_density := 0.08
## Chemins qui relient l'entrée aux dresseurs (NONE : pas de chemin dessiné).
@export var path := NONE
## Hautes herbes (ou équivalent) : on y rencontre les Pokémon sauvages.
@export var encounter := Vector2i.ZERO
## Eau, lave… : infranchissable (NONE : aucun).
@export var liquid := NONE
## Part des passages transformée en mares, et des bords transformés en étendue liquide.
@export_range(0.0, 0.4) var pools := 0.0
@export_range(0.0, 1.0) var liquid_border := 0.0
## Petits détails à plat (fleurs, cailloux), tuiles à fond transparent.
@export var decor: Array[Vector2i] = []
@export_range(0.0, 0.3) var decor_density := 0.04

@export_group("Décors")
@export var props: Array[ExpeditionProp] = []
## Décors isolés posés dans les passages (part des cases libres).
@export_range(0.0, 0.2) var scatter_density := 0.03

@export_group("Rencontres")
## Chance de rencontre à chaque pas dans les hautes herbes.
@export_range(0.0, 1.0) var encounter_rate := 0.12
## Dresseurs possibles : {"title": "Pêcheur", "sheet": "marin", "front": Vector2i(1, 2)},
## où « sheet » est un personnage de data/characters et « front » la case (rangée,
## colonne) de son sprite de combat dans « Trainers - Trainers (Front).png ».
@export var trainers: Array[Dictionary] = []


func props_for(walls: bool) -> Array[ExpeditionProp]:
	var found: Array[ExpeditionProp] = []
	for prop in props:
		if (walls and prop.walls) or (not walls and prop.scatter):
			found.append(prop)
	return found
