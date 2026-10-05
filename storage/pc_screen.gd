class_name PcScreen
extends Control
## Écran du PC de stockage, ouvert depuis un PC du monde (PcTerminal). Mêmes éléments que
## le menu du jeu et la boutique (DsUi : boutons crème, curseur rouge, cadres de message,
## chiffres du HUD), sur des panneaux clairs pour un écran lumineux : la boîte à gauche, sur
## toute la hauteur, avec son fond de Noir et Blanc ; l'équipe à droite (PartyPanel) ; sous
## la grille, le Pokémon désigné. Les messages n'apparaissent que lorsqu'il y en a.
## À l'ouverture, l'écran s'allume comme un vieil écran : une ligne lumineuse qui s'étire,
## puis s'ouvre en hauteur ; il s'éteint de la même façon à la fermeture.
##
## Commandes : flèches pour déplacer le curseur (en haut : le nom de la boîte, gauche /
## droite pour changer de boîte ; à droite de la boîte : l'équipe), « interact » pour
## choisir, « cancel » pour revenir, « menu » pour les réglages de la boîte.
## Prendre un Pokémon ne change rien aux données : c'est en le posant que l'écran demande
## l'opération à l'hôte (PlayerProfiles.request_pc_move), qui la vérifie et répond. Si
## elle est refusée, le Pokémon reste en main et le message s'affiche.

## Le PC vient d'être quitté (le terminal éteint alors son écran).
signal closed

enum Area { HEADER, GRID, PARTY }
enum State { CLOSED, BROWSE, ACTIONS, BOX_MENU, SUMMARY, RENAME, WALLPAPER, WAITING, MESSAGE }

const BOX_PANEL := Rect2(4, 4, 216, 256)
## Bandeau de titre et motif de la boîte (fond de Noir et Blanc étendu), grille dessus.
const TITLE := Rect2(10, 10, 204, 19)
const BODY := Rect2(10, 31, 204, 196)
## Ligne du Pokémon désigné, sous la grille.
const FOOTER := Rect2(10, 230, 204, 26)
## Message ponctuel (refus, renommage, fond), par-dessus le bas de la boîte.
const PROMPT := Rect2(8, 208, 208, 48)
const CELL := Vector2(34, 39)
const ACTIONS := ["Déplacer", "Résumé", "Annuler"]
const ACTION_COLORS := [Color8(88, 144, 232), Color8(96, 192, 96), Color8(232, 88, 72)]
const BOX_MENU := ["Renommer", "Fond", "Quitter le PC"]
const BOX_MENU_COLORS := [Color8(240, 184, 56), Color8(168, 120, 216), Color8(232, 88, 72)]
const OPEN_TIME := 0.18
## Allumage de l'écran : ligne qui s'étire, puis ouverture en hauteur, puis fondu.
const POWER_TIME := 0.38
const POWER_FADE_TIME := 0.2
const SWITCH_TIME := 0.12
## Hauteur dont le Pokémon en main est soulevé.
const HOLD_LIFT := 8.0

var _state := State.CLOSED
var _data: PlayerData
var _box := 0
var _area := Area.GRID
var _col := 0
var _row := 0
var _party_index := 0
## Pokémon pris en main : son emplacement (voir PokemonStorage), ou null.
var _held: Variant = null
var _menu_index := 0
var _wallpaper_choice := 0
var _message := ""
var _answer := ""
var _waiting_reply := false
var _open_amount := 0.0
var _switch_amount := 1.0
var _switch_dir := 0
var _pulse := 0.0
var _tween: Tween
## Allumage (0 : éteint, 1 : écran ouvert) et opacité de la lumière de l'écran.
var _power := 0.0
var _power_glow := 0.0
var _power_tween: Tween
var _power_layer: Control
var _party: PartyPanel
## Résumé complet d'un Pokémon (plusieurs pages), par-dessus le PC.
var _summary: SummaryScreen
var _name_edit: LineEdit


