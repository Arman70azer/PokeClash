class_name BattleAction
extends RefCounted
## Une action choisie pour un tour : attaque, changement, objet ou fuite. Le joueur et
## l'IA produisent les mêmes actions ; le moteur les ordonne puis appelle execute().
## Les actions voyagent sur le réseau sous forme de dictionnaire (to_dict / from_dict).

enum Kind {MOVE, SWITCH, ITEM, RUN}

## Tranches d'ordre (génération 5) : fuite, puis changements, puis objets, puis attaques.
const BRACKETS := {Kind.RUN: 3, Kind.SWITCH: 2, Kind.ITEM: 1, Kind.MOVE: 0}

var kind: Kind = Kind.MOVE
var side := 0


func bracket() -> int:
	return BRACKETS[kind]


## Priorité à l'intérieur de la tranche (priorité de l'attaque).
func priority(_engine: BattleEngine) -> int:
	return 0


## Vide si l'action est permise, sinon la raison (affichable).
func validate(_engine: BattleEngine) -> String:
	return ""


func execute(_engine: BattleEngine) -> void:
	push_error("BattleAction : execute() non défini pour %s" % Kind.keys()[kind])


func to_dict() -> Dictionary:
	return {"kind": kind, "side": side}


static func from_dict(data: Dictionary) -> BattleAction:
	var action: BattleAction
	match int(data.get("kind", -1)):
		Kind.MOVE:
			action = MoveAction.new(int(data.get("move_index", 0)))
		Kind.SWITCH:
			action = SwitchAction.new(int(data.get("team_index", -1)))
		Kind.ITEM:
			action = ItemAction.new(StringName(data.get("item", "")), int(data.get("team_index", -1)))
		Kind.RUN:
			action = RunAction.new()
		_:
			push_error("BattleAction.from_dict : action inconnue %s" % data)
			return null
	action.side = int(data.get("side", 0))
	return action
