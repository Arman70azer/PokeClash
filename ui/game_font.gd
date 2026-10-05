class_name GameFont
extends RefCounted
## Police du jeu, construite en mémoire à partir de la planche assets/Font_Poke.png.
## On utilise le panneau blanc de la planche (lettres sombres) : cases de 16x16 pixels,
## 49 caractères par ligne. La largeur de chaque lettre est mesurée sur son dessin,
## ce qui donne une police à chasse variable. Les lettres étant déjà colorées,
## le texte doit garder la couleur blanche (pas de teinte) pour s'afficher tel quel.

const SHEET := "res://assets/Font_Poke.png"
## Coin haut-gauche de la première case du panneau blanc.
const ORIGIN := Vector2i(24, 192)
const CELL := 16
const COLUMNS := 49
const ASCENT := 13
const SPACE_ADVANCE := 4
## Caractère qui marque, dans ROWS, une case de la planche à ignorer.
const SKIP := "¤"

## Caractères de chaque ligne du panneau, dans l'ordre. "¤" = case ignorée.
const ROWS: Array[String] = [
	"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklm",
	"nopqrstuvwxyzÀÁÂÄÇÈÉÊËÌÍÎÏÑÒÓÔÖ×ÙÚÛÜßàáâä¤çèéêëìí",
	"îïñòóôö÷ùúûüŒœªº¤¤¤¤¡¿!?,.…·/‘’“”„«»()♂♀+-*#=&~:;",
]
## Caractères courants absents de la planche, affichés avec un caractère proche.
const ALIASES := {"'": "’", "\"": "”", "−": "-", "–": "-", "—": "-"}

## Couleurs des lettres sur la planche (trait, ombre) et leur version claire, pour écrire
## sur un fond sombre : lettres blanches à ombre foncée, comme dans les menus des jeux.
const INK := Color8(82, 82, 90)
const INK_SHADOW := Color8(165, 165, 173)
const LIGHT_INK := Color8(248, 248, 248)
const LIGHT_SHADOW := Color8(64, 64, 72)

static var _font: FontFile
static var _light_font: FontFile
static var _theme: Theme
static var _light_theme: Theme


static func get_font() -> FontFile:
	if _font == null:
		_font = _build()
	return _font


## Police à lettres blanches, pour les fonds sombres.
static func get_light_font() -> FontFile:
	if _light_font == null:
		_light_font = _build(true)
	return _light_font


## Thème pour écrire sur un fond sombre (lettres blanches).
static func get_light_theme() -> Theme:
	if _light_theme == null:
		_light_theme = get_theme().duplicate()
		_light_theme.default_font = get_light_font()
	return _light_theme


## Thème clair commun au menu et aux dialogues, avec la police du jeu.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme := Theme.new()
	theme.default_font = get_font()
	theme.default_font_size = CELL

	var panel := _box(Color(0.97, 0.97, 0.94), Color(0.2, 0.25, 0.4), 6)
	theme.set_stylebox("panel", "PanelContainer", panel)

	theme.set_stylebox("normal", "Button", _box(Color(0.9, 0.92, 0.96), Color(0.2, 0.25, 0.4), 3))
	theme.set_stylebox("hover", "Button", _box(Color(0.8, 0.88, 1.0), Color(0.2, 0.25, 0.4), 3))
	theme.set_stylebox("pressed", "Button", _box(Color(0.7, 0.8, 0.98), Color(0.2, 0.25, 0.4), 3))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(0.9, 0.5, 0.2), 3))
	theme.set_stylebox("normal", "LineEdit", _box(Color.WHITE, Color(0.6, 0.62, 0.7), 3))
	theme.set_stylebox("focus", "LineEdit", _box(Color(0, 0, 0, 0), Color(0.9, 0.5, 0.2), 3))
	theme.set_color("caret_color", "LineEdit", Color(0.2, 0.25, 0.4))
	# Les lettres sont déjà colorées dans la planche : aucune teinte, quel que soit l'état.
	for type in ["Label", "LineEdit"]:
		theme.set_color("font_color", type, Color.WHITE)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color_name, "Button", Color.WHITE)
	theme.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.5))
	_theme = theme
	return _theme


static func _box(bg: Color, border: Color, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(margin)
	return style


static func _build(light := false) -> FontFile:
	var source: Texture2D = load(SHEET)
	var sheet := source.get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	# Une ligne de plus que le texte : sa dernière case, vide, sert de dessin à l'espace.
	var panel := sheet.get_region(Rect2i(ORIGIN, Vector2i(COLUMNS * CELL, (ROWS.size() + 1) * CELL)))
	# Le fond blanc du panneau devient transparent.
	for y in panel.get_height():
		for x in panel.get_width():
			var c := panel.get_pixel(x, y)
			if c.is_equal_approx(Color.WHITE):
				panel.set_pixel(x, y, Color(0, 0, 0, 0))
			elif light and c.is_equal_approx(INK):
				panel.set_pixel(x, y, LIGHT_INK)
			elif light and c.is_equal_approx(INK_SHADOW):
				panel.set_pixel(x, y, LIGHT_SHADOW)

	var font := FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.hinting = TextServer.HINTING_NONE
	font.fixed_size = CELL
	var size := Vector2i(CELL, 0)
	font.set_texture_image(0, size, 0, panel)
	font.set_cache_ascent(0, CELL, ASCENT)
	font.set_cache_descent(0, CELL, CELL - ASCENT)

	var rects := {}
	for row in ROWS.size():
		var chars := ROWS[row]
		for col in chars.length():
			var ch := chars[col]
			if ch == SKIP:
				continue
			var rect := _ink_rect(panel, col, row)
			if rect.size.x > 0:
				rects[ch] = rect
				_add_glyph(font, size, ch.unicode_at(0), rect, rect.size.x + 1)
	for alias in ALIASES:
		var target: String = ALIASES[alias]
		if rects.has(target):
			var rect: Rect2 = rects[target]
			_add_glyph(font, size, alias.unicode_at(0), rect, int(rect.size.x) + 1)
	# Espace : un morceau vide de la planche.
	var blank := Rect2((COLUMNS - 1) * CELL, ROWS.size() * CELL, 1, CELL)
	_add_glyph(font, size, " ".unicode_at(0), blank, SPACE_ADVANCE)
	return font


## Zone réellement dessinée d'une case : toute la hauteur, largeur ajustée au dessin.
static func _ink_rect(panel: Image, col: int, row: int) -> Rect2:
	var x0 := -1
	var x1 := -1
	for x in CELL:
		for y in CELL:
			if panel.get_pixel(col * CELL + x, row * CELL + y).a > 0.0:
				if x0 == -1:
					x0 = x
				x1 = x
				break
	if x0 == -1:
		return Rect2()
	return Rect2(col * CELL + x0, row * CELL, x1 - x0 + 1, CELL)


static func _add_glyph(font: FontFile, size: Vector2i, code: int, rect: Rect2, advance: int) -> void:
	font.set_glyph_advance(0, size.x, code, Vector2(advance, 0))
	font.set_glyph_offset(0, size, code, Vector2(0, -ASCENT))
	font.set_glyph_size(0, size, code, rect.size)
	font.set_glyph_uv_rect(0, size, code, rect)
	font.set_glyph_texture_idx(0, size, code, 0)
