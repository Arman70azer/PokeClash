class_name PokemonType
extends RefCounted
## Types des Pokémon et table des efficacités, en un seul endroit.
## Table actuelle (depuis la génération 6) : 18 types, avec le type Fée ; l'Acier ne
## résiste plus au Spectre ni aux Ténèbres. Pour changer les règles, modifier
## EFFECTIVENESS (ou ajouter un type à la fin de l'énumération et à NAMES).

enum Type {
	NORMAL, FIRE, WATER, ELECTRIC, GRASS, ICE, FIGHTING, POISON, GROUND,
	FLYING, PSYCHIC, BUG, ROCK, GHOST, DRAGON, DARK, STEEL, FAIRY,
}

## Noms affichés, dans l'ordre de l'énumération.
const NAMES := [
	"Normal", "Feu", "Eau", "Électrik", "Plante", "Glace", "Combat", "Poison", "Sol",
	"Vol", "Psy", "Insecte", "Roche", "Spectre", "Dragon", "Ténèbres", "Acier", "Fée",
]

## Efficacités différentes de 1 : type de l'attaque -> {type du défenseur: multiplicateur}.
const EFFECTIVENESS := {
	Type.NORMAL: {Type.ROCK: 0.5, Type.GHOST: 0.0, Type.STEEL: 0.5},
	Type.FIRE: {Type.FIRE: 0.5, Type.WATER: 0.5, Type.GRASS: 2.0, Type.ICE: 2.0, Type.BUG: 2.0,
		Type.ROCK: 0.5, Type.DRAGON: 0.5, Type.STEEL: 2.0},
	Type.WATER: {Type.FIRE: 2.0, Type.WATER: 0.5, Type.GRASS: 0.5, Type.GROUND: 2.0, Type.ROCK: 2.0,
		Type.DRAGON: 0.5},
	Type.ELECTRIC: {Type.WATER: 2.0, Type.ELECTRIC: 0.5, Type.GRASS: 0.5, Type.GROUND: 0.0,
		Type.FLYING: 2.0, Type.DRAGON: 0.5},
	Type.GRASS: {Type.FIRE: 0.5, Type.WATER: 2.0, Type.GRASS: 0.5, Type.POISON: 0.5, Type.GROUND: 2.0,
		Type.FLYING: 0.5, Type.BUG: 0.5, Type.ROCK: 2.0, Type.DRAGON: 0.5, Type.STEEL: 0.5},
	Type.ICE: {Type.FIRE: 0.5, Type.WATER: 0.5, Type.GRASS: 2.0, Type.ICE: 0.5, Type.GROUND: 2.0,
		Type.FLYING: 2.0, Type.DRAGON: 2.0, Type.STEEL: 0.5},
	Type.FIGHTING: {Type.NORMAL: 2.0, Type.ICE: 2.0, Type.POISON: 0.5, Type.FLYING: 0.5,
		Type.PSYCHIC: 0.5, Type.BUG: 0.5, Type.ROCK: 2.0, Type.GHOST: 0.0, Type.DARK: 2.0, Type.STEEL: 2.0,
		Type.FAIRY: 0.5},
	Type.POISON: {Type.GRASS: 2.0, Type.POISON: 0.5, Type.GROUND: 0.5, Type.ROCK: 0.5, Type.GHOST: 0.5,
		Type.STEEL: 0.0, Type.FAIRY: 2.0},
	Type.GROUND: {Type.FIRE: 2.0, Type.ELECTRIC: 2.0, Type.GRASS: 0.5, Type.POISON: 2.0,
		Type.FLYING: 0.0, Type.BUG: 0.5, Type.ROCK: 2.0, Type.STEEL: 2.0},
	Type.FLYING: {Type.ELECTRIC: 0.5, Type.GRASS: 2.0, Type.FIGHTING: 2.0, Type.BUG: 2.0, Type.ROCK: 0.5,
		Type.STEEL: 0.5},
	Type.PSYCHIC: {Type.FIGHTING: 2.0, Type.POISON: 2.0, Type.PSYCHIC: 0.5, Type.DARK: 0.0,
		Type.STEEL: 0.5},
	Type.BUG: {Type.FIRE: 0.5, Type.GRASS: 2.0, Type.FIGHTING: 0.5, Type.POISON: 0.5, Type.FLYING: 0.5,
		Type.PSYCHIC: 2.0, Type.GHOST: 0.5, Type.DARK: 2.0, Type.STEEL: 0.5, Type.FAIRY: 0.5},
	Type.ROCK: {Type.FIRE: 2.0, Type.ICE: 2.0, Type.FIGHTING: 0.5, Type.GROUND: 0.5, Type.FLYING: 2.0,
		Type.BUG: 2.0, Type.STEEL: 0.5},
	Type.GHOST: {Type.NORMAL: 0.0, Type.PSYCHIC: 2.0, Type.GHOST: 2.0, Type.DARK: 0.5},
	Type.DRAGON: {Type.DRAGON: 2.0, Type.STEEL: 0.5, Type.FAIRY: 0.0},
	Type.DARK: {Type.FIGHTING: 0.5, Type.PSYCHIC: 2.0, Type.GHOST: 2.0, Type.DARK: 0.5, Type.FAIRY: 0.5},
	Type.STEEL: {Type.FIRE: 0.5, Type.WATER: 0.5, Type.ELECTRIC: 0.5, Type.ICE: 2.0, Type.ROCK: 2.0,
		Type.STEEL: 0.5, Type.FAIRY: 2.0},
	Type.FAIRY: {Type.FIRE: 0.5, Type.FIGHTING: 2.0, Type.POISON: 0.5, Type.DRAGON: 2.0, Type.DARK: 2.0,
		Type.STEEL: 0.5},
}


static func type_name(type: int) -> String:
	if type < 0 or type >= NAMES.size():
		push_error("PokemonType : type inconnu %d" % type)
		return "???"
	return NAMES[type]


## Multiplicateur d'une attaque de type `attack` contre un Pokémon de types
## `defender_types` (un ou deux types) : 0, 0,25, 0,5, 1, 2 ou 4.
static func effectiveness(attack: int, defender_types: Array) -> float:
	var row: Dictionary = EFFECTIVENESS.get(attack, {})
	var result := 1.0
	for type in defender_types:
		result *= float(row.get(type, 1.0))
	return result
