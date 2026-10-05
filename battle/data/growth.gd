class_name Growth
extends RefCounted
## Courbes d'expérience (génération 5) : points d'expérience totaux nécessaires pour
## atteindre un niveau, selon la courbe de l'espèce (PokemonSpecies.growth_rate, noms de
## PokeAPI).

const MAX_LEVEL := 100


## Expérience totale au début du niveau `level`.
static func experience_for(rate: StringName, level: int) -> int:
	var n := clampi(level, 1, MAX_LEVEL)
	if n <= 1:
		return 0
	var cube := n * n * n
	match rate:
		&"fast":
			return 4 * cube / 5
		&"medium":
			return cube
		&"slow":
			return 5 * cube / 4
		&"slow-then-very-fast":  # « Erratique »
			if n <= 50:
				return cube * (100 - n) / 50
			if n <= 68:
				return cube * (150 - n) / 100
			if n <= 98:
				return cube * ((1911 - 10 * n) / 3) / 500
			return cube * (160 - n) / 100
		&"fast-then-very-slow":  # « Fluctuante »
			if n <= 15:
				return cube * ((n + 1) / 3 + 24) / 50
			if n <= 36:
				return cube * (n + 14) / 50
			return cube * (n / 2 + 32) / 50
	# medium-slow (« Parabolique »), et courbe inconnue.
	return maxi(0, 6 * cube / 5 - 15 * n * n + 100 * n - 140)


## Niveau atteint avec `experience` points.
static func level_for(rate: StringName, experience: int) -> int:
	var level := 1
	while level < MAX_LEVEL and experience >= experience_for(rate, level + 1):
		level += 1
	return level


## Expérience gagnée en battant `defeated` (formule de la génération 5). `winner_level` :
## niveau du Pokémon qui la reçoit ; `trainer` : Pokémon d'un dresseur (x1,5) ;
## `shared_by` : nombre de Pokémon qui se la partagent.
static func reward(defeated: PokemonSpecies, defeated_level: int, winner_level: int, trainer: bool, shared_by := 1) -> int:
	var base := float(defeated.base_experience) * defeated_level / (5.0 * maxi(1, shared_by))
	if trainer:
		base *= 1.5
	var scale := pow((2.0 * defeated_level + 10.0) / (defeated_level + winner_level + 10.0), 2.5)
	return int(floor(base * scale)) + 1
