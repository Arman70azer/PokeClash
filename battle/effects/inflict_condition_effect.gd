class_name InflictConditionEffect
extends MoveEffect
## Inflige un statut ou un effet volatil (Flammèche : 10 % de brûlure ; Vampigraine...).

## Identifiant de l'effet (voir BattleConditions) : &"burn", &"leech_seed"...
@export var condition: StringName = &"burn"


func _apply(engine: BattleEngine, _user: BattlePokemon, affected: BattlePokemon, move: MoveData, _damage: int) -> void:
	engine.apply_condition(affected, condition, is_primary(move))
