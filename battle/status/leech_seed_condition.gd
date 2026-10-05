extends BattleCondition
## Vampigraine (effet volatil) : en fin de tour, le Pokémon perd 1/8 de ses PV max, qui
## soignent le Pokémon adverse en face. Type Plante immunisé.


func _init() -> void:
	name = "Vampigraine"
	is_major = false
	persists_after_battle = false
	end_turn_order = 10


func can_apply(_engine: BattleEngine, target: BattlePokemon) -> bool:
	return not target.has_type(PokemonType.Type.GRASS)


func on_end_turn(engine: BattleEngine, pokemon: BattlePokemon) -> void:
	var drained := mini(pokemon.hp, BattleRules.fraction(pokemon.max_hp, engine.rules.leech_seed_fraction))
	engine.emit(&"condition_tick", {"pokemon": engine.ref(pokemon), "condition": id})
	engine.damage(pokemon, drained, id)
	var receiver := engine.opponent_active(pokemon)
	if receiver != null and not receiver.is_fainted():
		engine.heal(receiver, drained)
