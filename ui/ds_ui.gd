class_name DsUi
extends RefCounted
## Éléments d'interface communs à tout le jeu, dans le style de l'écran tactile de Noir et
## Blanc : fond brun sombre à petits points, boutons crème à bande de couleur, cadre de
## message blanc liseré de bleu, chiffres et jauge de PV de la planche « Battle HUD ».
## Utilisés par l'écran de combat et par le menu du jeu, pour qu'ils se ressemblent.

const CURSOR := Color8(232, 72, 56)
const CURSOR_OUTLINE := Color(1, 0.95, 0.6)


## Fond de l'écran tactile : brun sombre, petits points en quinconce. `border` : liseré
## noir tout autour (sinon seulement en haut).
static func draw_touch_panel(ci: CanvasItem, rect: Rect2, border := true, dots_from := 5) -> void:
	ci.draw_rect(rect, BattleSprites.HUD_PANEL)
	if border:
		ci.draw_rect(rect, Color.BLACK, false, 2.0)
	else:
		ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), Color.BLACK)
	for y in range(dots_from, int(rect.size.y), 6):
		for x in range(3 + (y / 6 % 2) * 3, int(rect.size.x), 6):
			ci.draw_rect(Rect2(rect.position + Vector2(x, y), Vector2.ONE), BattleSprites.HUD_PANEL_DARK)


## Couleurs du panneau clair (PC de stockage) : le blanc bleuté des cadres de message, avec
## les petits points de l'écran tactile en bleu pâle.
const LIGHT_FILL := Color8(232, 240, 248)
const LIGHT_DOTS := Color8(204, 218, 236)
const LIGHT_HOLLOW := Color8(212, 224, 240)


## Panneau clair : même forme que le cadre de message (contour sombre, liseré bleu clair),
## rempli de blanc bleuté à petits points. Pour les écrans qui doivent rester lumineux.
static func draw_light_panel(ci: CanvasItem, rect: Rect2) -> void:
	BattleStyle.draw_rounded(ci, rect, 6.0, BattleStyle.OUTLINE)
	BattleStyle.draw_rounded(ci, rect.grow(-2), 4.0, Color8(248, 248, 248))
	BattleStyle.draw_rounded(ci, rect.grow(-4), 3.0, BattleStyle.MESSAGE_LINE)
	BattleStyle.draw_rounded(ci, rect.grow(-5), 2.0, LIGHT_FILL)
	for y in range(8, int(rect.size.y) - 6, 6):
		for x in range(7 + (y / 6 % 2) * 3, int(rect.size.x) - 6, 6):
			ci.draw_rect(Rect2(rect.position + Vector2(x, y), Vector2.ONE), LIGHT_DOTS)


## Fond d'écran : clair (panneau à points bleus) ou sombre (écran tactile brun).
static func draw_backdrop(ci: CanvasItem, rect: Rect2, light: bool) -> void:
	if light:
		draw_light_panel(ci, rect)
	else:
		draw_touch_panel(ci, rect)


## Bouton crème teinté de `color`, bande franche de la couleur à gauche ; le bouton choisi
## est plus clair, cerclé de lumière, avec la flèche rouge du curseur (`pulse` : phase de
## son balancement). `enabled` faux : bouton grisé.
static func draw_button(ci: CanvasItem, rect: Rect2, color: Color, selected: bool, pulse := 0.0, enabled := true) -> void:
	if not enabled:
		color = color.lerp(Color(0.6, 0.6, 0.62), 0.7)
	var fill := color.lerp(Color.WHITE, 0.55 if not selected else 0.7)
	BattleStyle.draw_panel(ci, rect, fill, 0.0, not selected)
	ci.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(4, rect.size.y - 7)), color)
	ci.draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(4, 1)), color.lightened(0.4))
	if selected:
		var outline := BattleStyle.panel_points(rect.grow(-1), 3)
		outline.append(outline[0])
		ci.draw_polyline(outline, CURSOR_OUTLINE, 1.0, false)
		draw_cursor(ci, rect.position + Vector2(9, 6.0 + sin(pulse) * 1.0))


