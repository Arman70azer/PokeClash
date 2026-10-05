class_name PlayerInteraction
extends Node
## Ce que fait le joueur de cet ordinateur avec la touche « interact » : utiliser ce qu'il
## regarde (PNJ, PC… voir Interactable), faire défiler les répliques, puis laisser l'objet
## réagir à la fin (combat, soins, boutique, PC). Enfant du nœud Player.

## Objet en cours d'utilisation : il réagit à la fin des répliques.
var _target: Interactable

@onready var player: Player = get_parent()


func _unhandled_input(event: InputEvent) -> void:
	if not player.is_local() or not event.is_action_pressed("interact"):
		return
	var battles := Game.battles
	if battles != null and battles.is_in_battle(player.peer_id):
		return
	var box := Game.dialogue
	if box == null:
		return
	if box.is_open():
		box.advance()
		if not box.is_open() and _target != null:
			var target := _target
			_target = null
			target.on_interact_finished(player)
	elif not player.moving:
		# Ce qui se trouve sur la case regardée (ou derrière un comptoir).
		var here := player.current_map()
		var target := here.interactable_facing(player.cell, player.facing) if here != null else null
		if target == null:
			return
		target.on_interact_started(player, -player.facing)
		var text := target.dialogue_lines(player)
		if text.is_empty():
			target.on_interact_finished(player)
		else:
			_target = target
			box.open(target.display_name, text)
