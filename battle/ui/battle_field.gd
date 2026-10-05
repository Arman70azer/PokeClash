class_name BattleField
extends Control
## Le terrain du combat : fond, socles, dresseurs et Pokémon, avec leurs animations
## (arrivée des dresseurs, lancer de Poké Ball, apparition, respiration, attaque, coup
## reçu, K.O....) et la couche d'effets (BattleEffects). Aucune logique de combat ici :
## la scène appelle ces animations en lisant les évènements du moteur.
##
## Le fond est dessiné en code : ciel en bandes, nuages et collines en gros pixels.

const SKY := [Color8(120, 184, 240), Color8(144, 200, 248), Color8(168, 216, 248), Color8(200, 232, 248)]
const CLOUD := Color8(248, 252, 255)
const CLOUD_SHADE := Color8(216, 232, 248)
const HILLS_FAR := Color8(136, 200, 136)
const HILLS_NEAR := Color8(96, 176, 96)
const GROUND := Color8(160, 216, 120)
const GRASS_DARK := Color8(104, 176, 80)
const GRASS_LIGHT := Color8(192, 232, 144)
const HORIZON := 92.0

## Positions (pixels de l'écran de jeu) : socle et sprite de chaque camp.
const PLAYER_BASE := Vector2(-16, 170)
const PLAYER_SPRITE := Vector2(44, 124)
const OPPONENT_BASE := Vector2(196, 66)
const OPPONENT_SPRITE := Vector2(220, 30)
## Pokémon adverse : centré sur son socle, pieds sur le milieu de l'ellipse.
const OPPONENT_FEET := Vector2(260, 102)
## Centre visuel de chaque Pokémon (cible des effets).
const CENTERS := [Vector2(84, 168), Vector2(260, 74)]
## Pieds de chaque Pokémon, là où tombe la Poké Ball.
const LANDING := [Vector2(84, 196), Vector2(260, 100)]

var effects: BattleEffects
var _bases: Array[TextureRect] = []
var _pokemon: Array[TextureRect] = []
var _trainers: Array[TextureRect] = []
var _species: Array[PokemonSpecies] = [null, null]
## Respiration de chaque Pokémon : active hors des autres animations.
var _idle := [false, false]
var _time := 0.0
var _ball: Control
## Place de chaque Pokémon au repos (calculée d'après son sprite pour l'adversaire).
var _rest := [PLAYER_SPRITE, OPPONENT_SPRITE]
var _ball_spin := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_bases.append(_add_texture(BattleSprites.base(true), PLAYER_BASE))
	_bases.append(_add_texture(BattleSprites.base(false), OPPONENT_BASE))
	for side in 2:
		var pos := PLAYER_SPRITE if side == 0 else OPPONENT_SPRITE
		_trainers.append(_add_texture(null, pos))
		_pokemon.append(_add_texture(null, pos))
		_pokemon[side].pivot_offset = Vector2(40, 80)
	for node in _pokemon + _trainers:
		node.visible = false
	_ball = Control.new()
	_ball.size = Vector2(10, 10)
	_ball.pivot_offset = Vector2(5, 5)
	_ball.visible = false
	_ball.draw.connect(_draw_ball)
	add_child(_ball)
	effects = BattleEffects.new()
	add_child(effects)


func _process(delta: float) -> void:
	_time += delta
	for side in 2:
		if not _idle[side] or not _pokemon[side].visible:
			continue
		# Respiration : un pixel de haut en bas, décalée entre les deux camps ; de temps
		# en temps, la deuxième image du sprite (petit mouvement).
		var base_pos: Vector2 = _rest[side]
		_pokemon[side].position = base_pos + Vector2(0, roundf(sin(_time * 2.4 + side * 1.7)))
		var cycle := fmod(_time + side * 1.9, 4.0)
		_set_frame(side, 1 if cycle > 3.7 else 0)


