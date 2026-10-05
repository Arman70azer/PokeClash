class_name Stat
extends RefCounted
## Statistiques d'un Pokémon. Les six premières sont permanentes ; Précision et
## Esquive n'existent qu'en combat, sous forme de niveaux (de -6 à +6).

enum {HP, ATTACK, DEFENSE, SP_ATTACK, SP_DEFENSE, SPEED, ACCURACY, EVASION}

## Statistiques permanentes, dans l'ordre des tableaux d'IV et d'EV.
const PERMANENT := [HP, ATTACK, DEFENSE, SP_ATTACK, SP_DEFENSE, SPEED]
## Statistiques qui ont un niveau (« stage ») en combat.
const STAGED := [ATTACK, DEFENSE, SP_ATTACK, SP_DEFENSE, SPEED, ACCURACY, EVASION]

const NAMES := ["PV", "Attaque", "Défense", "Attaque Spé.", "Défense Spé.", "Vitesse", "Précision", "Esquive"]


static func stat_name(stat: int) -> String:
	if stat < 0 or stat >= NAMES.size():
		push_error("Stat : statistique inconnue %d" % stat)
		return "???"
	return NAMES[stat]
