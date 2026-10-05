class_name MoveAction
extends BattleAction
## Utiliser une attaque. move_index = STRUGGLE : Lutte (plus aucun PP).

const STRUGGLE := -1

var move_index := 0


func _init(p_move_index := 0) -> void:
	kind = Kind.MOVE
	move_index = p_move_index


func move(engine: BattleEngine) -> MoveData:
	var user := engine.sides[side].active()
	if move_index == STRUGGLE or user == null:
		return engine.struggle_move
	return user.moves[move_index]


func priority(engine: BattleEngine) -> int:
	return move(engine).priority


func validate(engine: BattleEngine) -> String:
	var user := engine.sides[side].active()
	if user == null or user.is_fainted():
		return "Aucun Pokémon en état de se battre."
	if move_index == STRUGGLE:
		return "" if user.usable_moves().is_empty() else "Il reste des PP."
	if move_index < 0 or move_index >= user.moves.size():
		return "Attaque inconnue."
	if user.pp[move_index] <= 0:
		return "Plus de PP pour cette capacité !"
	return ""


func execute(engine: BattleEngine) -> void:
	engine.execute_move(engine.sides[side].active(), move_index)


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["move_index"] = move_index
	return data
