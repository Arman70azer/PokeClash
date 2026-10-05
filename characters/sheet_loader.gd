class_name SheetLoader
extends RefCounted
## Charge les planches de personnages (data/characters/<nom>.tres) et les prépare pour
## l'affichage : fond rendu transparent, pieds mesurés pour les aligner sur l'ombre.
## Tout est calculé une seule fois par personnage puis gardé en mémoire.

const DIR := "res://data/characters/"
const FALLBACK := "ethan"

## Nombre de lignes vides laissées sous les pieds de la pose de repos, pour tous les
## personnages et toutes les directions. Les planches n'ont pas toutes la même marge :
## sans cet alignement, certains personnages paraissent flotter au-dessus de leur ombre.
const FEET_MARGIN := 2

static var _sheets := {}  # nom -> CharacterSheet
static var _images := {}  # nom -> Image détourée
static var _textures := {}  # nom -> texture détourée
static var _feet_shift := {}  # nom -> {direction -> décalage vertical en pixels}
static var _feet_center := {}  # nom -> {direction -> centre des pieds, en pixels depuis l'axe du sprite}
static var _vision_points := {}  # (nom, rectangle, décalage) -> points opaques


## Vrai si ce personnage existe.
static func exists(sheet_id: String) -> bool:
	return _sheets.has(sheet_id) or ResourceLoader.exists(DIR + sheet_id + ".tres")


## Description du personnage, ou celle du personnage par défaut s'il n'existe pas.
static func sheet(sheet_id: String) -> CharacterSheet:
	if not exists(sheet_id):
		push_warning("SheetLoader : personnage inconnu « %s »" % sheet_id)
		sheet_id = FALLBACK
	if not _sheets.has(sheet_id):
		_sheets[sheet_id] = load(DIR + sheet_id + ".tres")
	return _sheets[sheet_id]


## {direction: [3 rectangles]}, en pixels sur texture().
static func frames(sheet_id: String) -> Dictionary:
	return sheet(sheet_id).frames()


## Planche détourée (seulement la partie utilisée par ce personnage).
static func texture(sheet_id: String) -> Texture2D:
	_prepare(sheet_id)
	return _textures[sheet_id]


static func image(sheet_id: String) -> Image:
	_prepare(sheet_id)
	return _images[sheet_id]


static func feet_shift(sheet_id: String, facing: Vector2i) -> int:
	_prepare(sheet_id)
	return _feet_shift[sheet_id][facing]


static func feet_center(sheet_id: String, facing: Vector2i) -> float:
	_prepare(sheet_id)
	return _feet_center[sheet_id][facing]


## Pixels opaques d'une image, un sur trois en largeur et en hauteur, en pixels par
## rapport aux pieds : (décalage horizontal, hauteur au-dessus des pieds).
static func vision_points(sheet_id: String, rect: Rect2, shift: int) -> Array[Vector2]:
	var key := [sheet_id, rect, shift]
	if not _vision_points.has(key):
		var img := image(sheet_id)
		var r := Rect2i(rect)
		var points: Array[Vector2] = []
		for py in range(1, r.size.y, 3):
			for px in range(1, r.size.x, 3):
				if img.get_pixel(r.position.x + px, r.position.y + py).a > 0.5:
					points.append(Vector2(px + 0.5 - r.size.x / 2.0, r.size.y - py - 0.5 - shift))
		_vision_points[key] = points
	return _vision_points[key]


static func _prepare(sheet_id: String) -> void:
	if _textures.has(sheet_id):
		return
	var def := sheet(sheet_id)
	var img := def.texture.get_image().get_region(def.source_region())
	img.convert(Image.FORMAT_RGBA8)
	_clear_color(img, Rect2i(Vector2i.ZERO, img.get_size()), def.background)
	var frames := def.frames()
	if def.layout == CharacterSheet.Layout.DS_TRAINER_CELL:
		# La grille de la planche n'étant pas régulière, le bord d'une image peut mordre
		# sur le fond de la case voisine : on efface ces traits de couleur.
		for i in 12:
			_clear_border_lines(img, Rect2i(Vector2i(i % 3, i / 3) * 32, Vector2i(32, 32)))
	_images[sheet_id] = img
	_textures[sheet_id] = ImageTexture.create_from_image(img)
	_feet_shift[sheet_id] = _measure_feet(img, frames)
	_feet_center[sheet_id] = _measure_feet_center(img, frames)


