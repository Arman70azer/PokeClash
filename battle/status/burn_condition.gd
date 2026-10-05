extends BattleCondition
## Brûlure : perd 1/8 de ses PV max en fin de tour, et ses attaques physiques font
## moitié moins de dégâts. Type Feu immunisé.


func _init() -> void:
	name = "Brûlure"
	short_name = "BRL"
	end_turn_order = 20


func can_apply(_engine: BattleEngine, target: BattlePokemon) -> bool:
	return not target.has_type(PokemonType.Type.FIRE)


func on_end_turn(engine: BattleEngine, pokemon: BattlePokemon) -> void:
	engine.emit(&"condition_tick", {"pokemon": engine.ref(pokemon), "condition": id})
	engine.damage(pokemon, BattleRules.fraction(pokemon.max_hp, engine.rules.burn_end_turn_fraction), id)


func modify_damage_dealt(context: DamageContext) -> void:
	if context.move.category == MoveData.Category.PHYSICAL:
		context.add_modifier(&"burn", context.rules.burn_damage_multiplier)
