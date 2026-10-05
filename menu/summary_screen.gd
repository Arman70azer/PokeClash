class_name SummaryScreen
extends Control
## Résumé complet d'un Pokémon, sur tout l'écran, en cinq pages : Infos, Mémo,
## Statistiques, IV / EV et Capacités. Ouvert depuis le menu du jeu (équipe) et depuis le
## PC de stockage. À gauche, une carte fixe : le Pokémon de face (qui respire comme au
## combat), son nom, son genre, son niveau, ses types, son statut et son objet.
##
## Commandes : gauche / droite pour changer de page, haut / bas pour passer au Pokémon
## précédent ou suivant de la liste, « cancel », « interact » ou « menu » pour revenir.
## Même style que le reste de l'interface (DsUi), sur fond clair ou sombre selon l'écran
## qui l'ouvre.

## Le résumé est refermé ; `index` : Pokémon affiché en dernier dans la liste.
signal closed(index: int)

const PAGES := ["Infos", "Mémo", "Statistiques", "IV / EV", "Capacités"]
const PAGE_COLORS := [Color8(88, 144, 232), Color8(240, 184, 56), Color8(232, 88, 72), Color8(168, 120, 216), Color8(96, 192, 96)]
const SCREEN := Rect2(2, 2, 348, 260)
const HEADER := Rect2(8, 8, 336, 22)
const CARD := Rect2(8, 34, 128, 222)
const CONTENT := Rect2(140, 34, 204, 222)
const LINE := 16.0
const MALE_COLOR := Color8(72, 136, 240)
const FEMALE_COLOR := Color8(240, 88, 104)
const UP_COLOR := Color8(224, 64, 56)
const DOWN_COLOR := Color8(64, 112, 224)
const SLIDE_TIME := 0.12
## Respiration du sprite : durée de chaque image.
const BREATH_TIME := 0.5

## Fond clair (PC) ou écran tactile brun (menu).
var light := false
var _list: Array[PokemonInstance] = []
var _index := 0
var _page := 0
var _page_dir := 0
var _slide := 1.0
var _pulse := 0.0
var _breath := 0.0
var _open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func is_open() -> bool:
	return _open


## Affiche le résumé du Pokémon `index` de `list` (les cases vides sont ignorées).
func open(list: Array, index: int, p_light := false) -> void:
	_list.clear()
	var start := 0
	for i in list.size():
		if list[i] != null:
			if i == index:
				start = _list.size()
			_list.append(list[i])
	if _list.is_empty():
		return
	_index = start
	_page = 0
	light = p_light
	_open = true
	visible = true
	_slide = 0.0
	_page_dir = 0


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	closed.emit(_index)


func current() -> PokemonInstance:
	return _list[_index] if _index >= 0 and _index < _list.size() else null


