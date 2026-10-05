class_name MoveData
extends Resource
## Une attaque, décrite comme une donnée : un fichier .tres par attaque dans data/moves.
## Ce qu'elle fait en plus des dégâts (baisse de statistique, statut, recul...) est une
## liste d'effets (MoveEffect) : une nouvelle attaque se crée en général sans code.

enum Category {PHYSICAL, SPECIAL, STATUS}
enum Target {
	OPPONENT,  ## le Pokémon adverse
	USER,      ## le lanceur lui-même
}

const CATEGORY_NAMES := ["Physique", "Spéciale", "Statut"]

## Identifiant unique, utilisé dans les sauvegardes et le réseau.
@export var id: StringName
@export var name := ""
@export var type: PokemonType.Type = PokemonType.Type.NORMAL
@export var category: Category = Category.PHYSICAL
## Puissance (0 pour une attaque de statut).
@export var power := 0
## Précision en pourcentage ; 0 = ne rate jamais.
@export_range(0, 100) var accuracy := 100
@export var pp := 35
## Priorité : les attaques de priorité plus haute passent avant, quelle que soit la Vitesse.
@export_range(-7, 5) var priority := 0
@export var target: Target = Target.OPPONENT
## Taux de coups critiques augmenté (0 = normal, 1 = Tranche, Pince-Masse...).
@export_range(0, 4) var critical_stage := 0
## Attaque de contact (pour des talents ou objets plus tard).
@export var makes_contact := false
@export var effects: Array[MoveEffect] = []
@export_group("Présentation")
## Animation jouée par la scène de combat (nom libre, voir BattlePresenter).
@export var animation: StringName
@export var sound: AudioStream
@export_multiline var description := ""


func is_damaging() -> bool:
	return category != Category.STATUS


## Vérifie la cohérence de la donnée ; renvoie la liste des problèmes trouvés.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id.is_empty():
		problems.append("attaque sans id (%s)" % resource_path)
	if name.is_empty():
		problems.append("attaque %s sans nom" % id)
	if is_damaging() and power <= 0:
		problems.append("attaque %s : offensive mais sans puissance" % id)
	if pp <= 0:
		problems.append("attaque %s : PP nuls" % id)
	for effect in effects:
		if effect == null:
			problems.append("attaque %s : effet vide dans la liste" % id)
	return problems