## Flèche rouge du curseur, pointe vers la droite, coin haut-gauche en `pos`.
static func draw_cursor(ci: CanvasItem, pos: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(0, 8), pos + Vector2(5, 4)]), CURSOR)


## La même flèche, pointe vers le bas (au-dessus d'une case), pointe en `tip`.
static func draw_cursor_down(ci: CanvasItem, tip: Vector2) -> void:
	ci.draw_colored_polygon(PackedVector2Array([tip - Vector2(4, 5), tip - Vector2(-4, 5), tip]), CURSOR)


## Cadre des messages : blanc, contour sombre, liseré bleu clair.
static func draw_message_frame(ci: CanvasItem, rect: Rect2) -> void:
	BattleStyle.draw_rounded(ci, rect, 6.0, BattleStyle.OUTLINE)
	BattleStyle.draw_rounded(ci, rect.grow(-2), 4.0, Color8(248, 248, 248))
	BattleStyle.draw_rounded(ci, rect.grow(-4), 3.0, BattleStyle.MESSAGE_LINE)
	BattleStyle.draw_rounded(ci, rect.grow(-5), 2.0, Color8(252, 252, 252))


## Petite flèche qui clignote en bas à droite d'un message qui attend d'être lu.
static func draw_more_arrow(ci: CanvasItem, tip: Vector2) -> void:
	if fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.0:
		ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(8, 0), tip + Vector2(4, 5)]), CURSOR)


## Nombre écrit avec les chiffres du HUD (blancs cernés de noir) ; `right_aligned` : `at`
## est son bord droit. Renvoie sa largeur.
static func draw_hud_number(ci: CanvasItem, value: int, at: Vector2, right_aligned: bool) -> float:
	var digits := str(maxi(value, 0))
	var textures: Array[Texture2D] = []
	var width := 0.0
	for c in digits:
		var texture := BattleSprites.hud_digit(int(c))
		textures.append(texture)
		width += texture.get_width() + 1
	var x := at.x - width + 1 if right_aligned else at.x
	for texture in textures:
		ci.draw_texture(texture, Vector2(x, at.y))
		x += texture.get_width() + 1
	return width - 1


## Jauge de PV du HUD (deux lignes, verte, jaune ou rouge) dans `slot`, remplie à `ratio`.
static func draw_hud_gauge(ci: CanvasItem, slot: Rect2, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var colors: Array = BattleSprites.HUD_GAUGE_COLORS[0 if ratio > 0.5 else (1 if ratio > 0.2 else 2)]
	var width := maxf(1.0, ceilf(slot.size.x * ratio))
	var half := maxf(1.0, floorf(slot.size.y / 2.0))
	ci.draw_rect(Rect2(slot.position, Vector2(width, half)), colors[0])
	ci.draw_rect(Rect2(slot.position + Vector2(0, half), Vector2(width, slot.size.y - half)), colors[1])


## Texte du jeu, coin haut-gauche en `pos` ; `light` : lettres claires (fond sombre).
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, light := false, max_width := -1.0) -> void:
	var font := GameFont.get_light_font() if light else GameFont.get_font()
	ci.draw_string(font, pos + Vector2(0, GameFont.ASCENT), text, HORIZONTAL_ALIGNMENT_LEFT, max_width, GameFont.CELL)


## Texte aligné à droite : `right.x` est son bord droit.
static func draw_text_right(ci: CanvasItem, right: Vector2, text: String, light := false) -> void:
	var width := GameFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL).x
	draw_text(ci, right - Vector2(width, 0), text, light)


## Largeur d'un texte dans la police du jeu.
static func text_width(text: String) -> float:
	return GameFont.get_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, GameFont.CELL).x