## Rend transparents les pixels de la couleur `key` dans le rectangle donné.
static func _clear_color(img: Image, rect: Rect2i, key: Color) -> void:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).is_equal_approx(key):
				img.set_pixel(x, y, Color(0, 0, 0, 0))


## Efface les lignes près du bord de l'image `rect` presque entièrement couvertes d'une
## seule couleur : c'est le fond d'une case voisine, jamais le personnage.
static func _clear_border_lines(img: Image, rect: Rect2i) -> void:
	# Le trait peut être un peu en retrait du bord : on regarde les trois lignes extérieures.
	var lines: Array[Array] = []
	for d in 3:
		var sides: Array[Array] = [[], [], [], []]
		for k in 32:
			sides[0].append(rect.position + Vector2i(k, d))
			sides[1].append(rect.position + Vector2i(k, 31 - d))
			sides[2].append(rect.position + Vector2i(d, k))
			sides[3].append(rect.position + Vector2i(31 - d, k))
		lines.append_array(sides)
	for line in lines:
		var colors := {}
		for p: Vector2i in line:
			var c := img.get_pixelv(p)
			if c.a > 0.5:
				colors[c] = colors.get(c, 0) + 1
		for c: Color in colors:
			if colors[c] >= 24:
				for p: Vector2i in line:
					if img.get_pixelv(p).is_equal_approx(c):
						img.set_pixelv(p, Color(0, 0, 0, 0))
	# Restent parfois quelques pixels isolés (coin d'un trait) : on les efface aussi.
	var stray: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).a > 0.5 and not _has_neighbor(img, Vector2i(x, y), rect):
				stray.append(Vector2i(x, y))
	for p in stray:
		img.set_pixelv(p, Color(0, 0, 0, 0))


static func _has_neighbor(img: Image, p: Vector2i, rect: Rect2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := p + Vector2i(dx, dy)
			if q != p and rect.has_point(q) and img.get_pixelv(q).a > 0.5:
				return true
	return false


## Pour chaque direction, mesure la marge vide sous les pieds de la pose de repos et
## renvoie de combien de pixels descendre le sprite pour la ramener à FEET_MARGIN.
static func _measure_feet(img: Image, frames: Dictionary) -> Dictionary:
	var shifts := {}
	for facing in frames:
		var rect: Rect2 = frames[facing][CharacterSprite.IDLE_FRAME]
		var margin := 0
		for y in range(int(rect.end.y) - 1, int(rect.position.y) - 1, -1):
			var empty := true
			for x in range(int(rect.position.x), int(rect.end.x)):
				if img.get_pixel(x, y).a > 0.0:
					empty = false
					break
			if not empty:
				break
			margin += 1
		shifts[facing] = margin - FEET_MARGIN
	return shifts


## Pour chaque direction, position horizontale du milieu des pieds de la pose de repos,
## en pixels depuis l'axe du sprite. Arrondie au demi-pixel : l'ombre a une largeur
## impaire, son centre doit donc tomber entre deux pixels pour rester nette.
static func _measure_feet_center(img: Image, frames: Dictionary) -> Dictionary:
	var centers := {}
	for facing in frames:
		var rect: Rect2 = frames[facing][CharacterSprite.IDLE_FRAME]
		var left := -1
		var right := -1
		var rows := 0
		# Les 3 lignes dessinées les plus basses : les pieds.
		for y in range(int(rect.end.y) - 1, int(rect.position.y) - 1, -1):
			var found := false
			for x in range(int(rect.position.x), int(rect.end.x)):
				if img.get_pixel(x, y).a > 0.0:
					found = true
					if left == -1 or x < left:
						left = x
					if x > right:
						right = x
			if found:
				rows += 1
				if rows == 3:
					break
		var center := 0.0
		if left != -1:
			center = (left + right + 1) / 2.0 - rect.get_center().x
		centers[facing] = floorf(center) + 0.5
	return centers
