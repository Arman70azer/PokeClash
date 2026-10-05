class_name BattleAI
extends RefCounted
## Comportement d'un camp non joueur. Classe de base : choisit une attaque au hasard et
## envoie le premier Pokémon valide après un K.O. Les comportements plus fins
## (TrainerAI, et plus tard BossAI, ScriptedAI...) en héritent.

## Comportements disponibles : nom -> script (chargé à la demande, pour éviter que ce
## script et ses sous-classes ne se chargent mutuellement).
const SCRIPTS := {
	&"random": "res://battle/ai/battle_ai.gd",
	&"trainer": "res://battle/ai/trainer_ai.gd",
}


static func create(kind: StringName) -> BattleAI:
	if not SCRIPTS.has(kind):
		push_error("BattleAI : comportement inconnu « %s »" % kind)
		return null
	return load(SCRIPTS[kind]).new()


## Action du tour pour le camp `side`.
func choose_action(engine: BattleEngine, side: BattleSide) -> BattleAction:
	var action := MoveAction.new(_choose_move(engine, side))
	action.side = side.index
	return action


## Pokémon à envoyer après un K.O. (index dans l'équipe).
func choose_replacement(_engine: BattleEngine, side: BattleSide) -> int:
	var reserves := side.available_reserves()
	return reserves[0] if not reserves.is_empty() else -1


## Index de l'attaque choisie, ou MoveAction.STRUGGLE si plus aucun PP.
func _choose_move(engine: BattleEngine, side: BattleSide) -> int:
	var usable := side.active().usable_moves()
	if usable.is_empty():
		return MoveAction.STRUGGLE
	return usable[engine.rng.randi_range(0, usable.size() - 1)]
