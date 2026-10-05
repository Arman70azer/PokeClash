class_name ActionOrder
extends RefCounted
## Ordre d'exécution des actions d'un tour : tranche (fuite, changement, objet, attaque),
## puis priorité de l'attaque, puis Vitesse ; égalité tranchée au hasard.


static func sort(actions: Array[BattleAction], engine: BattleEngine) -> Array[BattleAction]:
	var keyed := []
	for action in actions:
		var user: BattlePokemon = engine.sides[action.side].active()
		var speed := user.effective_stat(Stat.SPEED, engine.rules) if user != null else 0
		keyed.append([action.bracket(), action.priority(engine), speed, engine.rng.randf(), action])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		for i in 4:
			if a[i] != b[i]:
				return a[i] > b[i]
		return false)
	var ordered: Array[BattleAction] = []
	for entry in keyed:
		ordered.append(entry[4])
	return ordered
