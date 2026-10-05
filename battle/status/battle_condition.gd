class_name BattleCondition
extends RefCounted
## Effet durable sur un Pokémon en combat : statut principal (poison, brûlure,
## paralysie, sommeil, gel) ou effet volatil (Vampigraine...). Classe de base : chaque
## effet en hérite et redéfinit les « crochets » dont il a besoin. Le moteur les appelle
## aux bons moments du tour, sans savoir de quel effet il s'agit.
## Pour un statut propre au fangame : nouvelle sous-classe, puis l'inscrire dans
## BattleConditions.SCRIPTS.

## Identifiant (&"poison", &"burn"...), utilisé dans les sauvegardes et le réseau.
var id: StringName
## Nom affiché.
var name := ""
## Abréviation affichée à côté des PV (« PSN »...) ; vide pour un effet volatil.
var short_name := ""
## Statut principal (un seul à la fois) ou effet volatil.
var is_major := true
## Conservé après le combat (statuts principaux) ou non (effets volatils).
var persists_after_battle := true
## Compteur libre (tours de sommeil, niveau de Toxik...).
var counter := 0
## Ordre de passage en fin de tour : les plus petits d'abord.
var end_turn_order := 100


## Faux si la cible est immunisée (selon ses types, par exemple).
func can_apply(_engine: BattleEngine, _target: BattlePokemon) -> bool:
	return true


## Appelé quand l'effet est posé. Un effet repris d'un combat précédent (statut
## conservé) n'est pas reposé : on_apply n'est appelé que pour un nouvel effet.
func on_apply(_engine: BattleEngine, _target: BattlePokemon) -> void:
	pass


## Appelé au début de chaque tour, avant les actions.
func on_turn_start(_engine: BattleEngine, _pokemon: BattlePokemon) -> void:
	pass


## Appelé avant que le Pokémon n'utilise une attaque ; faux = il ne peut pas agir.
func before_move(_engine: BattleEngine, _pokemon: BattlePokemon, _move: MoveData) -> bool:
	return true


## Appelé quand le Pokémon est touché par une attaque offensive.
func on_hit(_engine: BattleEngine, _pokemon: BattlePokemon, _move: MoveData) -> void:
	pass


## Appelé à la fin du tour (dans l'ordre de end_turn_order).
func on_end_turn(_engine: BattleEngine, _pokemon: BattlePokemon) -> void:
	pass


## Appelé quand le Pokémon est rappelé.
func on_switch_out(_engine: BattleEngine, _pokemon: BattlePokemon) -> void:
	pass


## Modifie une statistique en combat (paralysie : Vitesse...).
func modify_stat(_stat: int, value: float, _rules: BattleRules) -> float:
	return value


## Modifie les dégâts infligés par ce Pokémon (brûlure : attaques physiques...).
func modify_damage_dealt(_context: DamageContext) -> void:
	pass
