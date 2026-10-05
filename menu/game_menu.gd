class_name GameMenu
extends Control
## Menu du jeu, ouvert en exploration avec « menu » (Échap, X, Start) : la liste
## (Pokémon, Sac, Sauvegarde, Quitter) à gauche, l'équipe à droite (PartyPanel), dans le
## style de l'écran de combat (DsUi). Les deux côtés glissent depuis les bords à
## l'ouverture et repartent à la fermeture.
##
## - Pokémon : on parcourt l'équipe ; valider affiche le résumé du Pokémon choisi.
## - Sac : les objets par poche ; un objet de soin ou d'évolution s'utilise sur un Pokémon
##   de l'équipe. Après une évolution, une attaque qu'il n'a pas la place d'apprendre est
##   proposée : on choisit l'attaque à oublier (ou de ne pas l'apprendre).
## - Sauvegarde : résumé de la partie, puis sauvegarde par l'hôte.
## - Quitter : quitte la session (la partie est sauvegardée par l'hôte).
## Les données affichées sont une copie envoyée par l'hôte (PlayerProfiles) ; chaque
## action est une demande à l'hôte, qui répond avec une copie à jour.

enum State { CLOSED, MAIN, PARTY, SUMMARY, BAG, BAG_TARGET, CONFIRM, MESSAGE, FORGET }

const ENTRIES := ["Pokémon", "Sac", "Sauvegarde", "Quitter"]
const ENTRY_COLORS := [Color8(96, 192, 96), Color8(240, 184, 56), Color8(88, 144, 232), Color8(232, 88, 72)]
const HINTS := ["Voir son équipe.", "Ouvrir le sac.", "Sauvegarder la partie.", "Quitter la partie."]
const POCKET_NAMES := ["Objets", "Soins", "Balls", "Combat", "Objets rares"]
const POCKET_COLORS := [Color8(240, 184, 56), Color8(96, 192, 96), Color8(232, 88, 72), Color8(88, 144, 232), Color8(168, 120, 216)]
## Zone de gauche (listes, résumé, sac) et boîte d'aide en bas à gauche ; l'équipe occupe
## la droite de l'écran.
const LEFT := Rect2(4, 4, 216, 202)
const HINT := Rect2(4, 210, 216, 50)
const BAG_ROWS := 6
const OPEN_TIME := 0.18
const VIEW_TIME := 0.12

var _state := State.CLOSED
var _data: PlayerData
var _entry := 0
var _pocket := ItemData.Pocket.MEDICINE
var _item := 0
var _confirm_yes := true
## Action confirmée par « Oui » : &"save" ou &"quit".
var _confirm_action := &""
var _message := ""
## État où revenir après un message.
var _after_message := State.MAIN
## Attaque à apprendre en attente (voir PlayerProfiles.move_choice_requested), ou {}.
var _choice := {}
## Entrée choisie : une attaque connue, ou la dernière (« ne pas apprendre »).
var _forget := 0
var _party: PartyPanel
## Résumé complet d'un Pokémon (plusieurs pages), par-dessus le menu.
var _summary: SummaryScreen
## Ouverture (0 : fermé, 1 : ouvert) et arrivée de l'écran de gauche, animées.
var _open_amount := 0.0
var _view_amount := 1.0
var _last_view := &"main"
var _pulse := 0.0
var _tween: Tween


