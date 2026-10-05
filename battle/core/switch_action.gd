class_name SwitchAction
extends BattleAction
## Rappeler le Pokémon actif et en envoyer un autre de l'équipe.

var team_index := -1


func _init(p_team_index := -1) -> void:
	kind = Kind.SWITCH
	team_index = p_team_index


func validate(engine: BattleEngine) -> String:
	var battle_side: BattleSide = engine.sides[side]
	if team_index < 0 or team_index >= battle_side.team.size():
		return "Pokémon inconnu."
	if team_index == battle_side.active_index:
		return "%s est déjà au combat !" % battle_side.team[team_index].name
	if battle_side.team[team_index].is_fainted():
		return "%s n'a plus la force de se battre !" % battle_side.team[team_index].name
	return ""


func execute(engine: BattleEngine) -> void:
	engine.switch_pokemon(side, team_index)


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["team_index"] = team_index
	return data
