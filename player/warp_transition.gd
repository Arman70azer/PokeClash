class_name WarpTransition
extends RefCounted
## Animation d'un passage de porte (voir Warp).
## Pour le joueur de cet ordinateur : la porte s'ouvre, il avance d'un pas, l'écran passe
## au noir, la carte d'arrivée s'affiche, il apparaît (porte d'arrivée ouverte puis
## refermée) et l'écran revient. Chez les autres, il disparaît le temps du passage.

## Durée d'un passage vu par les autres joueurs.
const REMOTE_TIME := 1.0
const STEP_TIME := Player.MOVE_TIME * 1.4


static func play(player: Player, warp: Warp, destination: StringName, target_cell: Vector2i,
		target_facing: Vector2i, dir: Vector2i) -> void:
	var world := player.world
	var fade := Game.fade
	var local := player.is_local() and fade != null
	player.idle_frame()
	if local:
		var door := warp.source() if warp != null else null
		if door != null:
			await door.open()
		player.step_frame()
		var step := player.create_tween()
		step.tween_method(player._set_position, player.position,
			player.position + Vector3(dir.x, 0, dir.y) * GameConfig.TILE, STEP_TIME)
		await fade.fade_out()
		if door != null:
			door.close()
	else:
		player.visible = false
		await player.get_tree().create_timer(REMOTE_TIME).timeout
	player.map_id = destination
	if local:
		world.show_map(destination)
		player.confirm_map_loaded()
	player.place(destination, target_cell, target_facing)
	if local:
		var arrival_map := world.map(destination)
		var arrival: Door = arrival_map.door(warp.target_door) if arrival_map != null and warp != null else null
		if arrival != null:
			arrival.set_open()
		await fade.fade_in()
		if arrival != null:
			await arrival.close()
