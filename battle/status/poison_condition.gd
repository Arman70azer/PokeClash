extends BattleCondition
## Poison : perd 1/8 de ses PV max à chaque fin de tour. Types Poison et Acier immunisés.


func _init() -> void:
	name = "Poison"
	short_name = "PSN"
	end_turn_order = 20


func can_apply(_engine: BattleEngine, target: BattlePokemon) -> bool:
	return not target.has_type(PokemonType.Type.POISON) and not target.has_type(PokemonType.Type.STEEL)


func on_end_turn(engine: BattleEngine, pokemon: BattlePokemon) -> void:
	engine.emit(&"condition_tick", {"pokemon": engine.ref(pokemon), "condition": id})
	engine.damage(pokemon, BattleRules.fraction(pokemon.max_hp, engine.rules.poison_end_turn_fraction), id)
