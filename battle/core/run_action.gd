class_name RunAction
extends BattleAction
## Tenter de fuir (combats contre des Pokémon sauvages seulement).


func _init() -> void:
	kind = Kind.RUN


func validate(engine: BattleEngine) -> String:
	if not engine.can_run:
		return "On ne s'enfuit pas d'un combat de Dresseurs !"
	return ""


func execute(engine: BattleEngine) -> void:
	engine.try_run(side)