func _process(delta: float) -> void:
	if not _open:
		return
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	_breath = fmod(_breath + delta, BREATH_TIME * 2.0)
	_slide = minf(1.0, _slide + delta / SLIDE_TIME)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("move_left", true):
		_turn_page(-1)
	elif event.is_action_pressed("move_right", true):
		_turn_page(1)
	elif event.is_action_pressed("move_up", true):
		_change_pokemon(-1)
	elif event.is_action_pressed("move_down", true):
		_change_pokemon(1)
	elif event.is_action_pressed("cancel") or event.is_action_pressed("interact") or event.is_action_pressed("menu"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _turn_page(step: int) -> void:
	_page = posmod(_page + step, PAGES.size())
	_page_dir = step
	_slide = 0.0


func _change_pokemon(step: int) -> void:
	if _list.size() < 2:
		return
	_index = posmod(_index + step, _list.size())
	_page_dir = 0
	_slide = 0.0


# --- Dessin ---------------------------------------------------------------------------------

func _draw() -> void:
	var pokemon := current()
	if not _open or pokemon == null:
		return
	DsUi.draw_backdrop(self, SCREEN, light)
	_draw_header()
	_draw_card(pokemon)
	DsUi.draw_message_frame(self, CONTENT)
	# La page arrive en glissant du côté choisi.
	var offset := roundf((1.0 - _slide) * 10.0) * _page_dir
	var x := CONTENT.position.x + 9 + offset
	var y := CONTENT.position.y + 6
	var right := CONTENT.end.x - 9 + offset
	match _page:
		0:
			_draw_infos(pokemon, x, y, right)
		1:
			_draw_memo(pokemon, x, y, right)
		2:
			_draw_stats(pokemon, x, y, right)
		3:
			_draw_ivs_evs(pokemon, x, y, right)
		4:
			_draw_moves(pokemon, x, y, right)


func _draw_header() -> void:
	DsUi.draw_message_frame(self, HEADER)
	var title: String = PAGES[_page]
	var title_x := HEADER.get_center().x - DsUi.text_width(title) / 2.0
	DsUi.draw_text(self, Vector2(title_x, HEADER.position.y + 3), title)
	_draw_arrow(Vector2(HEADER.position.x + 14, HEADER.get_center().y), -1)
	_draw_arrow(Vector2(HEADER.end.x - 14, HEADER.get_center().y), 1)
	# Une pastille par page, la page affichée en couleur.
	for i in PAGES.size():
		var pip := Rect2(HEADER.end.x - 34 - (PAGES.size() - i) * 10, HEADER.position.y + 8, 7, 7)
		draw_rect(pip, BattleStyle.OUTLINE)
		draw_rect(pip.grow(-1), PAGE_COLORS[i] if i == _page else BattleStyle.PANEL_SHADE)
	# Position dans la liste.
	if _list.size() > 1:
		var w := DsUi.draw_hud_number(self, _index + 1, Vector2(HEADER.position.x + 34, HEADER.position.y + 7), false)
		draw_line(Vector2(HEADER.position.x + 37 + w, HEADER.position.y + 15), Vector2(HEADER.position.x + 39 + w, HEADER.position.y + 8), BattleStyle.OUTLINE, 1.0)
		DsUi.draw_hud_number(self, _list.size(), Vector2(HEADER.position.x + 42 + w, HEADER.position.y + 7), false)


## Carte de gauche : le Pokémon, toujours visible quelle que soit la page.
func _draw_card(pokemon: PokemonInstance) -> void:
	DsUi.draw_message_frame(self, CARD)
	var frame := 1 if _breath >= BREATH_TIME else 0
	var sprite := BattleSprites.pokemon(pokemon.species, false, frame)
	if sprite == null:
		sprite = BattleSprites.pokemon(pokemon.species, false, 0)
	if sprite != null:
		var at := Vector2(CARD.get_center().x - sprite.get_width() / 2.0, CARD.position.y + 4).round()
		draw_texture(sprite, at)
	var x := CARD.position.x + 8
	var y := CARD.position.y + 88
	DsUi.draw_text(self, Vector2(x, y), pokemon.display_name(), false, CARD.size.x - 30)
	_draw_gender(pokemon.gender, Vector2(CARD.end.x - 16, y))
	y += LINE + 2
	DsUi.draw_text(self, Vector2(x, y), "N.%d" % pokemon.level)
	var status := MenuSprites.status_label(&"fainted" if pokemon.is_fainted() else pokemon.status)
	if status != null:
		draw_texture(status, Vector2(CARD.end.x - 8 - status.get_width(), y + 5))
	y += LINE + 4
	var tx := x
	for type in pokemon.species.types:
		var label := MenuSprites.type_label(type)
		if label != null:
			draw_texture(label, Vector2(tx, y))
			tx += label.get_width() + 3
	y += 18
	# PV, jauge du HUD.
	var gauge := Rect2(x, y + 2, CARD.size.x - 16, 6)
	draw_rect(gauge, BattleStyle.OUTLINE)
	draw_rect(gauge.grow(-1), BattleStyle.HP_EMPTY)
	DsUi.draw_hud_gauge(self, gauge.grow(-1), float(pokemon.hp()) / maxf(1.0, pokemon.max_hp()))
	y += 10
	DsUi.draw_text(self, Vector2(x, y), "PV")
	DsUi.draw_text_right(self, Vector2(CARD.end.x - 8, y), "%d/%d" % [pokemon.hp(), pokemon.max_hp()])
	y += LINE + 4
	# Objet tenu.
	draw_rect(Rect2(x, y, CARD.size.x - 16, 1), BattleStyle.MESSAGE_LINE)
	y += 3
	var icon := MenuSprites.item_icon(pokemon.held_item)
	if icon != null:
		draw_texture(icon, Vector2(x - 4, y))
		DsUi.draw_text(self, Vector2(x + 28, y + 8), pokemon.held_item.name, false, CARD.size.x - 44)
	else:
		DsUi.draw_text(self, Vector2(x, y + 4), "Aucun objet")


func _draw_infos(pokemon: PokemonInstance, x: float, y: float, right: float) -> void:
	var species := pokemon.species
	_row(x, y, right, "Pokédex", "%03d" % species.dex_number)
	y += LINE + 2
	_row(x, y, right, "Espèce", species.name)
	y += LINE + 2
	DsUi.draw_text(self, Vector2(x, y), "Type")
	var tx := right
	for i in range(species.types.size() - 1, -1, -1):
		var label := MenuSprites.type_label(species.types[i])
		if label != null:
			tx -= label.get_width()
			draw_texture(label, Vector2(tx, y + 3))
			tx -= 3
	y += LINE + 2
	_row(x, y, right, "Genre", {&"male": "Mâle", &"female": "Femelle"}.get(pokemon.gender, "Asexué"))
	y += LINE + 2
	_row(x, y, right, "Dresseur", pokemon.original_trainer if not pokemon.original_trainer.is_empty() else "Inconnu")
	y += LINE + 2
	_row(x, y, right, "Expérience", str(pokemon.experience))
	y += LINE + 2
	var talent := pokemon.ability_data()
	_row(x, y, right, "Talent", talent.name if talent != null else "—")
	y += LINE + 2
	_row(x, y, right, "Objet", pokemon.held_item.name if pokemon.held_item != null else "Aucun")


func _draw_memo(pokemon: PokemonInstance, x: float, y: float, right: float) -> void:
	var nature := Nature.nature_name(pokemon.nature)
	var up := Nature.raised(pokemon.nature)
	var down := Nature.lowered(pokemon.nature)
	_row(x, y, right, "Nature", nature)
	y += LINE + 2
	if up == -1:
		DsUi.draw_text(self, Vector2(x, y), "Nature neutre.")
		y += LINE + 2
	else:
		DsUi.draw_text(self, Vector2(x + 10, y), Stat.stat_name(up))
		_draw_nature_mark(Vector2(x, y + 4), 1)
		y += LINE
		DsUi.draw_text(self, Vector2(x + 10, y), Stat.stat_name(down))
		_draw_nature_mark(Vector2(x, y + 4), -1)
		y += LINE + 2
	y += 4
	_separator(x, y, right)
	y += 6
	var memo := PackedStringArray()
	memo.append("Nature : %s." % nature)
	if not pokemon.met_location.is_empty():
		memo.append("Rencontré à %s au niveau %d." % [pokemon.met_location, maxi(pokemon.met_level, 1)])
	else:
		memo.append("Lieu de rencontre inconnu.")
	if not pokemon.original_trainer.is_empty():
		memo.append("Dresseur d'origine : %s." % pokemon.original_trainer)
	_paragraph(x, y, right, " ".join(memo))


func _draw_stats(pokemon: PokemonInstance, x: float, y: float, right: float) -> void:
	DsUi.draw_text(self, Vector2(x + 96, y), "Base")
	DsUi.draw_text_right(self, Vector2(right, y), "Valeur")
	y += LINE + 2
	_separator(x, y, right)
	y += 4
	var up := Nature.raised(pokemon.nature)
	var down := Nature.lowered(pokemon.nature)
	var total := 0
	for stat_id in Stat.PERMANENT:
		var value := pokemon.max_hp() if stat_id == Stat.HP else pokemon.stat(stat_id)
		total += pokemon.species.base_stat(stat_id)
		DsUi.draw_text(self, Vector2(x + 10, y), Stat.stat_name(stat_id))
		if stat_id == up:
			_draw_nature_mark(Vector2(x, y + 4), 1)
		elif stat_id == down:
			_draw_nature_mark(Vector2(x, y + 4), -1)
		DsUi.draw_hud_number(self, pokemon.species.base_stat(stat_id), Vector2(x + 112, y + 4), true)
		var shown := "%d/%d" % [pokemon.hp(), value] if stat_id == Stat.HP else str(value)
		DsUi.draw_text_right(self, Vector2(right, y), shown)
		y += LINE + 4
	_separator(x, y, right)
	y += 4
	DsUi.draw_text(self, Vector2(x + 10, y), "Total")
	DsUi.draw_hud_number(self, total, Vector2(x + 112, y + 4), true)


func _draw_ivs_evs(pokemon: PokemonInstance, x: float, y: float, right: float) -> void:
	var iv_x := x + 68
	var ev_x := x + 126
	DsUi.draw_text(self, Vector2(iv_x, y), "IV")
	DsUi.draw_text(self, Vector2(ev_x, y), "EV")
	y += LINE + 2
	_separator(x, y, right)
	y += 4
	var ev_total := 0
	for i in Stat.PERMANENT.size():
		var stat_id: int = Stat.PERMANENT[i]
		var iv := pokemon.ivs[i] if i < pokemon.ivs.size() else 0
		var ev := pokemon.evs[i] if i < pokemon.evs.size() else 0
		ev_total += ev
		DsUi.draw_text(self, Vector2(x, y), _short_stat(stat_id))
		_draw_value_bar(Vector2(iv_x, y), iv, 31, Color8(96, 192, 96))
		_draw_value_bar(Vector2(ev_x, y), ev, 255, Color8(88, 144, 232))
		y += LINE + 4
	_separator(x, y, right)
	y += 4
	DsUi.draw_text(self, Vector2(x, y), "EV au total")
	DsUi.draw_text_right(self, Vector2(right, y), "%d / 510" % ev_total)
	y += LINE + 2
	DsUi.draw_text(self, Vector2(x, y), "IV max. : 31, EV max. : 255.")


func _draw_moves(pokemon: PokemonInstance, x: float, y: float, right: float) -> void:
	for i in 4:
		var rect := Rect2(x - 4, y, right - x + 8, 24)
		if i >= pokemon.moves.size() or pokemon.moves[i] == null:
			draw_colored_polygon(BattleStyle.panel_points(rect, 3), DsUi.LIGHT_HOLLOW)
			DsUi.draw_text(self, rect.position + Vector2(12, 4), "—")
			y += 53
			continue
		var move := pokemon.moves[i]
		DsUi.draw_button(self, rect, BattleStyle.type_color(move.type), false)
		DsUi.draw_text(self, rect.position + Vector2(12, 4), move.name, false, rect.size.x - 60)
		DsUi.draw_text_right(self, Vector2(rect.end.x - 6, rect.position.y + 4), "%d/%d" % [pokemon.pp_left(i), move.pp])
		var info_y := y + 27
		var label := MenuSprites.type_label(move.type)
		if label != null:
			draw_texture(label, Vector2(x, info_y + 2))
		DsUi.draw_text(self, Vector2(x + 36, info_y - 2), MoveData.CATEGORY_NAMES[move.category])
		var power := str(move.power) if move.power > 0 else "—"
		var accuracy := str(move.accuracy) if move.accuracy > 0 else "—"
		DsUi.draw_text_right(self, Vector2(right, info_y - 2), "%s / %s" % [power, accuracy])
		y += 53
	DsUi.draw_text_right(self, Vector2(right, CONTENT.end.y - 20), "Puiss. / Préc.")


# --- Petits outils ------------------------------------------------------------------------

func _row(x: float, y: float, right: float, label: String, value: String) -> void:
	DsUi.draw_text(self, Vector2(x, y), label)
	DsUi.draw_text_right(self, Vector2(right, y), value)


func _separator(x: float, y: float, right: float) -> void:
	draw_rect(Rect2(x, y, right - x, 1), BattleStyle.MESSAGE_LINE)


func _paragraph(x: float, y: float, right: float, text: String) -> void:
	if text.is_empty():
		return
	draw_multiline_string(GameFont.get_font(), Vector2(x, y + GameFont.ASCENT), text, HORIZONTAL_ALIGNMENT_LEFT,
		right - x, GameFont.CELL, 5)


## Nombre (chiffres du HUD) et petite jauge de `maximum`.
func _draw_value_bar(at: Vector2, value: int, maximum: int, color: Color) -> void:
	DsUi.draw_hud_number(self, value, at + Vector2(22, 4), true)
	var bar := Rect2(at + Vector2(26, 6), Vector2(28, 5))
	draw_rect(bar, BattleStyle.OUTLINE)
	draw_rect(bar.grow(-1), BattleStyle.HP_EMPTY)
	var filled := roundf((bar.size.x - 2) * clampf(float(value) / maximum, 0.0, 1.0))
	if filled > 0:
		draw_rect(Rect2(bar.position + Vector2.ONE, Vector2(filled, bar.size.y - 2)), color)


## Petit triangle de nature : vers le haut (rouge) ou le bas (bleu), comme dans les jeux.
func _draw_nature_mark(at: Vector2, direction: int) -> void:
	var color := UP_COLOR if direction > 0 else DOWN_COLOR
	var points := PackedVector2Array([at + Vector2(0, 6), at + Vector2(6, 6), at + Vector2(3, 0)]) if direction > 0 \
		else PackedVector2Array([at, at + Vector2(6, 0), at + Vector2(3, 6)])
	draw_colored_polygon(points, color)


func _draw_gender(gender: StringName, at: Vector2) -> void:
	if gender == &"none":
		return
	var symbol := "♂" if gender == &"male" else "♀"
	draw_string(GameFont.get_light_font(), at + Vector2(0, GameFont.ASCENT), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1,
		GameFont.CELL, MALE_COLOR if gender == &"male" else FEMALE_COLOR)


func _draw_arrow(center: Vector2, direction: int) -> void:
	var nudge := roundf(sin(_pulse) * 1.0) * direction
	var tip := center + Vector2(4 * direction + nudge, 0)
	var back := center - Vector2(3 * direction - nudge, 0)
	draw_colored_polygon(PackedVector2Array([tip, back + Vector2(0, -5), back + Vector2(0, 5)]), DsUi.CURSOR)


static func _short_stat(stat_id: int) -> String:
	return {Stat.HP: "PV", Stat.ATTACK: "Attaque", Stat.DEFENSE: "Défense", Stat.SP_ATTACK: "Atq. Spé.",
		Stat.SP_DEFENSE: "Déf. Spé.", Stat.SPEED: "Vitesse"}.get(stat_id, "?")
