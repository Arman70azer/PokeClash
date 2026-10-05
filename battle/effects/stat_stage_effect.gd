class_name StatStageEffect
extends MoveEffect
## Change le niveau d'une statistique (Rugissement : Attaque -1 de la cible ;
## Mimi-Queue : Défense -1 ; Danse-Lames : Attaque +2 du lanceur...).

@export_enum("Attaque:1", "Défense:2", "Attaque Spé.:3", "Défense Spé.:4", "Vitesse:5", "Précision:6", "Esquive:7")
var stat: int = Stat.ATTACK
## Niveaux gagnés (positif) ou perdus (négatif).
@export_range(-6, 6) var stages := -1


func _apply(engine: BattleEngine, _user: BattlePokemon, affected: BattlePokemon, move: MoveData, _damage: int) -> void:
	engine.change_stage(affected, stat, stages, is_primary(move))
