extends BattleCondition
## Paralysie : une chance sur quatre de ne pas pouvoir attaquer, et Vitesse divisée par
## quatre (génération 5 : le type Électrik n'est pas immunisé).


func _init() -> void:
	name = "Paralysie"
	short_name = "PAR"


func before_move(engine: BattleEngine, pokemon: BattlePokemon, _move: MoveData) -> bool:
	if engine.rng.randi_range(1, 100) <= engine.rules.paralysis_skip_chance:
		engine.emit(&"condition_blocks", {"pokemon": engine.ref(pokemon), "condition": id})
		return false
	return true


func modify_stat(stat: int, value: float, rules: BattleRules) -> float:
	return value * rules.paralysis_speed_multiplier if stat == Stat.SPEED else value