func _enter_tree() -> void:
	Game.register(&"pc", self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameFont.get_theme()
	visible = false
	_party = PartyPanel.new()
	_party.light = true
	add_child(_party)
	_name_edit = LineEdit.new()
	_name_edit.visible = false
	_name_edit.position = Vector2(TITLE.get_center().x - 60, TITLE.position.y - 2)
	_name_edit.size = Vector2(120, TITLE.size.y + 4)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.text_submitted.connect(_on_name_submitted)
	add_child(_name_edit)
	_summary = SummaryScreen.new()
	_summary.closed.connect(_on_summary_closed)
	add_child(_summary)
	# Lumière de l'allumage, par-dessus tout l'écran (équipe comprise).
	_power_layer = Control.new()
	_power_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_power_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_layer.draw.connect(_draw_power)
	add_child(_power_layer)
	_place_party()
	if Game.profiles != null:
		Game.profiles.snapshot_received.connect(_on_snapshot)
		Game.profiles.request_answered.connect(_on_answer)
	Network.session_ended.connect(close)


func is_open() -> bool:
	return _state != State.CLOSED


## Allume le PC : l'écran s'allume (ligne lumineuse qui s'étire puis s'ouvre en hauteur),
## puis la boîte et l'équipe glissent depuis les bords pendant que la lumière s'efface.
func open() -> void:
	if is_open():
		return
	_state = State.WAITING
	_held = null
	_area = Area.GRID
	_col = 0
	_row = 0
	if Game.profiles != null:
		Game.profiles.request_snapshot()
	visible = true
	_open_amount = 0.0
	_place_party()
	_power_glow = 1.0
	await _power_to(1.0, POWER_TIME)
	_state = State.BROWSE
	_update_party_selection()
	_animate_open(1.0)
	_fade_glow(0.0)


## Éteint le PC : la boîte et l'équipe repartent, l'écran se referme en une ligne.
func close() -> void:
	if not is_open():
		return
	_state = State.CLOSED
	_held = null
	_name_edit.visible = false
	closed.emit()
	_animate_open(0.0)
	await _fade_glow(1.0)
	await _power_to(0.0, POWER_TIME * 0.7)
	if not is_open():
		visible = false


func _power_to(target: float, duration: float) -> void:
	if _power_tween != null:
		_power_tween.kill()
	_power_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_power_tween.tween_method(func(v: float) -> void:
		_power = v
		_power_layer.queue_redraw(), _power, target, duration)
	await _power_tween.finished


func _fade_glow(target: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_power_glow = v
		_power_layer.queue_redraw(), _power_glow, target, POWER_FADE_TIME)
	await tween.finished


func _animate_open(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float) -> void:
		_open_amount = v
		_place_party()
		queue_redraw(), _open_amount, target, OPEN_TIME)


func _place_party() -> void:
	var screen := Vector2(GameConfig.screen_size())
	_party.position = Vector2(roundf(screen.x - PartyPanel.PANEL_SIZE.x * _open_amount), 0)


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	_switch_amount = minf(1.0, _switch_amount + delta / SWITCH_TIME)
	queue_redraw()


# --- Données reçues de l'hôte ----------------------------------------------------------------

func _on_snapshot(data: PlayerData) -> void:
	_data = data
	_box = clampi(_box, 0, maxi(0, _data.storage.boxes.size() - 1))
	_party.set_party(_data.party)
	if _waiting_reply:
		# La réponse de l'hôte arrive en deux temps (copie puis message éventuel) : on
		# conclut une fois les deux reçus.
		_conclude_request.call_deferred()
	queue_redraw()


func _on_answer(message: String) -> void:
	if not is_open():
		return
	_answer = message


func _conclude_request() -> void:
	if not _waiting_reply:
		return
	_waiting_reply = false
	if _answer.is_empty():
		# Opération faite : le Pokémon est posé.
		_held = null
		_state = State.BROWSE
	else:
		# Refusée : rien n'a changé, le Pokémon reste en main.
		_show(_answer)
	_answer = ""
	_update_party_selection()


func _request_move(to: Vector2i) -> void:
	if Game.profiles == null or _held == null:
		return
	_answer = ""
	_waiting_reply = true
	_state = State.WAITING
	Game.profiles.request_pc_move(_held, to)


