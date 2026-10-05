class_name DamageContext
extends RefCounted
## Tout ce qui entre dans le calcul des dégâts d'une attaque. Les statuts, objets et
## talents peuvent y ajouter des multiplicateurs (add_modifier) avant le calcul final,
## sans toucher à la formule.

var rules: BattleRules
var attacker: BattlePokemon
var defender: BattlePokemon
var move: MoveData
var power := 0
var is_critical := false
## Facteur aléatoire, en pourcentage (85 à 100).
var random_percent := 100
var stab := false
var effectiveness := 1.0
## Multiplicateurs supplémentaires : nom -> valeur (&"burn" -> 0.5...).
var modifiers := {}


func add_modifier(modifier_name: StringName, value: float) -> void:
	modifiers[modifier_name] = float(modifiers.get(modifier_name, 1.0)) * value