func _draw() -> void:
	var band := HORIZON / SKY.size()
	for i in SKY.size():
		draw_rect(Rect2(0, i * band, size.x, band + 1), SKY[i])
	for cloud in [Vector2(30, 18), Vector2(150, 34), Vector2(300, 12)]:
		_draw_cloud(cloud)
	_draw_hills(HORIZON - 14, 18.0, 0.045, HILLS_FAR)
	_draw_hills(HORIZON - 6, 10.0, 0.08, HILLS_NEAR)
	draw_rect(Rect2(0, HORIZON, size.x, size.y - HORIZON), GROUND)
	# Touffes d'herbe semées au hasard (toujours au même endroit) : petites et serrées
	# près de l'horizon, plus grandes vers l'avant, pour donner de la profondeur.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := HORIZON + 3.0
	while y < size.y:
		var depth := (y - HORIZON) / (size.y - HORIZON)
		var spacing := lerpf(22.0, 46.0, depth)
		var x := rng.randf_range(0.0, spacing)
		while x < size.x:
			_draw_tuft(Vector2(roundf(x), roundf(y)), 1 if depth < 0.35 else 2)
			x += spacing * rng.randf_range(0.7, 1.3)
		y += lerpf(5.0, 14.0, depth)


## Touffe de trois brins ; `scale` 1 au loin, 2 au premier plan.
func _draw_tuft(at: Vector2, scale: int) -> void:
	var s := float(scale)
	draw_rect(Rect2(at + Vector2(-2, -2) * s, Vector2(1, 2) * s), GRASS_DARK)
	draw_rect(Rect2(at + Vector2(0, -3) * s, Vector2(1, 3) * s), GRASS_DARK)
	draw_rect(Rect2(at + Vector2(2, -2) * s, Vector2(1, 2) * s), GRASS_DARK)
	draw_rect(Rect2(at + Vector2(1, -2) * s, Vector2(1, 1) * s), GRASS_LIGHT)


func _draw_cloud(at: Vector2) -> void:
	for r in [Rect2(0, 6, 40, 8), Rect2(8, 2, 18, 6), Rect2(20, 0, 14, 8)]:
		draw_rect(Rect2(at + r.position, r.size), CLOUD)
	draw_rect(Rect2(at + Vector2(0, 13), Vector2(40, 2)), CLOUD_SHADE)


func _draw_hills(base_y: float, height: float, frequency: float, color: Color) -> void:
	var x := 0.0
	while x < size.x:
		var h := roundf(height * (0.55 + 0.45 * sin(x * frequency) * sin(x * frequency * 0.37 + 1.0)))
		draw_rect(Rect2(x, base_y - h, 4, HORIZON - base_y + h + 1), color)
		x += 4.0


# --- Entrée en combat ----------------------------------------------------------------

## Prépare le terrain hors de l'écran : socles et dresseurs à l'extérieur, Pokémon cachés.
func reset(player_trainer: Texture2D, opponent_trainer: Texture2D) -> void:
	for side in 2:
		_idle[side] = false
		_pokemon[side].visible = false
		_pokemon[side].modulate = Color.WHITE
		_pokemon[side].scale = Vector2.ONE
		_trainers[side].texture = player_trainer if side == 0 else opponent_trainer
		_trainers[side].visible = _trainers[side].texture != null
		_trainers[side].modulate = Color.WHITE
	_ball.visible = false
	# Le joueur arrive de la droite, l'adversaire de la gauche, comme sur DS.
	var width := size.x if size.x > 0.0 else 352.0
	_bases[0].position = PLAYER_BASE + Vector2(width, 0)
	_trainers[0].position = PLAYER_SPRITE + Vector2(width, 0)
	_bases[1].position = OPPONENT_BASE - Vector2(width, 0)
	_trainers[1].position = OPPONENT_SPRITE - Vector2(width, 0)


## Les socles glissent en place avec les dresseurs dessus.
func slide_in(duration := 0.9) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_bases[0], "position", PLAYER_BASE, duration)
	tween.tween_property(_trainers[0], "position", PLAYER_SPRITE, duration)
	tween.tween_property(_bases[1], "position", OPPONENT_BASE, duration)
	tween.tween_property(_trainers[1], "position", OPPONENT_SPRITE, duration)
	await tween.finished