# --- Commandes ------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Pendant la saisie du nom, Échap annule (le champ texte garde les autres touches).
	if _state == State.RENAME and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_end_rename()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or _state in [State.WAITING, State.RENAME]:
		if is_open():
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
	elif event.is_action_pressed("cancel"):
		_on_back()
	elif event.is_action_pressed("menu"):
		if _state == State.BROWSE and _held == null:
			_open_box_menu()
		else:
			_on_back()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_direction(dir: Vector2i) -> void:
	match _state:
		State.BROWSE:
			_move_cursor(dir)
		State.ACTIONS:
			if dir.y != 0:
				_menu_index = posmod(_menu_index + dir.y, ACTIONS.size())
		State.BOX_MENU:
			if dir.y != 0:
				_menu_index = posmod(_menu_index + dir.y, BOX_MENU.size())
		State.WALLPAPER:
			if dir.x != 0 or dir.y != 0:
				_wallpaper_choice = posmod(_wallpaper_choice + dir.x + dir.y, PcSprites.WALLPAPER_COUNT)


func _move_cursor(dir: Vector2i) -> void:
	var columns := _columns()
	var rows := _rows()
	match _area:
		Area.HEADER:
			if dir.x != 0:
				_switch_box(dir.x)
			elif dir.y > 0:
				_area = Area.GRID
				_row = 0
		Area.GRID:
			if dir.y < 0 and _row == 0:
				_area = Area.HEADER
			elif dir.y != 0:
				_row = clampi(_row + dir.y, 0, rows - 1)
			elif dir.x > 0 and _col == columns - 1:
				_area = Area.PARTY
				_party_index = clampi(_row, 0, PartyPanel.SLOTS - 1)
			elif dir.x != 0:
				_col = clampi(_col + dir.x, 0, columns - 1)
		Area.PARTY:
			if dir.x < 0:
				_area = Area.GRID
				_col = columns - 1
				_row = clampi(_party_index, 0, rows - 1)
			elif dir.y != 0:
				_party_index = posmod(_party_index + dir.y, PartyPanel.SLOTS)
	_update_party_selection()


func _on_accept() -> void:
	match _state:
		State.BROWSE:
			if _area == Area.HEADER:
				_open_box_menu()
			elif _held != null:
				_request_move(_cursor_location())
			elif _hovered() != null:
				_state = State.ACTIONS
				_menu_index = 0
		State.ACTIONS:
			match _menu_index:
				0:
					_held = _cursor_location()
					_state = State.BROWSE
				1:
					_open_summary()
				_:
					_state = State.BROWSE
		State.BOX_MENU:
			match _menu_index:
				0:
					_start_rename()
				1:
					_wallpaper_choice = _current_box().wallpaper if _current_box() != null else 0
					_state = State.WALLPAPER
				_:
					close()
		State.WALLPAPER:
			if Game.profiles != null:
				_answer = ""
				_waiting_reply = true
				_state = State.WAITING
				_held = null
				Game.profiles.request_pc_wallpaper(_box, _wallpaper_choice)
		State.MESSAGE:
			_state = State.BROWSE
	_update_party_selection()


func _on_back() -> void:
	match _state:
		State.BROWSE:
			if _held != null:
				# Reposer le Pokémon : rien n'avait changé dans les données.
				_held = null
			else:
				close()
		State.ACTIONS, State.BOX_MENU, State.WALLPAPER, State.MESSAGE:
			_state = State.BROWSE
	_update_party_selection()


func _open_box_menu() -> void:
	_state = State.BOX_MENU
	_menu_index = 0


func _switch_box(step: int) -> void:
	if _data == null or _data.storage.boxes.is_empty():
		return
	_box = posmod(_box + step, _data.storage.boxes.size())
	_switch_dir = step
	_switch_amount = 0.0


## Résumé complet : les Pokémon de la boîte (ou de l'équipe) défilent avec haut / bas.
func _open_summary() -> void:
	_state = State.SUMMARY
	if _area == Area.PARTY:
		_summary.open(_data.party, _party_index, true)
	else:
		_summary.open(_current_box().slots, _row * _columns() + _col, true)


