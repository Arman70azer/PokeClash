class_name ExpeditionGuard
extends Npc
## Le gardien du passage vers les zones d'expédition, en haut à gauche d'Accumula : il
## bouche le passage ; en lui parlant, on choisit une zone (ou on rejoint l'expédition en
## cours) dans l'écran d'expédition.


func dialogue_lines(_player: Player) -> PackedStringArray:
	var expeditions := Game.expeditions
	if expeditions != null and expeditions.is_running():
		return PackedStringArray(["Une expédition est en cours : %s." % expeditions.biome().name,
			"Je peux t'y emmener pour rejoindre les autres."])
	return lines


func on_interact_finished(_player: Player) -> void:
	if Game.expedition_screen != null:
		Game.expedition_screen.open()
