class_name PartyPanel
extends Control
## Colonne de l'équipe du menu du jeu, dans le style de l'écran tactile des combats : fond
## brun à petits points, un bouton crème par Pokémon, teinté de la couleur de son type.
## Chaque bouton montre l'icône du Pokémon (qui sautille quand il est choisi), son nom, sa
## jauge de PV et ses PV avec les chiffres du HUD de combat, son niveau et son statut.

const SLOTS := 6
const PANEL_SIZE := Vector2(126, 264)
const SLOT_SIZE := Vector2(120, 38)
const SLOT_STEP := 40.0
const FIRST_SLOT := Vector2(3, 20)
## Sautillement de l'icône choisie : durée d'une image, hauteur du saut.
const HOP_TIME := 0.18
const HOP_HEIGHT := 2.0
const FAINTED_COLOR := Color8(200, 72, 64)

var party: Array[PokemonInstance] = []
## Pokémon choisi, ou -1 si la colonne n'a pas la main.
var selected := -1
## Fond clair (PC de stockage) plutôt que l'écran tactile brun.
var light := false
## Place d'où un Pokémon a été pris en main (PC de stockage) : affichée en creux. -1 : aucune.
var held_from := -1

var _hop_clock := 0.0
var _hop_up := false
var _pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	_hop_clock += delta
	if _hop_clock >= HOP_TIME:
		_hop_clock = 0.0
		_hop_up = not _hop_up
	if selected >= 0 or held_from >= 0:
		queue_redraw()


func set_party(p_party: Array[PokemonInstance]) -> void:
	party = p_party
	selected = mini(selected, SLOTS - 1)
	queue_redraw()


func select(index: int) -> void:
	selected = index
	_hop_up = false
	_hop_clock = 0.0
	queue_redraw()


## Désigne une place, même vide (PC de stockage), de 0 à SLOTS - 1.
func select_slot(index: int) -> void:
	select(clampi(index, -1, SLOTS - 1))


## Choisit le Pokémon suivant (+1) ou précédent (-1), en boucle.
func move_selection(step: int) -> void:
	if party.is_empty():
		return
	select(posmod(maxi(selected, 0) + step, party.size()))


func selected_pokemon() -> PokemonInstance:
	return party[selected] if selected >= 0 and selected < party.size() else null


func slot_rect(index: int) -> Rect2:
	return Rect2(FIRST_SLOT + Vector2(0, index * SLOT_STEP), SLOT_SIZE)


func _draw() -> void:
	DsUi.draw_backdrop(self, Rect2(Vector2.ZERO, PANEL_SIZE), light)
	# Titre de la colonne (lettres claires sur le fond brun, sombres sur le fond clair) et
	# nombre de Pokémon.
	DsUi.draw_text(self, Vector2(8, 2), "Équipe", not light)
	DsUi.draw_hud_number(self, party.size(), Vector2(PANEL_SIZE.x - 22, 6), true)
	draw_line(Vector2(PANEL_SIZE.x - 21, 14), Vector2(PANEL_SIZE.x - 19, 7), BattleStyle.OUTLINE if light else Color.WHITE, 1.0)
	DsUi.draw_hud_number(self, SLOTS, Vector2(PANEL_SIZE.x - 16, 6), false)
	for i in SLOTS:
		var rect := slot_rect(i)
		if i >= party.size() or party[i] == null:
			_draw_empty(rect, i == selected)
		else:
			_draw_pokemon(party[i], rect, i == selected)
			if i == held_from:
				# Pokémon en main : sa place reste marquée, en creux.
				draw_colored_polygon(BattleStyle.panel_points(rect, 3), Color(DsUi.LIGHT_HOLLOW if light else BattleSprites.HUD_PANEL_DARK, 0.75))


## Emplacement libre : un creux sombre, sans bouton.
func _draw_empty(rect: Rect2, is_selected := false) -> void:
	draw_colored_polygon(BattleStyle.panel_points(rect, 3), DsUi.LIGHT_HOLLOW if light else BattleSprites.HUD_PANEL_DARK)
	var outline := BattleStyle.panel_points(rect, 3)
	outline.append(outline[0])
	# Place vide désignée (PC de stockage) : contour lumineux et flèche, comme un bouton.
	var edge := BattleStyle.MESSAGE_LINE if light else BattleSprites.HUD_PANEL.lightened(0.15)
	draw_polyline(outline, DsUi.CURSOR if is_selected and light else (DsUi.CURSOR_OUTLINE if is_selected else edge), 1.0)
	if is_selected:
		DsUi.draw_cursor(self, rect.position + Vector2(9, 6.0 + sin(_pulse) * 1.0))


func _draw_pokemon(pokemon: PokemonInstance, rect: Rect2, is_selected: bool) -> void:
	var fainted := pokemon.is_fainted()
	var color := BattleStyle.PANEL_SHADE
	if fainted:
		color = FAINTED_COLOR
	elif not pokemon.species.types.is_empty():
		color = BattleStyle.type_color(pokemon.species.types[0])
	DsUi.draw_button(self, rect, color, is_selected, _pulse)
	var icon := MenuSprites.pokemon_icon(pokemon.species)
	if icon != null:
		var hop := -HOP_HEIGHT if is_selected and _hop_up and not fainted else 0.0
		var tint := Color(0.6, 0.6, 0.65) if fainted else Color.WHITE
		draw_texture(icon, rect.position + Vector2(13, 3 + hop), tint)
	var font := GameFont.get_font()
	var text_x := rect.position.x + 46
	var right := rect.end.x - 5
	draw_string(font, Vector2(text_x, rect.position.y + GameFont.ASCENT), pokemon.display_name(),
		HORIZONTAL_ALIGNMENT_LEFT, right - text_x, GameFont.CELL)
	# Jauge de PV, cadre sombre comme celui des barres du combat.
	var hp := pokemon.hp()
	var max_hp := pokemon.max_hp()
	var gauge := Rect2(text_x, rect.position.y + 17, right - text_x, 5)
	draw_rect(gauge, BattleStyle.OUTLINE)
	draw_rect(gauge.grow(-1), BattleStyle.HP_EMPTY)
	DsUi.draw_hud_gauge(self, gauge.grow(-1), float(hp) / maxf(1.0, max_hp))
	# Niveau et statut à gauche, PV à droite.
	var level := "N.%d" % pokemon.level
	draw_string(font, Vector2(text_x, rect.position.y + 21 + GameFont.ASCENT), level,
		HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL)
	# K.O. : le bouton rouge et l'icône grisée le disent déjà, pas d'étiquette en plus.
	var label := MenuSprites.status_label(pokemon.status) if not fainted else null
	if label != null:
		var level_width := font.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL).x
		draw_texture(label, Vector2(text_x + level_width + 2, rect.position.y + 28))
	var max_width := DsUi.draw_hud_number(self, max_hp, Vector2(right, rect.position.y + 25), true)
	var slash_x := right - max_width - 4
	draw_line(Vector2(slash_x, rect.position.y + 33), Vector2(slash_x + 2, rect.position.y + 26), BattleStyle.OUTLINE, 1.0)
	DsUi.draw_hud_number(self, hp, Vector2(slash_x - 2, rect.position.y + 25), true)
