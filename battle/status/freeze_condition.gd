extends BattleCondition
## Gel : ne peut pas attaquer ; une chance sur cinq de dégeler à chaque tour, et dégèle
## aussitôt s'il est touché par une attaque Feu. Type Glace immunisé.


func _init() -> void:
	name = "Gel"
	short_name = "GEL"


func can_apply(_engine: BattleEngine, target: BattlePokemon) -> bool:
	return not target.has_type(PokemonType.Type.ICE)


func before_move(engine: BattleEngine, pokemon: BattlePokemon, _move: MoveData) -> bool:
	if engine.rng.randi_range(1, 100) <= engine.rules.thaw_chance:
		engine.cure_status(pokemon, &"thaw")
		return true
	engine.emit(&"condition_blocks", {"pokemon": engine.ref(pokemon), "condition": id})
	return false


func on_hit(engine: BattleEngine, pokemon: BattlePokemon, move: MoveData) -> void:
	if move.type == PokemonType.Type.FIRE and move.is_damaging():
		engine.cure_status(pokemon, &"thaw")
