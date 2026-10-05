class_name Nature
extends RefCounted
## Natures (génération 3 et suivantes) : chacune augmente une statistique de 10 % et
## en baisse une autre de 10 %, sauf les cinq natures neutres.
## Numéro d'une nature = 5 x (statistique augmentée) + (statistique baissée), dans
## l'ordre Attaque, Défense, Vitesse, Attaque Spé., Défense Spé. (ordre officiel).

const COUNT := 25
const NAMES := [
	"Hardi", "Solo", "Brave", "Rigide", "Mauvais",
	"Assuré", "Docile", "Relax", "Malin", "Lâche",
	"Timide", "Pressé", "Sérieux", "Jovial", "Naïf",
	"Modeste", "Doux", "Discret", "Pudique", "Foufou",
	"Calme", "Gentil", "Malpoli", "Prudent", "Bizarre",
]
const _ORDER := [Stat.ATTACK, Stat.DEFENSE, Stat.SPEED, Stat.SP_ATTACK, Stat.SP_DEFENSE]


## Multiplicateur de la nature pour une statistique (1,1, 0,9 ou 1).
static func multiplier(nature: int, stat: int) -> float:
	if nature < 0 or nature >= COUNT:
		push_error("Nature : nature inconnue %d" % nature)
		return 1.0
	var up: int = _ORDER[nature / 5]
	var down: int = _ORDER[nature % 5]
	if up == down:
		return 1.0
	if stat == up:
		return 1.1
	if stat == down:
		return 0.9
	return 1.0


## Statistique augmentée par la nature, ou -1 (nature neutre).
static func raised(nature: int) -> int:
	if nature < 0 or nature >= COUNT or nature / 5 == nature % 5:
		return -1
	return _ORDER[nature / 5]


## Statistique baissée par la nature, ou -1 (nature neutre).
static func lowered(nature: int) -> int:
	if nature < 0 or nature >= COUNT or nature / 5 == nature % 5:
		return -1
	return _ORDER[nature % 5]


static func nature_name(nature: int) -> String:
	return NAMES[nature] if nature >= 0 and nature < COUNT else "???"