func _enter_tree() -> void:
	Game.register(&"menu", self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameFont.get_theme()
	visible = false
	_party = PartyPanel.new()
	add_child(_party)
	_summary = SummaryScreen.new()
	_summary.closed.connect(_on_summary_closed)
	add_child(_summary)
	_place_party()
	if Game.profiles != null:
		Game.profiles.snapshot_received.connect(_on_snapshot)
		Game.profiles.request_answered.connect(_show_message)
		Game.profiles.move_choice_requested.connect(_on_move_choice_requested)
	Network.session_ended.connect(close)


func is_open() -> bool:
	return _state != State.CLOSED


func open() -> void:
	_state = State.MAIN
	_entry = 0
	_last_view = &"main"
	_view_amount = 1.0
	visible = true
	_party.select(-1)
	if Game.profiles != null:
		Game.profiles.request_snapshot()
	_animate_open(1.0)


func close() -> void:
	if _state == State.CLOSED:
		return
	_state = State.CLOSED
	_animate_open(0.0)


func _animate_open(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_open_amount, _open_amount, target, OPEN_TIME)
	if target == 0.0:
		_tween.tween_callback(func(): visible = false)


func _set_open_amount(value: float) -> void:
	_open_amount = value
	_place_party()
	queue_redraw()


## L'équipe glisse depuis le bord droit de l'écran.
func _place_party() -> void:
	var screen := Vector2(GameConfig.screen_size())
	_party.position = Vector2(roundf(screen.x - PartyPanel.PANEL_SIZE.x * _open_amount), 0)


func _process(delta: float) -> void:
	if _state == State.CLOSED:
		return
	# Un combat qui commence ferme le menu.
	var world := Game.world
	if Game.battles != null and world != null and Game.battles.is_in_battle(multiplayer.get_unique_id()):
		close()
		return
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	var view := _view()
	if view != _last_view:
		_last_view = view
		_view_amount = 0.0
	_view_amount = minf(1.0, _view_amount + delta / VIEW_TIME)
	queue_redraw()


func _can_open() -> bool:
	var world := Game.world
	var player := world.local_player() if world != null else null
	return player != null and not player.moving and not player.is_busy()


# --- Commandes ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _state == State.CLOSED:
		if event.is_action_pressed("menu") and _can_open():
			open()
			get_viewport().set_input_as_handled()
		return
	var handled := true
	if event.is_action_pressed("move_up", true):
		_on_direction(Vector2i.UP)
	elif event.is_action_pressed("move_down", true):
		_on_direction(Vector2i.DOWN)
	elif event.is_action_pressed("move_left", true):
		_on_direction(Vector2i.LEFT)
	elif event.is_action_pressed("move_right", true):
		_on_direction(Vector2i.RIGHT)
	elif event.is_action_pressed("interact"):
		_on_accept()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		_on_back()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
		queue_redraw()


func _on_direction(dir: Vector2i) -> void:
	match _state:
		State.MAIN:
			if dir.y != 0:
				_entry = posmod(_entry + dir.y, ENTRIES.size())
		State.PARTY, State.BAG_TARGET:
			if dir.y != 0:
				_party.move_selection(dir.y)
		State.BAG:
			if dir.x != 0:
				_pocket = posmod(_pocket + dir.x, POCKET_NAMES.size()) as ItemData.Pocket
				_item = 0
			elif dir.y != 0 and not _pocket_items().is_empty():
				_item = posmod(_item + dir.y, _pocket_items().size())
		State.CONFIRM:
			_confirm_yes = not _confirm_yes
		State.FORGET:
			if dir.y != 0:
				_forget = posmod(_forget + dir.y, _choice["moves"].size() + 1)


func _on_accept() -> void:
	match _state:
		State.MAIN:
			match _entry:
				0:
					if _data != null and not _data.party.is_empty():
						_state = State.PARTY
						_party.select(0)
				1:
					_state = State.BAG
					_item = 0
				2:
					_ask(&"save")
				3:
					_ask(&"quit")
		State.PARTY:
			if _party.selected_pokemon() != null:
				_state = State.SUMMARY
				_summary.open(_data.party, _party.selected, false)
		State.BAG:
			var item := _selected_item()
			if item != null:
				_state = State.BAG_TARGET
				_party.select(0)
		State.BAG_TARGET:
			var item := _selected_item()
			if item != null and Game.profiles != null:
				Game.profiles.request_use_item(item.resource_path, _party.selected)
		State.CONFIRM:
			if not _confirm_yes:
				_state = State.MAIN
			elif _confirm_action == &"save":
				_state = State.MAIN
				Game.profiles.request_save()
			else:
				close()
				Network.leave()
		State.MESSAGE:
			_end_message()
		State.FORGET:
			var known: int = _choice["moves"].size()
			# Avant la demande : chez l'hôte, la réponse (message, choix suivant) arrive aussitôt.
			_choice = {}
			_state = State.BAG
			_party.select(-1)
			Game.profiles.request_move_choice(_forget if _forget < known else -1)


func _on_back() -> void:
	match _state:
		State.MAIN:
			close()
		State.PARTY, State.BAG, State.CONFIRM:
			_state = State.MAIN
			_party.select(-1)
		State.BAG_TARGET:
			_state = State.BAG
			_party.select(-1)
		State.MESSAGE:
			_end_message()
		State.FORGET:
			# On ne quitte pas ce choix : « retour » mène à « ne pas apprendre ».
			_forget = _choice["moves"].size()


func _ask(action: StringName) -> void:
	_confirm_action = action
	_confirm_yes = action == &"save"
	_state = State.CONFIRM


## Retour du résumé : le Pokémon affiché en dernier reste choisi dans l'équipe.
func _on_summary_closed(index: int) -> void:
	if _state != State.SUMMARY:
		return
	_state = State.PARTY
	var shown := _summary.current()
	_party.select(_data.party.find(shown) if _data != null and shown != null else index)


func _show_message(text: String) -> void:
	if _state == State.CLOSED:
		return
	_message = text
	_after_message = State.BAG if _state in [State.BAG, State.BAG_TARGET] else State.MAIN
	_state = State.MESSAGE
	queue_redraw()


func _end_message() -> void:
	if not _choice.is_empty():
		_open_forget()
		return
	_state = _after_message
	_party.select(-1)


func _on_move_choice_requested(choice: Dictionary) -> void:
	_choice = choice
	# Un message (l'évolution) s'affiche d'abord ; le choix vient ensuite.
	if _state != State.MESSAGE:
		_open_forget()


func _open_forget() -> void:
	if _state == State.CLOSED:
		visible = true
		_animate_open(1.0)
	_state = State.FORGET
	_forget = 0
	_party.select(_choice["party_index"])


func _on_snapshot(data: PlayerData) -> void:
	_data = data
	var keep := _party.selected
	_party.set_party(data.party)
	_party.select(mini(keep, data.party.size() - 1))
	var items := _pocket_items()
	_item = clampi(_item, 0, maxi(0, items.size() - 1))
	queue_redraw()


func _pocket_items() -> Array[ItemData]:
	var found: Array[ItemData] = []
	if _data == null:
		return found
	for item in _data.bag.items:
		if item.pocket == _pocket and _data.bag.count(item) > 0:
			found.append(item)
	return found


func _selected_item() -> ItemData:
	var items := _pocket_items()
	return items[_item] if _item >= 0 and _item < items.size() else null


# --- Dessin ------------------------------------------------------------------------------
# Même langage visuel que l'écran de combat (DsUi) : écran tactile brun à petits points,
# boutons crème à bande de couleur, cadres de message blancs liserés de bleu.

func _draw() -> void:
	if not visible:
		return
	# Voile sur le monde, qui se fond à l'ouverture.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.4 * _open_amount))
	# La partie gauche glisse depuis le bord gauche, à l'ouverture et à chaque changement
	# d'écran (liste, résumé, sac).
	var slide := -(1.0 - _open_amount) * 240.0 - (1.0 - _view_amount) * 14.0
	draw_set_transform(Vector2(roundf(slide), 0))
	match _view():
		&"bag":
			_draw_bag()
		&"forget":
			_draw_forget()
		_:
			_draw_main()
	draw_set_transform(Vector2(roundf(-(1.0 - _open_amount) * 240.0), 0))
	_draw_hint()
	draw_set_transform(Vector2.ZERO)


## Écran de gauche affiché pour l'état courant.
func _view() -> StringName:
	match _state:
		State.BAG, State.BAG_TARGET:
			return &"bag"
		State.FORGET:
			return &"forget"
		State.MESSAGE:
			return &"bag" if _after_message == State.BAG else &"main"
	return &"main"


func _draw_main() -> void:
	# Carte du dresseur : pseudo, temps de jeu, argent.
	var card := Rect2(LEFT.position, Vector2(LEFT.size.x, 42))
	DsUi.draw_message_frame(self, card)
	if _data != null:
		_text(card.position + Vector2(9, 3), _data.player_name)
		_text_right(Vector2(card.end.x - 9, card.position.y + 3), _format_time(_data.play_time))
		_text(card.position + Vector2(9, 20), "Argent")
		_text_right(Vector2(card.end.x - 9, card.position.y + 20), str(_data.money))
	else:
		_text(card.position + Vector2(9, 3), "…")
	# Liste des entrées sur l'écran tactile.
	var list := Rect2(LEFT.position + Vector2(0, 46), Vector2(118, ENTRIES.size() * 31 + 7))
	DsUi.draw_touch_panel(self, list)
	for i in ENTRIES.size():
		var row := Rect2(list.position + Vector2(4, 5 + i * 31), Vector2(list.size.x - 8, 28))
		var highlighted := i == _entry and _state in [State.MAIN, State.CONFIRM]
		DsUi.draw_button(self, row, ENTRY_COLORS[i], highlighted, _pulse)
		_text(row.position + Vector2(17, 6), ENTRIES[i])
	if _state == State.CONFIRM and _confirm_action == &"save":
		_draw_save_card(Rect2(list.end.x + 4, list.position.y, LEFT.end.x - list.end.x - 4, list.size.y))


## Résumé de la partie à sauvegarder : pseudo, lieu, équipe en icônes, temps de jeu.
func _draw_save_card(card: Rect2) -> void:
	DsUi.draw_message_frame(self, card)
	if _data == null:
		return
	_text(card.position + Vector2(8, 3), _data.player_name)
	_text(card.position + Vector2(8, 19), _map_name(_current_map()))
	for i in _data.party.size():
		var icon := MenuSprites.pokemon_icon(_data.party[i].species)
		if icon != null:
			draw_texture(icon, card.position + Vector2(4 + (i % 3) * 28, 36 + (i / 3) * 28))
	_text(card.position + Vector2(8, card.size.y - 21), "Temps")
	_text_right(Vector2(card.end.x - 8, card.position.y + card.size.y - 21), _format_time(_data.play_time))


func _draw_bag() -> void:
	DsUi.draw_touch_panel(self, LEFT)
	# Poche : son nom dans un cadre, entre deux flèches, et des onglets en dessous.
	var header := Rect2(LEFT.position + Vector2(4, 4), Vector2(LEFT.size.x - 8, 22))
	DsUi.draw_message_frame(self, header)
	var name_width := GameFont.get_font().get_string_size(POCKET_NAMES[_pocket], HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL).x
	_text(Vector2(header.get_center().x - name_width / 2.0, header.position.y + 3), POCKET_NAMES[_pocket])
	_draw_arrow(Vector2(header.position.x + 12, header.get_center().y), -1)
	_draw_arrow(Vector2(header.end.x - 12, header.get_center().y), 1)
	for i in POCKET_NAMES.size():
		var tab := Rect2(LEFT.position + Vector2(8 + i * 12, 30), Vector2(10, 4))
		draw_rect(tab, POCKET_COLORS[i] if i == _pocket else POCKET_COLORS[i].darkened(0.6))
	# Sacoche, sur un rond clair.
	var bag := MenuSprites.bag(_state == State.BAG_TARGET)
	var bag_center := LEFT.position + Vector2(34, 90)
	draw_circle(bag_center, 27.0, BattleSprites.HUD_PANEL_DARK)
	draw_circle(bag_center, 25.0, POCKET_COLORS[_pocket].lerp(Color.WHITE, 0.55))
	if bag != null:
		draw_texture(bag, (bag_center - bag.get_size() / 2.0).round())
	# Objets : boutons crème, comme la liste du sac au combat.
	var items := _pocket_items()
	var list_x := LEFT.position.x + 68
	var list_width := LEFT.end.x - 4 - list_x
	if items.is_empty():
		_draw_hollow(Rect2(list_x, LEFT.position.y + 40, list_width, 26))
		_text(Vector2(list_x + 10, LEFT.position.y + 45), "Rien ici.")
		return
	var first := clampi(_item - BAG_ROWS + 1, 0, maxi(0, items.size() - BAG_ROWS))
	for row in mini(BAG_ROWS, items.size() - first):
		var index := first + row
		var item := items[index]
		var rect := Rect2(list_x, LEFT.position.y + 40 + row * 27, list_width, 25)
		var target := _state == State.BAG_TARGET
		DsUi.draw_button(self, rect, POCKET_COLORS[_pocket], index == _item, _pulse if not target else 0.0)
		_text(rect.position + Vector2(16, 4), item.name)
		_text_right(Vector2(rect.end.x - 8, rect.position.y + 4), "x%d" % _data.bag.count(item))


## Choix de l'attaque à oublier : la nouvelle en haut, puis les attaques connues et
## « ne pas l'apprendre », en boutons comme la liste du sac.
func _draw_forget() -> void:
	DsUi.draw_touch_panel(self, LEFT)
	var header := Rect2(LEFT.position + Vector2(4, 4), Vector2(LEFT.size.x - 8, 22))
	DsUi.draw_message_frame(self, header)
	_text(header.position + Vector2(8, 3), "Nouvelle : %s" % _choice["move_name"])
	var entries: Array = _choice["moves"]
	for i in entries.size() + 1:
		var rect := Rect2(LEFT.position + Vector2(4, 32 + i * 28), Vector2(LEFT.size.x - 8, 25))
		var last := i == entries.size()
		DsUi.draw_button(self, rect, POCKET_COLORS[2] if last else POCKET_COLORS[3], i == _forget, _pulse)
		if last:
			_text(rect.position + Vector2(16, 4), "Ne pas l'apprendre")
		else:
			_text(rect.position + Vector2(16, 4), entries[i]["name"])
			_text_right(Vector2(rect.end.x - 8, rect.position.y + 4), "PP %d/%d" % [entries[i]["pp"], entries[i]["max_pp"]])


func _draw_hint() -> void:
	DsUi.draw_message_frame(self, HINT)
	var text := ""
	var icon: Texture2D = null
	match _state:
		State.MAIN:
			text = HINTS[_entry]
		State.PARTY:
			text = "Choisis un Pokémon pour voir son résumé."
		State.BAG:
			var item := _selected_item()
			if item != null:
				text = item.description
				icon = MenuSprites.item_icon(item)
			else:
				text = "Gauche / droite : changer de poche."
		State.BAG_TARGET:
			var item := _selected_item()
			text = "Utiliser %s sur quel Pokémon ?" % (item.name if item != null else "l'objet")
			icon = MenuSprites.item_icon(item)
		State.CONFIRM:
			text = "Sauvegarder la partie ?" if _confirm_action == &"save" else "Quitter la partie ?"
		State.FORGET:
			text = "%s connaît déjà quatre attaques. Laquelle oublier ?" % _choice["name"]
		State.MESSAGE:
			text = _message
			DsUi.draw_more_arrow(self, HINT.end - Vector2(16, 12))
	var x := HINT.position.x + 9
	if icon != null:
		draw_texture(icon, Vector2(x - 2, HINT.position.y + 8))
		x += 34
	var width := HINT.end.x - 9 - x - (58 if _state == State.CONFIRM else 0)
	draw_multiline_string(GameFont.get_font(), Vector2(x, HINT.position.y + 4 + GameFont.ASCENT), text,
		HORIZONTAL_ALIGNMENT_LEFT, width, GameFont.CELL, 3)
	if _state == State.CONFIRM:
		for i in 2:
			var rect := Rect2(HINT.end.x - 60, HINT.position.y + 5 + i * 20, 54, 19)
			DsUi.draw_button(self, rect, BattleStyle.COMMAND_COLORS[2 if i == 0 else 0], (i == 0) == _confirm_yes, _pulse)
			_text(rect.position + Vector2(16, 1), "Oui" if i == 0 else "Non")


# --- Petits outils ------------------------------------------------------------------------

## Texte du jeu (lettres sombres), coin haut-gauche en `pos`.
func _text(pos: Vector2, text: String) -> void:
	draw_string(GameFont.get_font(), pos + Vector2(0, GameFont.ASCENT), text, HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL)


## Texte en lettres claires, pour l'écran tactile brun.
func _light_text(pos: Vector2, text: String) -> void:
	draw_string(GameFont.get_light_font(), pos + Vector2(0, GameFont.ASCENT), text, HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL)


## Texte aligné à droite sur `right.x`.
func _text_right(right: Vector2, text: String) -> void:
	var width := GameFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL).x
	_text(right - Vector2(width, 0), text)


## Emplacement vide : un creux plus sombre dans l'écran tactile.
func _draw_hollow(rect: Rect2) -> void:
	draw_colored_polygon(BattleStyle.panel_points(rect, 3), BattleSprites.HUD_PANEL_DARK)


## Flèche rouge de changement de poche.
func _draw_arrow(center: Vector2, direction: int) -> void:
	var nudge := roundf(sin(_pulse) * 1.0) * direction
	var tip := center + Vector2(4 * direction + nudge, 0)
	var back := center - Vector2(3 * direction - nudge, 0)
	draw_colored_polygon(PackedVector2Array([tip, back + Vector2(0, -5), back + Vector2(0, 5)]), DsUi.CURSOR)


func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%d:%02d" % [minutes / 60, minutes % 60]


## Carte où se trouve le joueur de cet ordinateur.
func _current_map() -> StringName:
	var player := Game.world.local_player() if Game.world != null else null
	return player.map_id if player != null else _data.map_id


func _map_name(map_id: StringName) -> String:
	var loaded := Game.world.map(map_id) if Game.world != null and not map_id.is_empty() else null
	return loaded.display_name if loaded != null and not loaded.display_name.is_empty() else String(map_id)
