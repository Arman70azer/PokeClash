class_name ItemAction
extends BattleAction
## Utiliser un objet du sac sur un Pokémon de son équipe.

var item_id: StringName
var team_index := -1


func _init(p_item_id: StringName = &"", p_team_index := -1) -> void:
	kind = Kind.ITEM
	item_id = p_item_id
	team_index = p_team_index


func item(engine: BattleEngine) -> ItemData:
	var bag: Bag = engine.sides[side].bag
	return bag.find_by_id(item_id) if bag != null else null


func validate(engine: BattleEngine) -> String:
	var battle_side: BattleSide = engine.sides[side]
	var found := item(engine)
	if found == null or battle_side.bag.count(found) <= 0:
		return "Tu n'as pas cet objet."
	if not found.usable_in_battle:
		return "Cet objet ne s'utilise pas en combat."
	if found is BallItem:
		if battle_side.balls_left == 0:
			return "Tu as lancé toutes les Poké Balls permises ici."
		return found.can_use_on(engine, null)
	if team_index < 0 or team_index >= battle_side.team.size():
		return "Pokémon inconnu."
	return found.can_use_on(engine, battle_side.team[team_index])


func execute(engine: BattleEngine) -> void:
	engine.use_item(side, item(engine), team_index)


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["item"] = String(item_id)
	data["team_index"] = team_index
	return data
