extends BattleAI
## IA de dresseur : préfère l'attaque qui fera le plus de dégâts (puissance, efficacité
## du type, bonus de même type, précision), et utilise de temps en temps une attaque de
## statut tant qu'elle peut encore servir.

## Chance (%) de jouer une attaque au hasard au lieu de la meilleure, pour rester
## imprévisible.
const RANDOM_CHANCE := 15
## Valeur d'une attaque de statut encore utile, comparée aux dégâts estimés.
const STATUS_MOVE_SCORE := 25.0


func _choose_move(engine: BattleEngine, side: BattleSide) -> int:
	var user := side.active()
	var usable := user.usable_moves()
	if usable.is_empty():
		return MoveAction.STRUGGLE
	if engine.rng.randi_range(1, 100) <= RANDOM_CHANCE:
		return usable[engine.rng.randi_range(0, usable.size() - 1)]
	var target := engine.opponent_active(user)
	var best := usable[0]
	var best_score := -1.0
	for index in usable:
		var score := _score(engine, user, target, user.moves[index])
		if score > best_score:
			best_score = score
			best = index
	return best


func _score(engine: BattleEngine, user: BattlePokemon, target: BattlePokemon, move: MoveData) -> float:
	if target == null:
		return 0.0
	var accuracy := 1.0 if move.accuracy == 0 else move.accuracy / 100.0
	if move.is_damaging():
		var score := float(move.power) * PokemonType.effectiveness(move.type, target.types) * accuracy
		if user.has_type(move.type):
			score *= engine.rules.stab_multiplier
		return score
	return STATUS_MOVE_SCORE * accuracy if _status_move_useful(user, target, move) else 0.0


## Une attaque de statut n'a d'intérêt que si au moins un de ses effets peut encore agir.
func _status_move_useful(user: BattlePokemon, target: BattlePokemon, move: MoveData) -> bool:
	for effect in move.effects:
		var affected := user if effect.who == MoveEffect.Who.USER else target
		if effect is StatStageEffect:
			var stage: int = affected.stages.get(effect.stat, 0)
			if (effect.stages < 0 and stage > -2) or (effect.stages > 0 and stage < 2):
				return true
		elif effect is InflictConditionEffect:
			var condition := BattleConditions.create(effect.condition)
			if condition == null:
				continue
			if condition.is_major and affected.status == null:
				return true
			if not condition.is_major and not affected.has_volatile(condition.id):
				return true
		else:
			return true
	return false