## Envoi d'un Pokémon : le dresseur lance la Poké Ball (le joueur, avec ses images de
## lancer) puis s'en va ; la Poké Ball s'ouvre dans un éclair et le Pokémon apparaît.
func send_out(side: int, species: PokemonSpecies, wild := false) -> void:
	_species[side] = species
	# Un Pokémon sauvage est déjà là : il apparaît sans Poké Ball.
	if wild:
		await appear(side)
		return
	var trainer := _trainers[side]
	var from: Vector2 = LANDING[side] + (Vector2(-60, -50) if side == 0 else Vector2(60, -40))
	if trainer.visible:
		if side == 0:
			for frame in BattleSprites.PLAYER_BACK_FRAMES:
				trainer.texture = BattleSprites.player_back(frame)
				await _wait(0.06)
			from = trainer.position + Vector2(56, 20)
		else:
			from = trainer.position + Vector2(20, 30)
		var away := Vector2(-110, 0) if side == 0 else Vector2(110, 0)
		var leave := create_tween()
		leave.tween_property(trainer, "position", trainer.position + away, 0.35)
		leave.parallel().tween_property(trainer, "modulate:a", 0.0, 0.35)
		leave.finished.connect(func() -> void: trainer.visible = false)
	await _throw_ball(from, LANDING[side])
	effects.play_flash(LANDING[side] - Vector2(0, 8))
	await appear(side)


## Apparition d'un Pokémon : silhouette blanche qui grandit, puis ses couleurs, puis un
## petit mouvement (deuxième image du sprite).
func appear(side: int) -> void:
	var sprite := _pokemon[side]
	_idle[side] = false
	_set_frame(side, 0)
	_place(side)
	sprite.position = _rest[side]
	sprite.scale = Vector2(0.15, 0.15)
	sprite.modulate = Color(4, 4, 4)
	sprite.visible = true
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.08, 1.08), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	await tween.finished
	_set_frame(side, 1)
	await _wait(0.25)
	_set_frame(side, 0)
	_idle[side] = true


func withdraw(side: int) -> void:
	var sprite := _pokemon[side]
	_idle[side] = false
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(4, 4, 4), 0.1)
	tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.18)
	await tween.finished
	sprite.visible = false
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE


## Capture : la Ball est lancée sur le Pokémon sauvage, qui y entre dans un éclair ; elle
## tombe sur le socle et se secoue `shakes` fois. Si elle tient, elle reste fermée ; sinon
## le Pokémon en ressort.
func capture(shakes: int, caught: bool) -> void:
	var sprite := _pokemon[1]
	var target: Vector2 = CENTERS[1] - Vector2(0, 6)
	await _throw_ball(LANDING[0] + Vector2(-40, -30), target)
	_ball.visible = true
	_ball.position = (target - Vector2(5, 5)).round()
	effects.play_flash(target)
	await withdraw(1)
	var drop := create_tween()
	drop.tween_property(_ball, "position", (LANDING[1] - Vector2(5, 10)).round(), 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await drop.finished
	await _wait(0.4)
	for i in mini(shakes, 3):
		for angle in [-0.5, 0.5, 0.0]:
			_ball.rotation = angle
			await _wait(0.12)
		await _wait(0.45)
	if caught:
		# Ball fermée, un peu assombrie, comme dans les jeux.
		var dim := create_tween()
		dim.tween_property(_ball, "modulate", Color(0.6, 0.6, 0.6), 0.3)
		await _wait(0.6)
		return
	effects.play_flash(LANDING[1] - Vector2(0, 8))
	_ball.visible = false
	sprite.position = _rest[1]
	await appear(1)


## Évolution : le Pokémon du joueur clignote en blanc entre ses deux formes, de plus en
## plus vite, puis reste sous sa nouvelle forme.
func evolve(from: PokemonSpecies, to: PokemonSpecies) -> void:
	if from == null or to == null:
		return
	var sprite := _pokemon[0]
	_idle[0] = false
	sprite.visible = true
	sprite.position = _rest[0]
	sprite.modulate = Color(4, 4, 4)
	for i in 10:
		var species := to if i % 2 == 1 else from
		sprite.texture = BattleSprites.pokemon(species, true, 0)
		await _wait(maxf(0.06, 0.32 - i * 0.03))
	_species[0] = to
	_set_frame(0, 0)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.4)
	await tween.finished
	effects.play_flash(CENTERS[0])
	await _wait(0.3)
	_idle[0] = true


# --- Attaques et coups -----------------------------------------------------------------

