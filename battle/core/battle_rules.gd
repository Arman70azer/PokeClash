class_name BattleRules
extends RefCounted
## Règles chiffrées du combat, réunies ici : formules des statistiques, niveaux de
## statistiques, coups critiques, précision, durées et dégâts des statuts.
## Valeurs de la génération 5 (Noir et Blanc). Pour d'autres règles, créer une
## sous-classe et la passer au BattleEngine.

static var _default: BattleRules

## Multiplicateur des coups critiques.
var critical_multiplier := 2.0
## Chance de coup critique selon le taux (0 à 4) : 1 / valeur.
var critical_chance := [16, 8, 4, 3, 2]
## Bonus de même type (STAB).
var stab_multiplier := 1.5
## Facteur aléatoire des dégâts, en pourcentage.
var damage_random_min := 85
var damage_random_max := 100
var stage_min := -6
var stage_max := 6
## Brûlure : dégâts physiques divisés par deux ; perte de PV en fin de tour.
var burn_damage_multiplier := 0.5
var burn_end_turn_fraction := 8
## Poison : perte de PV en fin de tour ; Toxik : n/16, n augmentant à chaque tour.
var poison_end_turn_fraction := 8
var toxic_fraction := 16
## Paralysie : chance (%) de ne pas pouvoir attaquer, et Vitesse multipliée.
var paralysis_skip_chance := 25
var paralysis_speed_multiplier := 0.25
## Sommeil : nombre de tours tiré entre ces bornes (inclus).
var sleep_turns_min := 1
var sleep_turns_max := 3
## Gel : chance (%) de dégeler au début de chaque tour.
var thaw_chance := 20
## Vampigraine : fraction des PV max drainée en fin de tour.
var leech_seed_fraction := 8
## Lutte (plus de PP) : recul en fraction des PV max.
var struggle_recoil_fraction := 4


static func default_rules() -> BattleRules:
	if _default == null:
		_default = BattleRules.new()
	return _default


## Formule des statistiques (génération 3 et suivantes).
func stat_value(stat: int, base: int, level: int, iv: int, ev: int, nature: int) -> int:
	var core := (2 * base + iv + ev / 4) * level / 100
	if stat == Stat.HP:
		return core + level + 10
	return int(floor((core + 5) * Nature.multiplier(nature, stat)))


## Multiplicateur d'un niveau de statistique (Attaque, Défense, Vitesse...).
func stage_multiplier(stage: int) -> float:
	stage = clampi(stage, stage_min, stage_max)
	return (2.0 + maxi(stage, 0)) / (2.0 + maxi(-stage, 0))


## Multiplicateur de précision pour (niveau de précision du lanceur - niveau
## d'esquive de la cible).
func accuracy_multiplier(stage: int) -> float:
	stage = clampi(stage, stage_min, stage_max)
	return (3.0 + maxi(stage, 0)) / (3.0 + maxi(-stage, 0))


func critical_denominator(stage: int) -> int:
	return critical_chance[clampi(stage, 0, critical_chance.size() - 1)]


func sleep_turns(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(sleep_turns_min, sleep_turns_max)


## Fraction d'une quantité, au moins 1.
static func fraction(total: int, denominator: int) -> int:
	return maxi(1, total / denominator)
