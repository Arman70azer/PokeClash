class_name BattleSprites
extends RefCounted
## Découpe des images de combat dans les planches de assets/ : une zone de la planche,
## dont les couleurs de fond deviennent transparentes. Chaque découpe est faite une
## fois puis gardée en mémoire.

## Planches d'interface (assets/) et zones utilisées.
const BASES_SHEET := "res://assets/Miscellaneous - Battle Bases.png"
const TEXT_BOXES_SHEET := "res://assets/Miscellaneous - Text Boxes.png"
const TRAINERS_BACK_SHEET := "res://assets/Trainers - Trainers (Back).png"
const BASE_BACKGROUND := Color8(248, 248, 248)
## Socles « herbe » : grand (côté joueur) et petit (côté adversaire).
const GRASS_BASE_PLAYER := Rect2i(8, 16, 256, 32)
const GRASS_BASE_OPPONENT := Rect2i(272, 8, 128, 64)
## Premier cadre de boîte de texte de la planche.
const TEXT_BOX := Rect2i(2, 2, 254, 48)
## Ethan de dos : les cinq images du lancer de Poké Ball, de gauche à droite.
const PLAYER_BACK := Rect2i(1, 18, 80, 80)
const PLAYER_BACK_FRAMES := 5
const PLAYER_BACK_STEP := 81
const SHEET_BACKGROUNDS: Array[Color] = [Color8(147, 187, 236), Color8(84, 165, 75)]

## Planche « Battle HUD » (interface de Noir et Blanc) : barres de PV, chiffres, boutons.
const HUD_SHEET := "res://assets/Battle HUD.png"
const HUD_BACKGROUND := Color8(189, 189, 231)
## Barre de l'adversaire (flèche vers la droite) et du joueur (flèche vers la gauche,
## partie sombre des PV et barre d'expérience), avec leur icône « Lv. ».
const HUD_OPPONENT_STRIP := Rect2i(617, 22, 125, 17)
const HUD_PLAYER_STRIP := Rect2i(617, 44, 120, 25)
## Emplacement de la jauge dans chaque barre, relatif à la barre.
const HUD_OPPONENT_GAUGE := Rect2i(44, 10, 48, 2)
const HUD_PLAYER_GAUGE := Rect2i(56, 9, 48, 2)
const HUD_PLAYER_EXP := Rect2i(32, 23, 80, 1)
## Couleurs de la jauge (claire, foncée) : vert, jaune, rouge.
const HUD_GAUGE_COLORS := [
	[Color8(0, 255, 74), Color8(0, 189, 33)],
	[Color8(234, 255, 0), Color8(173, 189, 0)],
	[Color8(255, 0, 0), Color8(189, 0, 0)],
]
## Chiffres 0 à 9 (blancs cernés de noir) : abscisse et largeur de chacun, ligne 97.
const HUD_DIGITS := [[516, 5], [522, 4], [527, 5], [533, 5], [539, 5], [545, 5], [551, 5], [557, 5], [563, 5], [569, 5]]
const HUD_DIGIT_Y := 97
const HUD_DIGIT_HEIGHT := 9
## Boutons du menu de combat.
const HUD_FIGHT_DOME := Rect2i(206, 52, 100, 56)
const HUD_FIGHT_TEXT := Rect2i(515, 186, 56, 12)
const HUD_BAG := Rect2i(518, 219, 78, 60)
const HUD_RUN := Rect2i(608, 235, 76, 44)
const HUD_POKEMON := Rect2i(696, 219, 78, 60)
## Fond sombre de l'écran tactile, autour de la grande Poké Ball.
const HUD_PANEL := Color8(74, 57, 57)
const HUD_PANEL_DARK := Color8(49, 36, 36)

static var _images := {}    # chemin -> Image de la planche
static var _textures := {}  # clé -> ImageTexture découpée


