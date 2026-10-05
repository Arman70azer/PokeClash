extends BattleCondition
## Sommeil : ne peut pas attaquer pendant 1 à 3 tours (counter = tours restants). Le
## Pokémon se réveille au début de son action et attaque dans le même tour.

## Durée tirée au début, rétablie quand le Pokémon est rappelé (génération 5).
var duration := 0


func _init() -> void:
	name = "Sommeil"
	short_name = "SOM"


func on_apply(engine: BattleEngine, _target: BattlePokemon) -> void:
	duration = engine.rules.sleep_turns(engine.rng)
	counter = duration


func before_move(engine: BattleEngine, pokemon: BattlePokemon, _move: MoveData) -> bool:
	counter -= 1
	if counter <= 0:
		engine.cure_status(pokemon, &"wake_up")
		return true
	engine.emit(&"condition_blocks", {"pokemon": engine.ref(pokemon), "condition": id})
	return false


func on_switch_out(_engine: BattleEngine, _pokemon: BattlePokemon) -> void:
	if duration > 0:
		counter = duration
