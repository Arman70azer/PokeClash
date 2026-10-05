class_name PokemonSpecies
extends Resource
## Une espèce de Pokémon (Salamèche, Bulbizarre...) : tout ce qui est commun à tous les
## Pokémon de l'espèce. Un fichier .tres par espèce dans data/pokemon.
## Les Pokémon eux-mêmes (niveau, PV, attaques connues) sont des PokemonInstance.
##
## Cas particuliers : créer une sous-classe et redéfinir les méthodes marquées
## « point d'extension » (statistiques, types, attaques de départ).

@export var id: StringName
@export var dex_number := 0
@export var name := ""
## Un ou deux types.
@export var types: Array[PokemonType.Type] = []

@export_group("Statistiques de base")
@export var base_hp := 1
@export var base_attack := 1
@export var base_defense := 1
@export var base_sp_attack := 1
@export var base_sp_defense := 1
@export var base_speed := 1

@export_group("Divers")
## Description du Pokédex.
@export_multiline var description := ""
## Talents possibles, et talent caché.
@export var abilities: Array[AbilityData] = []
@export var hidden_ability: AbilityData
## Courbe d'expérience (identifiant : medium, medium-slow, fast…).
@export var growth_rate: StringName = &"medium-slow"
## EV donnés quand on le met K.O., dans l'ordre de Stat.PERMANENT.
@export var ev_yield := PackedInt32Array([0, 0, 0, 0, 0, 0])
## Expérience de base donnée quand on le met K.O.
@export var base_experience := 0
@export var catch_rate := 45
## Part de femelles, en pourcentage ; -1 : espèce asexuée.
@export_range(-1.0, 100.0) var female_ratio := 50.0

@export_group("Évolution")
## Espèce dont celle-ci est l'évolution (vide pour une forme de base).
@export var evolves_from: StringName
@export var evolutions: Array[EvolutionData] = []

@export_group("Attaques")
## Attaques apprises en montant de niveau.
@export var learnset: Array[LearnsetEntry] = []

@export_group("Icône de menu")
## Planche des icônes (équipe, sac…) et zone de l'icône, en pixels. La couleur du coin
## haut-gauche de la zone est rendue transparente.
@export var icon_sheet: Texture2D
@export var icon_region := Rect2i()

@export_group("Sprites de combat")
## Planche contenant les sprites, et zones de face (vu par l'adversaire) et de dos
## (Pokémon du joueur), en pixels.
@export var battle_sheet: Texture2D
@export var front_region := Rect2i()
@export var back_region := Rect2i()
## Couleurs de fond de la planche à rendre transparentes.
@export var sheet_background_colors: Array[Color] = []
## Décalage de la deuxième image d'animation par rapport à la première (Vector2i.ZERO :
## pas de deuxième image). Sur les planches HGSS, elle est juste à droite.
@export var animation_frame_offset := Vector2i(81, 0)


const DATA_DIR := "res://data/pokemon/"


## Espèce de data/pokemon d'après son identifiant, ou null.
static func find(species_id: StringName) -> PokemonSpecies:
	var path := DATA_DIR + String(species_id) + ".tres"
	return load(path) as PokemonSpecies if not String(species_id).is_empty() and ResourceLoader.exists(path) else null


## Évolution par le niveau que ce Pokémon peut faire maintenant, ou null.
func level_evolution(level: int) -> EvolutionData:
	for evolution in evolutions:
		if evolution.method == EvolutionData.Method.LEVEL and evolution.min_level > 0 and level >= evolution.min_level:
			return evolution
	return null


## Attaques que cette espèce apprend exactement à ce niveau.
func moves_learned_at(level: int) -> Array[MoveData]:
	var found: Array[MoveData] = []
	for entry in learnset:
		if entry.level == level and entry.move != null and not entry.move in found:
			found.append(entry.move)
	return found


func base_stat(stat: int) -> int:
	match stat:
		Stat.HP: return base_hp
		Stat.ATTACK: return base_attack
		Stat.DEFENSE: return base_defense
		Stat.SP_ATTACK: return base_sp_attack
		Stat.SP_DEFENSE: return base_sp_defense
		Stat.SPEED: return base_speed
	push_error("PokemonSpecies %s : pas de statistique de base pour %d" % [id, stat])
	return 0


## Point d'extension : valeur finale d'une statistique, calculée par les règles. Une
## espèce particulière peut la retoucher (par exemple, PV fixes à 1 comme Munja).
func adjust_stat(_stat: int, value: int, _pokemon: PokemonInstance) -> int:
	return value


## Point d'extension : types en combat (une espèce qui change de type selon sa forme).
func battle_types(_pokemon: PokemonInstance) -> Array:
	return types.duplicate()


## Point d'extension : attaques connues par un Pokémon sauvage ou neuf de ce niveau :
## les quatre dernières apprises, comme dans les jeux officiels.
func moves_at_level(level: int) -> Array[MoveData]:
	var known: Array[MoveData] = []
	var sorted := learnset.duplicate()
	sorted.sort_custom(func(a: LearnsetEntry, b: LearnsetEntry) -> bool: return a.level < b.level)
	for entry: LearnsetEntry in sorted:
		if entry.level > level or entry.move == null:
			continue
		if entry.move in known:
			continue
		known.append(entry.move)
		if known.size() > 4:
			known.pop_front()
	return known


## Vérifie la cohérence de la donnée ; renvoie la liste des problèmes trouvés.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id.is_empty():
		problems.append("espèce sans id (%s)" % resource_path)
	if types.is_empty() or types.size() > 2:
		problems.append("espèce %s : il faut un ou deux types" % id)
	for stat in Stat.PERMANENT:
		if base_stat(stat) <= 0:
			problems.append("espèce %s : statistique de base %s nulle" % [id, Stat.stat_name(stat)])
	if learnset.is_empty():
		problems.append("espèce %s : aucune attaque apprise" % id)
	for entry in learnset:
		if entry == null or entry.move == null:
			problems.append("espèce %s : ligne d'attaque vide" % id)
	if battle_sheet == null:
		problems.append("espèce %s : planche de sprites manquante" % id)
	return problems