## Zone `region` de la planche `sheet`, couleurs `transparent` rendues transparentes.
static func cut(sheet: Texture2D, region: Rect2i, transparent: Array[Color] = []) -> Texture2D:
	if sheet == null:
		push_error("BattleSprites : planche manquante")
		return null
	var key := "%s|%s|%s" % [sheet.resource_path, region, transparent]
	if _textures.has(key):
		return _textures[key]
	if not _images.has(sheet.resource_path):
		var full := sheet.get_image()
		if full.is_compressed():
			full.decompress()
		full.convert(Image.FORMAT_RGBA8)
		_images[sheet.resource_path] = full
	var source: Image = _images[sheet.resource_path]
	if not Rect2i(Vector2i.ZERO, source.get_size()).encloses(region):
		push_error("BattleSprites : la zone %s sort de la planche %s" % [region, sheet.resource_path])
		return null
	var img := source.get_region(region)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			for t in transparent:
				if c.is_equal_approx(t):
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					break
	var texture := ImageTexture.create_from_image(img)
	_textures[key] = texture
	return texture


## Zone réellement dessinée d'une image (pixels non transparents), en pixels.
static func opaque_bounds(texture: Texture2D) -> Rect2i:
	var key := "bounds|%s" % texture.get_instance_id()
	if _textures.has(key):
		return _textures[key]
	var img := texture.get_image()
	var bounds := img.get_used_rect()
	_textures[key] = bounds
	return bounds


static func load_sheet(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("BattleSprites : image introuvable %s" % path)
	return texture


## Sprite de combat d'une espèce : de face (adversaire) ou de dos (Pokémon du joueur).
## `frame` : 0 ou 1 (deuxième image d'animation, si la planche en a une).
static func pokemon(species: PokemonSpecies, back: bool, frame := 0) -> Texture2D:
	if species == null:
		return null
	if species.battle_sheet == null:
		return _stand_in(species)
	var region := species.back_region if back else species.front_region
	if frame > 0 and species.animation_frame_offset != Vector2i.ZERO:
		region.position += species.animation_frame_offset * frame
	return cut(species.battle_sheet, region, species.sheet_background_colors)


## Espèce sans sprites de combat (pas encore dans les planches de assets/) : son icône de
## menu agrandie deux fois, en attendant.
static func _stand_in(species: PokemonSpecies) -> Texture2D:
	var key := "stand_in|%s" % species.id
	if not _textures.has(key):
		var icon := MenuSprites.pokemon_icon(species)
		if icon == null:
			return null
		var image := icon.get_image()
		image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
		_textures[key] = ImageTexture.create_from_image(image)
	return _textures[key]


static func trainer(trainer_data: TrainerData) -> Texture2D:
	if trainer_data == null or trainer_data.battle_sheet == null:
		return null
	return cut(trainer_data.battle_sheet, trainer_data.front_region, trainer_data.sheet_background_colors)


static func base(for_player: bool) -> Texture2D:
	var colors: Array[Color] = [BASE_BACKGROUND]
	return cut(load_sheet(BASES_SHEET), GRASS_BASE_PLAYER if for_player else GRASS_BASE_OPPONENT, colors)


## Ethan de dos ; `frame` de 0 (immobile) à 4 (Poké Ball lancée).
static func player_back(frame := 0) -> Texture2D:
	var region := PLAYER_BACK
	region.position.x += PLAYER_BACK_STEP * clampi(frame, 0, PLAYER_BACK_FRAMES - 1)
	return cut(load_sheet(TRAINERS_BACK_SHEET), region, SHEET_BACKGROUNDS)


static func text_box() -> Texture2D:
	return cut(load_sheet(TEXT_BOXES_SHEET), TEXT_BOX)


## Élément de la planche Battle HUD, fond transparent.
static func hud(region: Rect2i) -> Texture2D:
	var colors: Array[Color] = [HUD_BACKGROUND]
	return cut(load_sheet(HUD_SHEET), region, colors)


## Chiffre `digit` (0 à 9) de la police du HUD.
static func hud_digit(digit: int) -> Texture2D:
	var d: Array = HUD_DIGITS[clampi(digit, 0, 9)]
	return hud(Rect2i(d[0], HUD_DIGIT_Y, d[1], HUD_DIGIT_HEIGHT))