## Retour du résumé : le curseur va sur le Pokémon affiché en dernier.
func _on_summary_closed(_index: int) -> void:
	if _state != State.SUMMARY:
		return
	_state = State.BROWSE
	var shown := _summary.current()
	if shown != null and _area == Area.PARTY:
		_party_index = maxi(0, _data.party.find(shown))
	elif shown != null and _current_box() != null:
		var slot := _current_box().slots.find(shown)
		if slot != -1:
			_col = slot % _columns()
			_row = slot / _columns()
	_update_party_selection()


func _start_rename() -> void:
	_state = State.RENAME
	_name_edit.text = _current_box().name if _current_box() != null else ""
	_name_edit.max_length = _data.storage.config.name_max_length if _data != null else 12
	_name_edit.visible = true
	_name_edit.grab_focus()
	_name_edit.select_all()


func _on_name_submitted(text: String) -> void:
	_end_rename()
	if Game.profiles != null:
		_answer = ""
		_waiting_reply = true
		_state = State.WAITING
		Game.profiles.request_pc_rename(_box, text)


func _end_rename() -> void:
	_name_edit.release_focus()
	_name_edit.visible = false
	_state = State.BROWSE


func _show(text: String) -> void:
	_message = text
	_state = State.MESSAGE


# --- Emplacements ---------------------------------------------------------------------------

func _current_box() -> PokemonBox:
	if _data == null or _box >= _data.storage.boxes.size():
		return null
	return _data.storage.boxes[_box]


func _columns() -> int:
	return _data.storage.config.columns if _data != null else 6


func _rows() -> int:
	var box := _current_box()
	return ceili(float(box.capacity()) / _columns()) if box != null else 5


## Emplacement désigné par le curseur (voir PokemonStorage).
func _cursor_location() -> Vector2i:
	if _area == Area.PARTY:
		return PokemonStorage.party_slot(_party_index)
	return PokemonStorage.box_slot(_box, _row * _columns() + _col)


func _hovered() -> PokemonInstance:
	if _data == null or _area == Area.HEADER:
		return null
	return _data.storage.get_pokemon(_data.party, _cursor_location())


func _held_pokemon() -> PokemonInstance:
	return _data.storage.get_pokemon(_data.party, _held) if _data != null and _held != null else null


func _update_party_selection() -> void:
	_party.select_slot(_party_index if _area == Area.PARTY and _state != State.CLOSED else -1)
	_party.held_from = _held.y if _held != null and _held.x == PokemonStorage.PARTY else -1


func _cell_rect(index: int) -> Rect2:
	var columns := _columns()
	return Rect2(BODY.position + Vector2(index % columns, index / columns) * CELL, CELL)


# --- Dessin ---------------------------------------------------------------------------------

func _draw() -> void:
	if not visible or _open_amount <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.2 * _open_amount))
	draw_set_transform(Vector2(roundf(-(1.0 - _open_amount) * 240.0), 0))
	if _state != State.SUMMARY:
		_draw_box()
		if _state == State.ACTIONS:
			_draw_choice_panel(ACTIONS, ACTION_COLORS)
		elif _state == State.BOX_MENU:
			_draw_choice_panel(BOX_MENU, BOX_MENU_COLORS)
		var prompt := _prompt_text()
		if not prompt.is_empty():
			_draw_prompt(prompt)
	draw_set_transform(Vector2.ZERO)
	_draw_held()


