class_name BattleScreen
extends Control
## Écran de combat du joueur de cet ordinateur. Il ne calcule rien : il joue les
## évènements envoyés par l'hôte (messages, animations, barres de PV), puis propose les
## choix (commandes, attaques, équipe, sac) et renvoie l'action choisie.
##
## Entrée : l'écran clignote, des bandes noires le couvrent, puis s'ouvrent sur le
## terrain où glissent les dresseurs. Sortie : même fondu, puis retour au monde.
## États : INTRO, PLAYING (évènements en cours), CHOOSING (un menu est ouvert), WAITING
## (action envoyée, en attente du tour suivant), OUTRO, CLOSED.

signal action_chosen(action: Dictionary)
signal replacement_chosen(team_index: int)
signal closed(outcome: int)

enum State {CLOSED, INTRO, PLAYING, CHOOSING, WAITING, OUTRO}

const PLAYER_BOX := Vector2(226, 150)
const OPPONENT_BOX := Vector2(4, 8)

var state: State = State.CLOSED
## Camp du joueur dans le combat (toujours 0 pour l'instant : un combat par joueur).
var own_side := 0

var _snapshot := {}
var _queue: Array = []  # lots [snapshot, évènements] reçus, joués dans l'ordre
var _ended := false
var _outcome := 0
var _field: BattleField
var _boxes: Array[BattleInfoBox] = []
var _messages: BattleMessageBox
var _commands: BattleCommandMenu
var _moves: BattleMenu
var _move_info: Control
var _move_info_label: Label
var _move_info_type := 0
var _party: BattleMenu
var _bag: BattleMenu
var _transition: BattleTransition
var _pending_item := ""
var _move_reminder: MoveReminderDialog
var _awaiting_move_replacement := {"pokemon": null, "new_move": null}


