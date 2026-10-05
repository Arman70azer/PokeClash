class_name BattleConditions
extends RefCounted
## Registre des effets durables : identifiant -> script. Pour ajouter un statut, écrire
## sa classe (voir BattleCondition) et l'inscrire ici.

const SCRIPTS := {
	&"poison": preload("res://battle/status/poison_condition.gd"),
	&"toxic": preload("res://battle/status/toxic_condition.gd"),
	&"burn": preload("res://battle/status/burn_condition.gd"),
	&"paralysis": preload("res://battle/status/paralysis_condition.gd"),
	&"sleep": preload("res://battle/status/sleep_condition.gd"),
	&"freeze": preload("res://battle/status/freeze_condition.gd"),
	&"leech_seed": preload("res://battle/status/leech_seed_condition.gd"),
}


static func exists(id: StringName) -> bool:
	return SCRIPTS.has(id)


## Crée un effet ; null (avec une erreur) si l'identifiant est inconnu.
static func create(id: StringName) -> BattleCondition:
	if not SCRIPTS.has(id):
		push_error("BattleConditions : effet inconnu « %s »" % id)
		return null
	var condition: BattleCondition = SCRIPTS[id].new()
	condition.id = id
	return condition
