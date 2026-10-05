class_name ExpeditionTrainer
extends Npc
## Dresseur d'une zone d'expédition : il regarde droit devant lui et défie le joueur qui
## passe dans son champ de vision (voir ExpeditionService.on_player_stepped), ou qui vient
## lui parler. Une fois battu par un joueur, il ne se bat plus contre lui.

## Répliques après sa défaite.
var defeated_lines := PackedStringArray()


func dialogue_lines(_player: Player) -> PackedStringArray:
	if trainer != null and _beaten_by_local():
		return defeated_lines
	return lines


func can_battle(peer_id: int) -> bool:
	var expeditions := Game.expeditions
	return trainer != null and (expeditions == null or not expeditions.has_defeated(peer_id, trainer.name))


## Il a repéré `player` : chez l'hôte, rien d'autre à faire que lancer le combat (voir
## ExpeditionService) ; il reste tourné vers lui.
func challenge(_player: Player) -> void:
	_pause = TALK_PAUSE


func _beaten_by_local() -> bool:
	return Game.expeditions != null and Game.expeditions.has_defeated(multiplayer.get_unique_id(), trainer.name)