func _enter_tree() -> void:
	Game.register(&"battle_screen", self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameFont.get_theme()
	visible = false
	_field = BattleField.new()
	add_child(_field)
	for side in 2:
		var box := BattleInfoBox.new()
		box.is_player = side == own_side
		box.visible = false
		add_child(box)
		_boxes.append(box)
	_messages = BattleMessageBox.new()
	_messages.position = Vector2(0, 200)
	_messages.size = Vector2(352, 64)
	add_child(_messages)
	_commands = BattleCommandMenu.new()
	_commands.position = Vector2(0, 196)
	_commands.visible = false
	_commands.chosen.connect(_on_command)
	add_child(_commands)
	_moves = _make_menu(Vector2(0, 200), Vector2(256, 64))
	_moves.cell_height = 26.0
	_moves.chosen.connect(_on_move)
	_moves.cancelled.connect(_show_commands)
	_moves.hovered.connect(_on_move_hovered)
	_move_info = Control.new()
	_move_info.position = Vector2(256, 202)
	_move_info.size = Vector2(94, 60)
	_move_info.visible = false
	_move_info.draw.connect(_draw_move_info)
	add_child(_move_info)
	_move_info_label = Label.new()
	_move_info_label.position = Vector2(8, 6)
	_move_info.add_child(_move_info_label)
	_party = _make_menu(Vector2(20, 14), Vector2(312, 180))
	_party.cell_height = 30.0
	_party.fit_to_content = true
	_party.chosen.connect(_on_party_chosen)
	_party.cancelled.connect(_on_party_cancelled)
	_bag = _make_menu(Vector2(20, 14), Vector2(312, 180))
	_bag.fit_to_content = true
	_bag.chosen.connect(_on_bag_chosen)
	_bag.cancelled.connect(_show_commands)
	_transition = BattleTransition.new()
	add_child(_transition)
	_move_reminder = MoveReminderDialog.new()
	_move_reminder.move_selected.connect(_on_move_to_forget_selected)
	_move_reminder.cancelled.connect(_on_move_replacement_cancelled)
	add_child(_move_reminder)


func is_open() -> bool:
	return state != State.CLOSED


## Ouvre l'écran au début d'un combat. `opponent_trainer` : dresseur adverse (null pour
## un Pokémon sauvage).
func open(snapshot: Dictionary, events: Array, opponent_trainer: TrainerData) -> void:
	_queue.clear()
	_ended = false
	_snapshot = snapshot
	_queue.append([snapshot, events])
	state = State.INTRO
	visible = true
	_set_scene_visible(false)
	await _transition.cover()
	_field.reset(BattleSprites.player_back(), BattleSprites.trainer(opponent_trainer))
	_set_scene_visible(true)
	for box in _boxes:
		box.visible = false
	_messages.show_prompt("")
	_transition.reveal()
	await _field.slide_in()
	_play_queue()


## Reçoit de l'hôte la suite du combat : évènements à jouer, puis état à jour.
func receive(snapshot: Dictionary, events: Array) -> void:
	_queue.append([snapshot, events])
	if state == State.CHOOSING or state == State.WAITING:
		_play_queue()


## Ferme l'écran sans attendre (session quittée...).
func force_close() -> void:
	_queue.clear()
	_hide_menus()
	visible = false
	state = State.CLOSED


func _play_queue() -> void:
	state = State.PLAYING
	_hide_menus()
	while not _queue.is_empty():
		var batch: Array = _queue[0]
		for event in batch[1]:
			if state == State.CLOSED:
				return
			await _play_event(event)
		_snapshot = batch[0]
		_queue.pop_front()
	_after_events()


func _after_events() -> void:
	if _ended:
		_close_with_transition()
	elif _snapshot.get("needs_replacement", false):
		_open_party(true)
	elif _snapshot.get("needs_action", false):
		_show_commands()
	else:
		state = State.WAITING
		_messages.show_prompt("…")


func _close_with_transition() -> void:
	state = State.OUTRO
	_hide_menus()
	await _transition.cover()
	_set_scene_visible(false)
	await _transition.reveal()
	visible = false
	state = State.CLOSED
	closed.emit(_outcome)


func _set_scene_visible(shown: bool) -> void:
	_field.visible = shown
	_messages.visible = shown
	for box in _boxes:
		box.visible = box.visible and shown


# --- Évènements ------------------------------------------------------------------------

func _play_event(event: Dictionary) -> void:
	var texts := BattleText.messages(event, own_side, _side_names())
	match event["type"]:
		&"send_out":
			await _say(texts)
			var side: int = event["pokemon"]["side"]
			var info: Dictionary = event["info"]
			await _field.send_out(side, load(info["species"]), info.get("wild", false))
			_boxes[side].set_pokemon(info)
			await _boxes[side].slide_in(PLAYER_BOX if side == own_side else OPPONENT_BOX)
		&"withdraw":
			await _say(texts)
			await _field.withdraw(event["pokemon"]["side"])
			_boxes[event["pokemon"]["side"]].visible = false
		&"move_used":
			await _say(texts)
			var strong: bool = event.get("category", 0) == MoveData.Category.PHYSICAL and event.get("contact", false)
			await _field.attack(event["pokemon"]["side"], StringName(event.get("animation", "")), strong)
		&"hit":
			await _field.hit(event["target"]["side"])
		&"hp_change":
			var side: int = event["pokemon"]["side"]
			match event.get("cause", &""):
				&"heal":
					await _field.heal(side)
				&"leech_seed":
					_field.drain(side)
			await _boxes[side].animate_hp(event["hp"], event["max_hp"])
			await _say(texts)
		&"stat_change":
			await _field.stat_change(event["pokemon"]["side"], event["delta"] > 0)
			await _say(texts)
		&"condition_applied":
			var side: int = event["pokemon"]["side"]
			if not String(event.get("short", "")).is_empty():
				_boxes[side].set_status(event["short"])
			await _field.condition(side, event["condition"])
			await _say(texts)
		&"condition_tick", &"condition_blocks":
			await _say(texts)
			await _field.condition(event["pokemon"]["side"], event["condition"])
		&"condition_cured":
			_boxes[event["pokemon"]["side"]].set_status("")
			await _say(texts)
		&"faint":
			await _field.faint(event["pokemon"]["side"])
			_boxes[event["pokemon"]["side"]].visible = false
			await _say(texts)
		&"exp_gain":
			await _say(texts)
			await _boxes[event["pokemon"]["side"]].animate_exp(event["exp_ratio"], event.get("levels", 0))
		&"level_up":
			_boxes[event["pokemon"]["side"]].set_level(event["level"], event["hp"], event["max_hp"])
			await _say(texts)
		&"ball_thrown":
			await _say(texts)
			await _field.capture(event["shakes"], event["caught"])
			if not event["caught"]:
				var escaped := event.duplicate()
				escaped["type"] = &"ball_escaped"
				await _say(BattleText.messages(escaped, own_side, _side_names()))
		&"evolution":
			await _say(texts)
			await _field.evolve(load(event["from"]), load(event["to"]))
		&"move_needs_replacement":
			await _say(texts)
			await _handle_move_replacement(event)
		&"battle_end":
			_ended = true
			_outcome = event["outcome"]
		_:
			await _say(texts)


func _say(texts: PackedStringArray) -> void:
	for text in texts:
		await _messages.show_message(text)


func _side_names() -> Array:
	var names := []
	for side in _snapshot.get("sides", []):
		names.append(side["name"])
	return names


func _own() -> Dictionary:
	return _snapshot["sides"][own_side]


func _active_info() -> Dictionary:
	var own := _own()
	return own["team"][own["active"]]


# --- Choix -----------------------------------------------------------------------------

func _show_commands() -> void:
	state = State.CHOOSING
	_hide_menus()
	_messages.show_prompt("Que doit faire\n%s ?" % _active_info()["name"])
	_commands.visible = true


func _on_command(index: int) -> void:
	match index:
		0:
			var moves: Array = _active_info()["moves"]
			if moves.filter(func(m: Dictionary) -> bool: return m["pp"] > 0).is_empty():
				_send({"kind": BattleAction.Kind.MOVE, "move_index": MoveAction.STRUGGLE})
				return
			var names := PackedStringArray()
			var enabled: Array[bool] = []
			var colors: Array[Color] = []
			for m in moves:
				names.append(m["name"])
				enabled.append(m["pp"] > 0)
				colors.append(BattleStyle.type_color(m["type"]))
			_hide_menus()
			_moves.set_entries(names, 2, enabled, colors)
			_moves.visible = true
			_move_info.visible = true
		1:
			var items: Array = _snapshot.get("bag", [])
			if items.is_empty():
				_hide_menus()
				await _messages.show_message("Le sac ne contient rien d'utile en combat.")
				_show_commands()
				return
			var names := PackedStringArray()
			var details := PackedStringArray()
			for item in items:
				names.append(item["name"])
				details.append("x%d" % item["count"])
			_hide_menus()
			_bag.set_entries(names, 1, [], [], details)
			_bag.visible = true
			_messages.show_prompt("Quel objet utiliser ?")
		2:
			_open_party(false)
		3:
			if not _snapshot.get("can_run", false):
				_hide_menus()
				await _messages.show_message("On ne s'enfuit pas d'un combat de Dresseurs !")
				_show_commands()
				return
			_send({"kind": BattleAction.Kind.RUN})


func _on_move(index: int) -> void:
	_send({"kind": BattleAction.Kind.MOVE, "move_index": index})


func _on_move_hovered(index: int) -> void:
	var moves: Array = _active_info()["moves"]
	if index < 0 or index >= moves.size():
		return
	var m: Dictionary = moves[index]
	_move_info_type = m["type"]
	_move_info_label.text = "PP %d/%d\n%s" % [m["pp"], m["max_pp"], PokemonType.type_name(m["type"])]
	_move_info.queue_redraw()


func _draw_move_info() -> void:
	var rect := Rect2(Vector2.ZERO, _move_info.size)
	BattleStyle.draw_panel(_move_info, rect, BattleStyle.PANEL, 0.0, false)
	# Bande de la couleur du type sous le nom du type.
	_move_info.draw_rect(Rect2(6, 38, rect.size.x - 12, 3), BattleStyle.type_color(_move_info_type))


## Menu de l'équipe : changer de Pokémon, choisir la cible d'un objet, ou remplacer
## un Pokémon K.O. (`forced` : impossible d'annuler).
func _open_party(forced: bool) -> void:
	state = State.CHOOSING
	_hide_menus()
	var names := PackedStringArray()
	var details := PackedStringArray()
	var colors: Array[Color] = []
	for info in _own()["team"]:
		names.append("%s  N.%d" % [info["name"], info["level"]])
		details.append("K.O." if info["hp"] <= 0 else "%d/%d PV" % [info["hp"], info["max_hp"]])
		var ratio := float(info["hp"]) / maxf(1.0, float(info["max_hp"]))
		colors.append(BattleStyle.hp_color(ratio).lerp(BattleStyle.PANEL, 0.55) if info["hp"] > 0 else Color(0.62, 0.6, 0.6))
	_party.can_cancel = not forced
	_party.set_entries(names, 1, [], colors, details)
	_party.visible = true
	if forced:
		_messages.show_prompt("Quel Pokémon envoyer ?")
	elif _pending_item.is_empty():
		_messages.show_prompt("Quel Pokémon envoyer au combat ?")
	else:
		_messages.show_prompt("Sur quel Pokémon ?")


func _on_party_chosen(index: int) -> void:
	var info: Dictionary = _own()["team"][index]
	if not _pending_item.is_empty():
		var item := _pending_item
		_pending_item = ""
		_send({"kind": BattleAction.Kind.ITEM, "item": item, "team_index": index})
		return
	if info["hp"] <= 0:
		_messages.show_prompt("%s n'a plus la force de se battre !" % info["name"])
		return
	if index == _own()["active"] and not _snapshot.get("needs_replacement", false):
		_messages.show_prompt("%s est déjà au combat !" % info["name"])
		return
	if _snapshot.get("needs_replacement", false):
		_hide_menus()
		state = State.WAITING
		replacement_chosen.emit(index)
	else:
		_send({"kind": BattleAction.Kind.SWITCH, "team_index": index})


func _on_party_cancelled() -> void:
	_pending_item = ""
	_show_commands()


func _on_bag_chosen(index: int) -> void:
	var item: Dictionary = _snapshot["bag"][index]
	# Une Ball se lance sur le Pokémon d'en face : pas de Pokémon à choisir.
	if item.get("ball", false):
		_send({"kind": BattleAction.Kind.ITEM, "item": item["id"], "team_index": -1})
		return
	_pending_item = item["id"]
	_open_party(false)


func _send(action: Dictionary) -> void:
	action["side"] = own_side
	_hide_menus()
	state = State.WAITING
	_messages.show_prompt("…")
	action_chosen.emit(action)


func _hide_menus() -> void:
	for menu in [_commands, _moves, _move_info, _party, _bag]:
		if menu != null:
			menu.visible = false


func _make_menu(pos: Vector2, menu_size: Vector2) -> BattleMenu:
	var menu := BattleMenu.new()
	menu.position = pos
	menu.size = menu_size
	menu.visible = false
	add_child(menu)
	return menu


func _handle_move_replacement(event: Dictionary) -> void:
	var battle_pokemon_ref = event.get("pokemon")
	var battle_pokemon = battle_pokemon_ref.get_ref() if battle_pokemon_ref is WeakRef else null

	if battle_pokemon == null or not battle_pokemon.has_method("source"):
		push_error("BattleScreen : Donnees Pokemon invalides")
		return

	var source = battle_pokemon.source
	var new_move = event.get("new_move")

	if source == null or new_move == null:
		return

	_awaiting_move_replacement = {"pokemon": source, "new_move": new_move}
	_move_reminder.show_for_pokemon(source, new_move)
	await _move_reminder.move_selected


func _on_move_to_forget_selected(index: int) -> void:
	var pokemon = _awaiting_move_replacement["pokemon"]
	var new_move = _awaiting_move_replacement["new_move"]

	if pokemon != null and new_move != null:
		pokemon.learn_move_with_replacement(new_move, index)
		_move_reminder.hide()


func _on_move_replacement_cancelled() -> void:
	_awaiting_move_replacement = {"pokemon": null, "new_move": null}
	_move_reminder.hide()
