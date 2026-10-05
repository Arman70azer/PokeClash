class_name MoveEffect
extends Resource
## Effet d'une attaque, en plus de ses dégâts. Classe de base : chaque effet concret
## (baisse de statistique, statut, recul...) en hérite et redéfinit _apply().
## Pour un effet propre au fangame, créer une nouvelle sous-classe dans
## scripts/battle/effects/ et l'ajouter à la liste `effects` des attaques concernées.

enum Who {
	TARGET,  ## la cible de l'attaque
	USER,    ## le lanceur
}

## Chance de se produire, en pourcentage (100 = toujours).
@export_range(0, 100) var chance := 100
@export var who: Who = Who.TARGET


## Applique l'effet si le tirage le permet. `damage` : dégâts infligés par l'attaque
## (0 pour une attaque de statut).
func apply(engine: BattleEngine, user: BattlePokemon, target: BattlePokemon, move: MoveData, damage: int) -> void:
	var affected := user if who == Who.USER else target
	if affected == null or affected.is_fainted():
		return
	if chance < 100 and engine.rng.randi_range(1, 100) > chance:
		return
	_apply(engine, user, affected, move, damage)


## Vrai si l'effet est le cœur de l'attaque (attaque de statut) : son échec doit alors
## être annoncé (« Mais cela échoue ! »). Les effets secondaires échouent en silence.
func is_primary(move: MoveData) -> bool:
	return not move.is_damaging()


func _apply(_engine: BattleEngine, _user: BattlePokemon, _affected: BattlePokemon, _move: MoveData, _damage: int) -> void:
	push_error("%s : _apply() n'est pas défini" % get_script().resource_path)
