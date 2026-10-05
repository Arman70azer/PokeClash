extends BattleCondition
## Poison grave (Toxik) : perd n/16 de ses PV max en fin de tour, n augmentant de 1 à
## chaque tour ; n revient à 1 quand le Pokémon est rappelé.


func _init() -> void:
	name = "Poison grave"
	short_name = "PSN"
	end_turn_order = 20
	counter = 1


func can_apply(_engine: BattleEngine, target: BattlePokemon) -> bool:
	return not target.has_type(PokemonType.Type.POISON) and not target.has_type(PokemonType.Type.STEEL)


func on_end_turn(engine: BattleEngine, pokemon: BattlePokemon) -> void:
	engine.emit(&"condition_tick", {"pokemon": engine.ref(pokemon), "condition": id})
	var amount := maxi(1, pokemon.max_hp * maxi(counter, 1) / engine.rules.toxic_fraction)
	counter += 1
	engine.damage(pokemon, amount, id)


func on_switch_out(_engine: BattleEngine, _pokemon: BattlePokemon) -> void:
	counter = 1
