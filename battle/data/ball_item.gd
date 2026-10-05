class_name BallItem
extends ItemData
## Poké Ball et ses variantes : se lance sur un Pokémon sauvage pour le capturer (voir
## BattleEngine.throw_ball). Ne se lance pas sur le Pokémon d'un dresseur.

## Multiplicateur du taux de capture (Poké Ball 1, Super Ball 1,5, Hyper Ball 2...).
@export var catch_modifier := 1.0


func can_use_on(engine: BattleEngine, _target: BattlePokemon) -> String:
	if not engine.is_wild:
		return "On ne peut pas capturer le Pokémon d'un Dresseur !"
	return ""
