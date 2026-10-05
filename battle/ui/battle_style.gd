class_name BattleStyle
extends RefCounted
## Couleurs et petits outils de dessin de l'écran de combat (cadres, barres, boutons),
## dans l'esprit des jeux DS : contours sombres, aplats, reflets d'un pixel.

## Couleur de chaque type (boutons d'attaque, effets).
const TYPE_COLORS := [
	Color8(168, 168, 120), Color8(240, 128, 48), Color8(104, 144, 240), Color8(248, 208, 48),
	Color8(120, 200, 80), Color8(152, 216, 216), Color8(192, 48, 40), Color8(160, 64, 160),
	Color8(224, 192, 104), Color8(168, 144, 240), Color8(248, 88, 136), Color8(168, 184, 32),
	Color8(184, 160, 56), Color8(112, 88, 152), Color8(112, 56, 248), Color8(112, 88, 72),
	Color8(184, 184, 208), Color8(238, 153, 172),
]
## Boutons du menu principal : Combat, Sac, Pokémon, Fuite.
const COMMAND_COLORS := [Color8(232, 88, 72), Color8(240, 184, 56), Color8(96, 192, 96), Color8(88, 144, 232)]

const OUTLINE := Color8(40, 48, 64)
## Liseré intérieur de la boîte de messages, et plaque claire derrière les noms.
const MESSAGE_LINE := Color8(160, 192, 224)
const NAME_PLATE := Color(1, 1, 1, 0.82)
const PANEL := Color8(248, 248, 240)
const PANEL_SHADE := Color8(208, 216, 216)
const TAB := Color8(72, 80, 104)
const HP_GREEN := Color8(88, 208, 96)
const HP_YELLOW := Color8(248, 200, 40)
const HP_RED := Color8(240, 80, 56)
const HP_EMPTY := Color8(80, 88, 104)
const STATUS_COLORS := {
	"PSN": Color8(160, 72, 168), "BRL": Color8(232, 96, 48), "PAR": Color8(216, 176, 40),
	"SOM": Color8(136, 136, 152), "GEL": Color8(96, 184, 216),
}


## Rectangle aux coins arrondis (rayon `radius`, en pixels), rempli.
static func draw_rounded(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) / 2.0)
	ci.draw_rect(Rect2(rect.position + Vector2(r, 0), Vector2(rect.size.x - 2 * r, rect.size.y)), color)
	ci.draw_rect(Rect2(rect.position + Vector2(0, r), Vector2(rect.size.x, rect.size.y - 2 * r)), color)
	for corner in [rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r),
			Vector2(rect.position.x + r, rect.end.y - r), rect.end - Vector2(r, r)]:
		ci.draw_circle(corner, r, color)


static func type_color(type: int) -> Color:
	return TYPE_COLORS[type] if type >= 0 and type < TYPE_COLORS.size() else Color.GRAY


static func hp_color(ratio: float) -> Color:
	return HP_GREEN if ratio > 0.5 else (HP_YELLOW if ratio > 0.2 else HP_RED)


## Polygone d'un panneau aux coins coupés ; `slant` : biseau du côté gauche (négatif)
## ou droit (positif), en pixels.
static func panel_points(rect: Rect2, cut := 3.0, slant := 0.0) -> PackedVector2Array:
	var l := rect.position.x
	var t := rect.position.y
	var r := rect.end.x
	var b := rect.end.y
	var right_bottom := r - maxf(slant, 0.0)
	var left_bottom := l + maxf(-slant, 0.0)
	return PackedVector2Array([
		Vector2(l + cut, t), Vector2(r - cut, t), Vector2(r, t + cut),
		Vector2(right_bottom, b - cut), Vector2(right_bottom - cut, b),
		Vector2(left_bottom + cut, b), Vector2(left_bottom, b - cut), Vector2(l, t + cut),
	])


## Panneau DS : ombre portée, contour sombre, fond, bande claire en haut.
static func draw_panel(ci: CanvasItem, rect: Rect2, fill: Color, slant := 0.0, shadow := true) -> void:
	if shadow:
		ci.draw_colored_polygon(panel_points(Rect2(rect.position + Vector2(2, 2), rect.size), 3, slant), Color(0, 0, 0, 0.25))
	ci.draw_colored_polygon(panel_points(rect, 3, slant), OUTLINE)
	ci.draw_colored_polygon(panel_points(rect.grow(-2), 2, slant), fill.darkened(0.12))
	ci.draw_colored_polygon(panel_points(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, rect.size.y - 6)), 2, slant), fill)
	ci.draw_rect(Rect2(rect.position + Vector2(4, 3), Vector2(rect.size.x - 8 - absf(slant), 1)), fill.lightened(0.45))


## Barre de PV : cadre sombre, étiquette « PV », remplissage coloré avec reflet.
static func draw_hp_bar(ci: CanvasItem, origin: Vector2, width: float, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	ci.draw_rect(Rect2(origin, Vector2(width + 20, 7)), OUTLINE)
	ci.draw_rect(Rect2(origin + Vector2(1, 1), Vector2(16, 5)), HP_YELLOW.darkened(0.15))
	_draw_tiny_text(ci, origin + Vector2(3, 2), "PV")
	var bar := Rect2(origin + Vector2(18, 1), Vector2(width, 5))
	ci.draw_rect(bar, HP_EMPTY)
	if ratio > 0.0:
		var filled := Rect2(bar.position, Vector2(maxf(1.0, ceilf(width * ratio)), 5))
		var color := hp_color(ratio)
		ci.draw_rect(filled, color)
		ci.draw_rect(Rect2(filled.position, Vector2(filled.size.x, 1)), color.lightened(0.45))
		ci.draw_rect(Rect2(filled.position + Vector2(0, 4), Vector2(filled.size.x, 1)), color.darkened(0.25))


## Lettres « P » et « V » de 3x3 pixels (la police du jeu est trop grande ici).
static func _draw_tiny_text(ci: CanvasItem, origin: Vector2, _text: String) -> void:
	var c := OUTLINE
	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0, 2)]:
		ci.draw_rect(Rect2(origin + p, Vector2.ONE), c)
	for p in [Vector2(4, 0), Vector2(6, 0), Vector2(4, 1), Vector2(6, 1), Vector2(5, 2)]:
		ci.draw_rect(Rect2(origin + p, Vector2.ONE), c)
