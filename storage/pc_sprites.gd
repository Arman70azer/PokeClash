class_name PcSprites
extends RefCounted
## Fonds des boîtes du PC : la planche des fonds de boîte de Noir et Blanc (24 fonds de
## 168 × 142 pixels : un bandeau de titre de 19 pixels, puis la boîte). Découpe faite une
## fois puis gardée en mémoire (voir BattleSprites.cut).

const SHEET := "res://assets/DS _ DSi - Pokemon Black _ White - Miscellaneous - Box Backgrounds.png"
const BACKGROUND := Color8(168, 176, 248)
const WALLPAPER_COUNT := 24
const COLUMNS := 4
const ORIGIN := Vector2i(4, 11)
const STEP := Vector2i(172, 164)
## Taille d'un fond, bandeau compris, et hauteur du bandeau de titre.
const SIZE := Vector2i(168, 142)
const TITLE_HEIGHT := 19
## Haut de la boîte elle-même, sous le bandeau.
const BODY_TOP := 21
const NAMES := [
	"Forêt", "Ville", "Désert", "Savane", "Grotte", "Volcan", "Neige", "Rocher",
	"Plage", "Océan", "Rivière", "Ciel", "Poké Ball", "Acier", "Damier", "Simple",
	"Blanc", "Noir", "Contraste", "Blason", "Fleurs", "Lumière", "Carte", "Scène",
]


static func wallpaper(index: int) -> Texture2D:
	index = posmod(index, WALLPAPER_COUNT)
	var cell := Vector2i(index % COLUMNS, index / COLUMNS)
	return BattleSprites.cut(BattleSprites.load_sheet(SHEET), Rect2i(ORIGIN + cell * STEP, SIZE), [BACKGROUND])


static func wallpaper_name(index: int) -> String:
	return NAMES[posmod(index, WALLPAPER_COUNT)]


## Zones d'un fond à l'intérieur de son cadre gris de DS : le petit paysage du bandeau de
## titre (affiché tel quel) et le motif de la boîte (étendu par répétition à la taille de
## la boîte du jeu).
const TITLE_PATTERN := Rect2i(28, 0, 112, 19)
const BODY_PATTERN := Rect2i(6, 27, 156, 115)

static var _styles := {}


## Petit paysage du bandeau de titre d'un fond, à sa taille d'origine.
static func title(index: int) -> Texture2D:
	index = posmod(index, WALLPAPER_COUNT)
	var cell := Vector2i(index % COLUMNS, index / COLUMNS)
	return BattleSprites.cut(BattleSprites.load_sheet(SHEET), Rect2i(ORIGIN + cell * STEP + TITLE_PATTERN.position, TITLE_PATTERN.size), [BACKGROUND])


## Motif d'un fond, étirable (bord de 2 pixels gardé, milieu répété).
static func body_style(index: int) -> StyleBoxTexture:
	return _style(index, BODY_PATTERN, Vector4i(2, 2, 2, 2))


static func _style(index: int, part: Rect2i, margins: Vector4i) -> StyleBoxTexture:
	index = posmod(index, WALLPAPER_COUNT)
	var key := "%d|%s" % [index, part]
	if not _styles.has(key):
		var cell := Vector2i(index % COLUMNS, index / COLUMNS)
		var region := Rect2i(ORIGIN + cell * STEP + part.position, part.size)
		var style := StyleBoxTexture.new()
		style.texture = BattleSprites.cut(BattleSprites.load_sheet(SHEET), region, [BACKGROUND])
		style.texture_margin_left = margins.x
		style.texture_margin_top = margins.y
		style.texture_margin_right = margins.z
		style.texture_margin_bottom = margins.w
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		_styles[key] = style
	return _styles[key]
