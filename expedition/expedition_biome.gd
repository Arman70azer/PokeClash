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
## Image des tuiles du sol, des chemins, des herbes et des détails (vide : le tileset).
@export var sheet: Texture2D
## Tuile de base, et quelques variantes mêlées au hasard.
@export var ground := Vector2i.ZERO
## Le sol de base est un motif de plusieurs tuiles (à partir de `ground`) répété sur la
## zone, comme la texture d'herbe des cartes 3D. De même pour les chemins, les couloirs,
## les rencontres et le liquide.
@export var ground_pattern := Vector2i.ONE
@export var ground_variants: Array[Vector2i] = []
@export_range(0.0, 1.0) var variant_density := 0.08
## Chemins qui relient l'entrée aux dresseurs (NONE : pas de chemin dessiné).
@export var path := NONE
@export var path_pattern := Vector2i.ONE
## Sol des couloirs du labyrinthe, hors des clairières (NONE : le sol de base). Pour une
## lagune : des pontons entre des îlots.
@export var corridor := NONE
@export var corridor_pattern := Vector2i.ONE
## Clairières en îlots : les rencontres et les décors isolés n'y sont qu'en clairière.
@export var islands := false
## Plan bâti plutôt qu'organique (crypte, tour) : salles rectangulaires reliées par des
## couloirs droits, les rencontres dans les salles seulement.
@export var halls := false
## Hautes herbes (ou équivalent) : on y rencontre les Pokémon sauvages.
@export var encounter := Vector2i.ZERO
@export var encounter_pattern := Vector2i.ONE
## Hautes herbes en 3D, une par case (à la place de la tuile `encounter`).
@export var encounter_mesh: Mesh
## Animation d'un pas dans les rencontres : &"grass" (les herbes bougent et cachent les
## pieds), &"sand" (nuage de sable), ou vide.
@export var step_effect: StringName
## Eau, lave… : infranchissable (NONE : aucun).
@export var liquid := NONE
@export var liquid_pattern := Vector2i.ONE
## Liquide qui borde la terre (eau peu profonde du lagon ; NONE : le liquide).
@export var shallow := NONE
@export var shallow_pattern := Vector2i.ONE
## Tous les murs sont du liquide (une mer autour des passages), sans décor.
@export var walls_liquid := false
## Part des passages transformée en mares, et des bords transformés en étendue liquide.
@export_range(0.0, 0.4) var pools := 0.0
@export_range(0.0, 1.0) var liquid_border := 0.0
## Petits détails à plat (fleurs, cailloux), tuiles à fond transparent.
@export var decor: Array[Vector2i] = []
@export_range(0.0, 0.3) var decor_density := 0.04

@export_group("Décors")
@export var props: Array[ExpeditionProp] = []
## Murs en falaises (plateaux) plutôt qu'en décors : la première, basse, borde les
## passages (elle ne cache pas ce qui est derrière) ; la seconde, haute, est au-delà de
## `cliff_clearance` rangées d'un passage.
@export var cliffs: Array[CliffStyle] = []
@export var cliff_clearance := 3
## Décors isolés posés dans les passages (part des cases libres).
@export_range(0.0, 0.2) var scatter_density := 0.03
## Décors isolés rangés en rangées dans chaque salle, de part et d'autre d'une allée
## centrale (les tombes d'un cimetière), au lieu d'être éparpillés.
@export var prop_rows := false

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
