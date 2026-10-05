class_name EvolutionData
extends Resource
## Une évolution possible d'une espèce (Bulbizarre -> Herbizarre au niveau 16...). Rangée
## dans PokemonSpecies.evolutions ; l'espèce d'arrivée est désignée par son identifiant
## (fichier data/pokemon/<id>.tres), pour que deux espèces ne se chargent pas l'une l'autre.

## Comment l'évolution se déclenche.
enum Method {LEVEL, ITEM, TRADE, HAPPINESS, OTHER}

@export var species_id: StringName
@export var method: Method = Method.LEVEL
## Niveau à atteindre (méthode LEVEL ; 0 si la méthode n'en demande pas).
@export var min_level := 0
## Objet utilisé (méthode ITEM : identifiant PokeAPI de la pierre, &"fire-stone"...).
@export var item: StringName


func species() -> PokemonSpecies:
	return PokemonSpecies.find(species_id)