func _draw_box() -> void:
	DsUi.draw_light_panel(self, BOX_PANEL)
	var box := _current_box()
	if box == null:
		return
	# Changement de boîte : la nouvelle glisse depuis le côté choisi.
	var shift := Vector2(roundf((1.0 - _switch_amount) * 24.0 * _switch_dir), 0)
	var wallpaper_index := _wallpaper_choice if _state == State.WALLPAPER else box.wallpaper
	# Le paysage du bandeau, à sa taille d'origine, au milieu ; les flèches de part et d'autre.
	var title_art := PcSprites.title(wallpaper_index)
	var title_rect := Rect2((TITLE.get_center() - Vector2(title_art.get_size()) / 2.0).round() + shift, title_art.get_size())
	draw_rect(title_rect.grow(1), BattleStyle.OUTLINE)
	draw_texture(title_art, title_rect.position)
	draw_style_box(PcSprites.body_style(wallpaper_index), Rect2(BODY.position + shift, BODY.size))
	# Nom de la boîte sur son bandeau, entre deux flèches.
	if _state != State.RENAME:
		var title := box.name if _state != State.WALLPAPER else PcSprites.wallpaper_name(wallpaper_index)
		var center := TITLE.get_center() + shift
		DsUi.draw_text(self, Vector2(center.x - DsUi.text_width(title) / 2.0, TITLE.position.y + 1), title)
	var lit := _area == Area.HEADER and _state in [State.BROWSE, State.WALLPAPER]
	_draw_arrow(Vector2(TITLE.position.x + 22, TITLE.get_center().y), -1, lit)
	_draw_arrow(Vector2(TITLE.end.x - 22, TITLE.get_center().y), 1, lit)
	if _area == Area.HEADER and _state == State.BROWSE:
		draw_rect(title_rect.grow(2), DsUi.CURSOR, false, 1.0)
	# Emplacements et Pokémon.
	for i in box.capacity():
		var rect := _cell_rect(i)
		rect.position += shift
		if _area == Area.GRID and i == _row * _columns() + _col:
			draw_rect(rect.grow(-2), Color(1, 1, 1, 0.4))
			draw_rect(rect.grow(-2), DsUi.CURSOR_OUTLINE, false, 1.0)
		var pokemon: PokemonInstance = box.slots[i]
		if pokemon == null:
			continue
		var is_held: bool = _held != null and _held == PokemonStorage.box_slot(_box, i)
		var icon := MenuSprites.pokemon_icon(pokemon.species)
		if icon != null:
			var tint := Color(1, 1, 1, 0.35) if is_held else Color.WHITE
			draw_texture(icon, (rect.get_center() - Vector2(16, 18)).round(), tint)
	if _area == Area.GRID and _held == null and _state == State.BROWSE:
		var cell := _cell_rect(_row * _columns() + _col)
		DsUi.draw_cursor_down(self, cell.position + shift + Vector2(CELL.x / 2.0, 1 + sin(_pulse)))
	_draw_footer(box)


## Sous la grille : le Pokémon désigné (ou en main) et le remplissage de la boîte.
func _draw_footer(box: PokemonBox) -> void:
	draw_rect(Rect2(FOOTER.position.x, FOOTER.position.y - 2, FOOTER.size.x, 1), BattleStyle.MESSAGE_LINE)
	var y := FOOTER.position.y + 3
	# Remplissage de la boîte, à droite.
	var right := FOOTER.end.x - 2
	var max_width := DsUi.draw_hud_number(self, box.capacity(), Vector2(right, y + 4), true)
	draw_line(Vector2(right - max_width - 4, y + 12), Vector2(right - max_width - 2, y + 5), BattleStyle.OUTLINE, 1.0)
	DsUi.draw_hud_number(self, box.count(), Vector2(right - max_width - 6, y + 4), true)
	var pokemon := _held_pokemon() if _held != null else _hovered()
	if pokemon == null:
		if box.is_full():
			DsUi.draw_text(self, Vector2(FOOTER.position.x + 2, y), "Boîte pleine")
		return
	var label := "%s  N.%d" % [pokemon.display_name(), pokemon.level]
	DsUi.draw_text(self, Vector2(FOOTER.position.x + 2, y), label, false, 120)
	var gauge := Rect2(FOOTER.position.x + 126, y + 5, 40, 5)
	draw_rect(gauge, BattleStyle.OUTLINE)
	draw_rect(gauge.grow(-1), BattleStyle.HP_EMPTY)
	DsUi.draw_hud_gauge(self, gauge.grow(-1), float(pokemon.hp()) / maxf(1.0, pokemon.max_hp()))