## Le lanceur prend son élan (plus fort pour une attaque physique de contact), puis
## l'animation de l'attaque se joue de lui vers sa cible.
func attack(side: int, animation: StringName, strong: bool) -> void:
	_idle[side] = false
	var sprite := _pokemon[side]
	var start: Vector2 = _rest[side]
	var forward := (Vector2(14, -6) if side == 0 else Vector2(-14, 6)) * (2.0 if strong else 1.0)
	var tween := create_tween()
	tween.tween_property(sprite, "position", start + forward, 0.08 if strong else 0.1)
	tween.tween_property(sprite, "position", start, 0.12)
	_set_frame(side, 1)
	await tween.finished
	_set_frame(side, 0)
	_idle[side] = true
	await effects.play_move(animation, CENTERS[side], CENTERS[1 - side])


## Le Pokémon touché tremble et clignote.
func hit(side: int) -> void:
	var sprite := _pokemon[side]
	_idle[side] = false
	var start: Vector2 = _rest[side]
	for i in 4:
		sprite.visible = i % 2 == 1
		sprite.position = start + Vector2(3 if i % 2 == 0 else -3, 0)
		await _wait(0.05)
	sprite.visible = true
	sprite.position = start
	_idle[side] = true


## Reflet coloré et flèches : rouge quand une statistique monte, bleu quand elle baisse.
func stat_change(side: int, rising: bool) -> void:
	var sprite := _pokemon[side]
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.6, 0.8, 0.7) if rising else Color(0.65, 0.8, 1.7), 0.15)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	await effects.play_stat(CENTERS[side], rising)


func condition(side: int, id: StringName) -> void:
	await effects.play_condition(id, CENTERS[side])


func drain(from_side: int) -> void:
	await effects.play_drain(CENTERS[from_side], CENTERS[1 - from_side])


func heal(side: int) -> void:
	await effects.play_heal(CENTERS[side])


func faint(side: int) -> void:
	var sprite := _pokemon[side]
	_idle[side] = false
	var tween := create_tween()
	tween.tween_property(sprite, "position", sprite.position + Vector2(0, 48), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4)
	await tween.finished
	sprite.visible = false


# --- Interne ---------------------------------------------------------------------------

## Calcule la place au repos d'un Pokémon : celui de l'adversaire est centré sur son
## socle d'après la partie réellement dessinée de son sprite (les planches ne centrent
## pas toujours le Pokémon dans sa case).
func _place(side: int) -> void:
	var sprite := _pokemon[side]
	var texture := BattleSprites.pokemon(_species[side], side == 0, 0)
	if side == 0 or texture == null:
		_rest[side] = PLAYER_SPRITE
		sprite.pivot_offset = Vector2(40, 80)
		return
	var bounds := BattleSprites.opaque_bounds(texture)
	var feet := Vector2(bounds.position.x + bounds.size.x / 2.0, bounds.end.y)
	_rest[side] = (OPPONENT_FEET - feet).round()
	sprite.pivot_offset = feet


func _set_frame(side: int, frame: int) -> void:
	if _species[side] != null:
		_pokemon[side].texture = BattleSprites.pokemon(_species[side], side == 0, frame)


## Poké Ball lancée en cloche, qui tourne, de `from` à `to`.
func _throw_ball(from: Vector2, to: Vector2) -> void:
	_ball.rotation = 0.0
	_ball.modulate = Color.WHITE
	_ball.visible = true
	var duration := 0.4
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var p := from.lerp(to, t) - Vector2(0, 40.0 * 4.0 * t * (1.0 - t))
		_ball.position = (p - Vector2(5, 5)).round()
		_ball_spin = t * 3.0
		_ball.queue_redraw(), 0.0, 1.0, duration)
	await tween.finished
	_ball.visible = false


func _draw_ball() -> void:
	# Poké Ball de 10 pixels ; le bandeau tourne en suivant _ball_spin.
	var outline := BattleStyle.OUTLINE
	_ball.draw_circle(Vector2(5, 5), 5.0, outline)
	_ball.draw_circle(Vector2(5, 5), 4.0, Color.WHITE)
	var flip := fmod(_ball_spin, 1.0) > 0.5
	_ball.draw_rect(Rect2(1, 1 if not flip else 5, 8, 4), Color8(232, 64, 56))
	_ball.draw_rect(Rect2(1, 4, 8, 2), outline)
	_ball.draw_rect(Rect2(4, 4, 2, 2), Color.WHITE)


func _add_texture(texture: Texture2D, pos: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position = pos
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(rect)
	return rect


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
