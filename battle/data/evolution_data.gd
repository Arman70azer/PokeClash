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
## Bonheur à atteindre (méthode HAPPINESS ; 0 : PokemonInstance.EVOLUTION_HAPPINESS).
@export var min_happiness := 0
## Moment de la journée exigé : &"day", &"night", ou vide (à toute heure).
@export var time_of_day: StringName

## Heures de jour (heure locale de l'ordinateur de l'hôte), comme sur DS : de 4 h à 19 h 59.
const DAY_START_HOUR := 4
const NIGHT_START_HOUR := 20


func species() -> PokemonSpecies:
	return PokemonSpecies.find(species_id)


## Vrai si le moment de la journée convient à cette évolution (`hour` : 0 à 23).
func fits_time(hour: int) -> bool:
	match time_of_day:
		&"day":
			return hour >= DAY_START_HOUR and hour < NIGHT_START_HOUR
		&"night":
			return hour < DAY_START_HOUR or hour >= NIGHT_START_HOUR
	return true


## Heure locale actuelle (0 à 23).
static func current_hour() -> int:
	return int(Time.get_time_dict_from_system()["hour"])