## Pokémon en main : il suit le curseur, soulevé, avec son ombre.
func _draw_held() -> void:
	var pokemon := _held_pokemon()
	if pokemon == null or _state == State.SUMMARY:
		return
	var icon := MenuSprites.pokemon_icon(pokemon.species)
	if icon == null:
		return
	var anchor: Vector2
	if _area == Area.PARTY:
		var slot := _party.slot_rect(_party_index)
		anchor = _party.position + slot.position + Vector2(29, 22)
	elif _area == Area.HEADER:
		anchor = Vector2(TITLE.get_center().x, TITLE.end.y + 22)
	else:
		anchor = _cell_rect(_row * _columns() + _col).get_center() + Vector2(0, 6)
	anchor.x += roundf(-(1.0 - _open_amount) * 240.0) if _area != Area.PARTY else 0.0
	var bob := roundf(sin(_pulse) * 1.0)
	draw_circle(anchor + Vector2(0, 2), 6.0, Color(0, 0, 0, 0.3))
	draw_texture(icon, (anchor - Vector2(16, 28 + HOLD_LIFT - bob)).round())


## Message à afficher par-dessus le bas de la boîte, ou "" s'il n'y en a pas.
func _prompt_text() -> String:
	match _state:
		State.MESSAGE:
			return _message
		State.RENAME:
			return "Nouveau nom, puis Entrée (Échap : annuler)."
		State.WALLPAPER:
			return "Gauche / droite : fond. Valider pour le garder."
	return ""


func _draw_prompt(text: String) -> void:
	DsUi.draw_message_frame(self, PROMPT)
	draw_multiline_string(GameFont.get_font(), Vector2(PROMPT.position.x + 9, PROMPT.position.y + 4 + GameFont.ASCENT), text,
		HORIZONTAL_ALIGNMENT_LEFT, PROMPT.size.x - 22, GameFont.CELL, 2)
	if _state == State.MESSAGE:
		DsUi.draw_more_arrow(self, PROMPT.end - Vector2(16, 12))


## Petite liste de choix, comme ceux de la boutique, au-dessus du bas de la boîte.
func _draw_choice_panel(entries: Array, colors: Array) -> void:
	var panel := Rect2(BOX_PANEL.end.x - 112, FOOTER.position.y - entries.size() * 27 - 14, 108, entries.size() * 27 + 12)
	DsUi.draw_light_panel(self, panel)
	for i in entries.size():
		var row := Rect2(panel.position + Vector2(6, 6 + i * 27), Vector2(panel.size.x - 12, 25))
		DsUi.draw_button(self, row, colors[i], i == _menu_index, _pulse)
		DsUi.draw_text(self, row.position + Vector2(16, 4), entries[i], false, row.size.x - 20)


func _draw_arrow(center: Vector2, direction: int, lit: bool) -> void:
	var nudge := roundf(sin(_pulse) * 1.0) * direction if lit else 0.0
	var tip := center + Vector2(4 * direction + nudge, 0)
	var back := center - Vector2(3 * direction - nudge, 0)
	var color := DsUi.CURSOR if lit else DsUi.CURSOR.darkened(0.4)
	draw_colored_polygon(PackedVector2Array([tip, back + Vector2(0, -5), back + Vector2(0, 5)]), color)


## Allumage de l'écran : d'abord une ligne lumineuse qui s'étire depuis le centre, puis la
## lumière qui s'ouvre sur toute la hauteur ; elle s'efface ensuite sur l'écran du PC.
func _draw_power() -> void:
	if _power_glow <= 0.0 or _power <= 0.0:
		return
	var screen := Vector2(GameConfig.screen_size())
	var line_part := 0.4
	var white := Color(1, 1, 1, _power_glow)
	if _power < line_part:
		var width := roundf(screen.x * _power / line_part)
		var line := Rect2((screen.x - width) / 2.0, screen.y / 2.0 - 1, width, 2)
		_power_layer.draw_rect(line.grow_individual(0, 2, 0, 2), Color(DsUi.LIGHT_DOTS, 0.6 * _power_glow))
		_power_layer.draw_rect(line, white)
	else:
		var height := roundf(lerpf(2.0, screen.y, (_power - line_part) / (1.0 - line_part)))
		var rect := Rect2(0, (screen.y - height) / 2.0, screen.x, height)
		_power_layer.draw_rect(rect, Color(DsUi.LIGHT_FILL, _power_glow))
		_power_layer.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), white)
		_power_layer.draw_rect(Rect2(rect.position.x, rect.end.y - 2, rect.size.x, 2), white)
