class_name MenuSprites
extends RefCounted
## Images du menu du jeu, découpées dans les planches d'interface de assets/ (voir
## BattleSprites.cut : découpe faite une fois puis gardée en mémoire).

## Panneaux de l'écran d'équipe de Noir et Blanc : 126 × 46 pixels, sur fond vert anis.
const PARTY_SHEET := "res://assets/DS _ DSi - Pokemon Black _ White - Miscellaneous - Party Screen.png"
const PARTY_BACKGROUND := Color8(160, 234, 0)
const PARTY_PANELS := {
	&"normal": Rect2i(5, 201, 126, 46),
	&"selected": Rect2i(133, 201, 126, 46),
	&"fainted": Rect2i(5, 249, 126, 46),
	&"fainted_selected": Rect2i(133, 249, 126, 46),
	&"empty": Rect2i(5, 345, 126, 46),
}
## Bords des panneaux qui ne s'étirent pas quand on les redimensionne.
const PARTY_PANEL_MARGIN := Vector4i(10, 8, 10, 8)

## Étiquettes de type et de statut de Noir et Blanc.
const ICONS_SHEET := "res://assets/DS _ DSi - Pokemon Black _ White - Miscellaneous - Miscellaneous Icons.png"
const ICONS_BACKGROUND := Color8(66, 66, 255)
## Rang de chaque type (ordre de PokemonType.Type) dans la colonne d'étiquettes.
const TYPE_ROWS := [0, 3, 2, 4, 1, 14, 10, 9, 7, 6, 11, 5, 8, 13, 16, 12, 15]
const TYPE_LABEL := Rect2i(73, 5, 32, 12)
const TYPE_STEP := 15
## Le type Fée n'a pas d'étiquette dans Noir et Blanc : on l'assemble avec les lettres des
## autres étiquettes (F, I, R de FIRE, A de DARK, Y de FLYING), sur un fond rose.
## [type de l'étiquette source, première colonne, largeur] pour chaque lettre de FAIRY.
const FAIRY_LETTERS := [
	[PokemonType.Type.FIRE, 5, 5], [PokemonType.Type.DARK, 11, 5], [PokemonType.Type.FIRE, 11, 4],
	[PokemonType.Type.FIRE, 16, 5], [PokemonType.Type.FLYING, 11, 6],
]
const FAIRY_FILL := Color8(238, 153, 172)
const FAIRY_BORDER := Color8(140, 64, 96)
const LABEL_TEXT := [Color8(255, 255, 255), Color8(82, 82, 82)]
## Statuts : empoisonné, brûlé, paralysé, gelé, K.O. (pas d'étiquette pour le sommeil).
const STATUS_ROWS := {&"poison": 0, &"toxic": 0, &"burn": 1, &"paralysis": 2, &"freeze": 3, &"fainted": 4}
const STATUS_LABEL := Rect2i(79, 311, 19, 6)
const STATUS_STEP := 9

## Sacoche de Noir 2 et Blanc 2 (version garçon, bleue) : fermée et ouverte.
const BAGS_SHEET := "res://assets/DS _ DSi - Pokemon Black 2 _ White 2 - Miscellaneous - Bags.png"
const BAGS_BACKGROUND := Color8(157, 185, 235)
const BAG_CLOSED := Rect2i(614, 18, 38, 55)
const BAG_OPEN := Rect2i(738, 11, 45, 63)

static var _styles := {}
static var _keyed := {}  # "planche|zone" -> icône découpée


## Panneau d'équipe, redimensionnable sans abîmer ses bords.
static func party_panel(kind: StringName) -> StyleBoxTexture:
	if not _styles.has(kind):
		var style := StyleBoxTexture.new()
		style.texture = BattleSprites.cut(BattleSprites.load_sheet(PARTY_SHEET), PARTY_PANELS[kind], [PARTY_BACKGROUND])
		style.texture_margin_left = PARTY_PANEL_MARGIN.x
		style.texture_margin_top = PARTY_PANEL_MARGIN.y
		style.texture_margin_right = PARTY_PANEL_MARGIN.z
		style.texture_margin_bottom = PARTY_PANEL_MARGIN.w
		_styles[kind] = style
	return _styles[kind]


## Icône de menu d'une espèce, ou null si elle n'en a pas.
static func pokemon_icon(species: PokemonSpecies) -> Texture2D:
	if species == null or species.icon_sheet == null or species.icon_region.size == Vector2i.ZERO:
		return null
	return _cut_keyed(species.icon_sheet, species.icon_region)


## Icône d'un objet du sac, ou null.
static func item_icon(item: ItemData) -> Texture2D:
	if item == null or item.icon_sheet == null or item.icon_region.size == Vector2i.ZERO:
		return null
	return _cut_keyed(item.icon_sheet, item.icon_region)


static func type_label(type: int) -> Texture2D:
	if type == PokemonType.Type.FAIRY:
		return _fairy_label()
	if type < 0 or type >= TYPE_ROWS.size():
		return null
	var region := TYPE_LABEL
	region.position.y += TYPE_ROWS[type] * TYPE_STEP
	return BattleSprites.cut(BattleSprites.load_sheet(ICONS_SHEET), region, [ICONS_BACKGROUND])


static func _fairy_label() -> Texture2D:
	if _keyed.has(&"fairy_label"):
		return _keyed[&"fairy_label"]
	var label := Image.create(TYPE_LABEL.size.x, TYPE_LABEL.size.y, false, Image.FORMAT_RGBA8)
	label.fill(FAIRY_BORDER)
	label.fill_rect(Rect2i(Vector2i.ONE, TYPE_LABEL.size - Vector2i(2, 2)), FAIRY_FILL)
	var width := -1
	for letter in FAIRY_LETTERS:
		width += letter[2] + 1
	var x := (TYPE_LABEL.size.x - width) / 2
	for letter in FAIRY_LETTERS:
		var source := type_label(letter[0]).get_image()
		for dx in letter[2]:
			for y in range(2, TYPE_LABEL.size.y - 2):
				var color := source.get_pixel(letter[1] + dx, y)
				if LABEL_TEXT.any(func(c: Color) -> bool: return c.is_equal_approx(color)):
					label.set_pixel(x + dx, y, color)
		x += letter[2] + 1
	var texture := ImageTexture.create_from_image(label)
	_keyed[&"fairy_label"] = texture
	return texture


## Étiquette de statut (PSN, BRN…), ou null s'il n'y en a pas pour ce statut.
static func status_label(status: StringName) -> Texture2D:
	if not STATUS_ROWS.has(status):
		return null
	var region := STATUS_LABEL
	region.position.y += STATUS_ROWS[status] * STATUS_STEP
	return BattleSprites.cut(BattleSprites.load_sheet(ICONS_SHEET), region, [ICONS_BACKGROUND])


static func bag(open: bool) -> Texture2D:
	return BattleSprites.cut(BattleSprites.load_sheet(BAGS_SHEET), BAG_OPEN if open else BAG_CLOSED, [BAGS_BACKGROUND])


## Zone d'une planche dont la couleur du coin haut-gauche (le fond de la case) devient
## transparente.
static func _cut_keyed(sheet: Texture2D, region: Rect2i) -> Texture2D:
	var id := "%s|%s" % [sheet.resource_path, region]
	if not _keyed.has(id):
		var corner := BattleSprites.cut(sheet, Rect2i(region.position, Vector2i.ONE))
		var background := corner.get_image().get_pixel(0, 0) if corner != null else Color.TRANSPARENT
		_keyed[id] = BattleSprites.cut(sheet, region, [background])
	return _keyed[id]
