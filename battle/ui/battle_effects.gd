class_name BattleEffects
extends Control
## Effets visuels du combat, dessinés en code en gros pixels : animations d'attaques
## (flammes, griffes, graines, lianes...), de statuts (brûlure, poison, sommeil...),
## de statistiques (flèches) et de soin. Chaque animation est une fonction qu'on peut
## attendre (await) ; les effets restants s'effacent tout seuls.
##
## Une attaque choisit son animation par le champ `animation` de sa donnée (MoveData) :
## pour une nouvelle animation, écrire sa fonction ici et l'ajouter à play_move().

## Une particule : position, vitesse, durée de vie, sorte, couleur, taille.
class Particle:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var gravity := 0.0
	var age := 0.0
	var life := 0.5
	var kind := &"square"
	var color := Color.WHITE
	var size := 2.0
	## Pour les traits (griffes, lianes) : point d'arrivée.
	var to := Vector2.ZERO

## Sortes de particules dessinées en pixels doubles.
const DOUBLED := [&"square", &"sparkle", &"flame", &"seed", &"leaf", &"bubble", &"orb", &"z", &"arrow_up", &"arrow_down"]

var _particles: Array[Particle] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _particles.is_empty():
		return
	for p in _particles:
		p.age += delta
		p.vel.y += p.gravity * delta
		p.pos += p.vel * delta
	_particles = _particles.filter(func(p: Particle) -> bool: return p.age < p.life)
	queue_redraw()


# --- Attaques ------------------------------------------------------------------------

## Joue l'animation d'une attaque, de `from` (centre du lanceur) vers `to` (centre de la
## cible). Animation inconnue : un simple impact.
func play_move(animation: StringName, from: Vector2, to: Vector2) -> void:
	match animation:
		&"scratch": await _move_scratch(from, to)
		&"tackle", &"struggle": await _impact(to, 0.3)
		&"growl": await _move_growl(from, to)
		&"ember": await _move_ember(from, to)
		&"leech_seed": await _move_leech_seed(from, to)
		&"vine_whip": await _move_vine_whip(from, to)
		&"smokescreen": await _move_smokescreen(from, to)
		_: await _impact(to)


func _move_scratch(_from: Vector2, to: Vector2) -> void:
	for i in 3:
		var offset := Vector2(-10 + i * 8, -10)
		_slash(to + offset, to + offset + Vector2(12, 22), Color.WHITE, 0.25)
		await _wait(0.07)
	await _impact(to, 0.2)


func _move_growl(from: Vector2, to: Vector2) -> void:
	var dir := (to - from).normalized()
	for i in 3:
		var p := _spawn(&"ring", from + dir * 12, Color(1, 1, 1, 0.9), 0.5, 4.0)
		p.vel = dir * 90.0
		await _wait(0.12)
	await _wait(0.35)


func _move_ember(from: Vector2, to: Vector2) -> void:
	for i in 5:
		_projectile(&"flame", from, to + Vector2(-10 + i * 5, randf_range(-4, 4)), Color8(248, 136, 40), 0.35, 18.0)
		await _wait(0.06)
	await _wait(0.3)
	await _burst(to, &"flame", [Color8(248, 208, 64), Color8(240, 112, 40), Color8(216, 48, 32)], 22, 0.55)


func _move_leech_seed(from: Vector2, to: Vector2) -> void:
	for i in 2:
		_projectile(&"seed", from, to + Vector2(-8 + i * 14, 6), Color8(176, 136, 72), 0.4, 30.0)
		await _wait(0.1)
	await _wait(0.35)
	for i in 6:
		var p := _spawn(&"leaf", to + Vector2(randf_range(-14, 14), randf_range(-4, 10)), Color8(96, 200, 72), 0.5, 3.0)
		p.vel = Vector2(randf_range(-10, 10), -30)
	await _wait(0.4)


func _move_vine_whip(_from: Vector2, to: Vector2) -> void:
	_slash(to + Vector2(-20, -16), to + Vector2(18, 10), Color8(88, 184, 64), 0.25, 3.0)
	await _wait(0.12)
	_slash(to + Vector2(20, -16), to + Vector2(-16, 12), Color8(88, 184, 64), 0.25, 3.0)
	await _impact(to, 0.2)


func _move_smokescreen(from: Vector2, to: Vector2) -> void:
	_projectile(&"puff", from, to, Color(0.35, 0.35, 0.4), 0.3, 10.0)
	await _wait(0.3)
	for i in 8:
		var p := _spawn(&"puff", to + Vector2(randf_range(-18, 18), randf_range(-12, 12)), Color(0.4, 0.4, 0.45, 0.85), 0.8, 5.0)
		p.vel = Vector2(randf_range(-8, 8), randf_range(-6, 2))
	await _wait(0.7)


# --- Statuts, statistiques, soin -----------------------------------------------------

func play_condition(condition: StringName, at: Vector2) -> void:
	match condition:
		&"burn":
			await _rising(at, &"flame", [Color8(248, 176, 48), Color8(232, 88, 40)], 10, 0.6)
		&"poison", &"toxic":
			await _rising(at, &"bubble", [Color8(176, 96, 200), Color8(128, 64, 160)], 10, 0.7)
		&"paralysis":
			for i in 6:
				var p := _spawn(&"spark", at + Vector2(randf_range(-20, 20), randf_range(-20, 14)), Color8(248, 224, 64), 0.25, 3.0)
				p.to = p.pos + Vector2(randf_range(-6, 6), 8)
				await _wait(0.05)
			await _wait(0.2)
		&"sleep":
			for i in 3:
				var p := _spawn(&"z", at + Vector2(8 + i * 4, -10), Color(0.95, 0.95, 1.0), 0.9, 2.0)
				p.vel = Vector2(10, -18)
				await _wait(0.18)
			await _wait(0.5)
		&"freeze":
			await _burst(at, &"square", [Color8(200, 240, 255), Color8(120, 200, 240)], 14, 0.5)
		&"leech_seed":
			await _rising(at, &"leaf", [Color8(96, 200, 72)], 6, 0.5)
		_:
			await _impact(at, 0.2)


## Fils de Vampigraine : orbes vertes de la victime vers le Pokémon qui en profite.
func play_drain(from: Vector2, to: Vector2) -> void:
	for i in 4:
		_projectile(&"orb", from + Vector2(randf_range(-8, 8), randf_range(-8, 8)), to, Color8(120, 232, 96), 0.45, -20.0)
		await _wait(0.07)
	await _wait(0.4)


func play_stat(at: Vector2, rising: bool) -> void:
	for i in 6:
		var start := at + Vector2(randf_range(-20, 20), 18 if rising else -22)
		var p := _spawn(&"arrow_up" if rising else &"arrow_down", start, Color8(240, 96, 72) if rising else Color8(88, 136, 240), 0.5, 3.0)
		p.vel = Vector2(0, -60 if rising else 60)
		await _wait(0.05)
	await _wait(0.4)


func play_heal(at: Vector2) -> void:
	await _rising(at, &"sparkle", [Color8(160, 248, 160), Color.WHITE], 10, 0.6)


## Éclair blanc qui s'ouvre (Poké Ball qui s'ouvre, Pokémon qui apparaît).
func play_flash(at: Vector2) -> void:
	var ring := _spawn(&"ring", at, Color.WHITE, 0.35, 2.0)
	ring.vel = Vector2.ZERO
	ring.gravity = 0.0
	for i in 10:
		var p := _spawn(&"sparkle", at, Color(1, 1, 0.85), 0.4, 2.0)
		p.vel = Vector2.from_angle(TAU * i / 10.0) * 70.0
	await _wait(0.3)


# --- Briques ---------------------------------------------------------------------------

func _spawn(kind: StringName, pos: Vector2, color: Color, life: float, particle_size: float) -> Particle:
	var p := Particle.new()
	p.kind = kind
	p.pos = pos
	p.color = color
	p.life = life
	p.size = particle_size
	_particles.append(p)
	return p


## Projectile en arc de `from` à `to` en `duration` secondes (`arc` : hauteur de l'arc).
func _projectile(kind: StringName, from: Vector2, to: Vector2, color: Color, duration: float, arc: float) -> void:
	var p := _spawn(kind, from, color, duration, 3.0)
	# Vitesse initiale et gravité pour atteindre `to` avec un arc de hauteur `arc`.
	var g := 8.0 * arc / (duration * duration)
	p.gravity = g
	p.vel = (to - from) / duration - Vector2(0, g * duration / 2.0)


func _slash(from: Vector2, to: Vector2, color: Color, life: float, width := 2.0) -> void:
	var p := _spawn(&"slash", from, color, life, width)
	p.to = to


func _impact(at: Vector2, duration := 0.25) -> void:
	_spawn(&"star", at, Color(1, 1, 0.8), duration, 10.0)
	for i in 6:
		var p := _spawn(&"square", at, Color.WHITE, duration, 2.0)
		p.vel = Vector2.from_angle(TAU * i / 6.0 + 0.3) * 60.0
	await _wait(duration)


func _burst(at: Vector2, kind: StringName, colors: Array, count: int, duration: float) -> void:
	for i in count:
		var p := _spawn(kind, at, colors[i % colors.size()], duration * randf_range(0.7, 1.0), 3.0)
		p.vel = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 60.0)
		p.gravity = -20.0 if kind == &"flame" else 40.0
	await _wait(duration)


func _rising(at: Vector2, kind: StringName, colors: Array, count: int, duration: float) -> void:
	for i in count:
		var p := _spawn(kind, at + Vector2(randf_range(-18, 18), randf_range(0, 16)), colors[i % colors.size()], duration, 3.0)
		p.vel = Vector2(randf_range(-6, 6), randf_range(-40, -25))
		await _wait(duration / count * 0.6)
	await _wait(duration * 0.5)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _draw() -> void:
	for p in _particles:
		var t := p.age / p.life
		var c := p.color
		c.a *= 1.0 - maxf(0.0, t - 0.6) / 0.4
		var at := p.pos.round()
		# Les petites formes sont dessinées en pixels doubles, pour se voir à l'écran.
		var doubled := p.kind in DOUBLED
		if doubled:
			draw_set_transform(at, 0.0, Vector2(2, 2))
			at = Vector2.ZERO
		match p.kind:
			&"square", &"sparkle":
				var s := p.size if p.kind == &"square" else (2.0 if fmod(p.age * 12.0, 2.0) < 1.0 else 1.0)
				draw_rect(Rect2(at - Vector2(s, s) / 2.0, Vector2(s, s)), c)
			&"flame":
				var hot := Color8(248, 232, 120).lerp(c, clampf(t * 1.5, 0, 1))
				hot.a = c.a
				draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 3)), hot)
				draw_rect(Rect2(at + Vector2(-1, -3), Vector2(2, 2)), Color(hot.r, hot.g * 1.1, hot.b, c.a))
				draw_rect(Rect2(at + Vector2(-2, 2), Vector2(4, 1)), Color(c.r * 0.8, c.g * 0.5, c.b * 0.5, c.a))
			&"seed":
				draw_rect(Rect2(at + Vector2(-2, -1), Vector2(4, 3)), c)
				draw_rect(Rect2(at + Vector2(-1, -2), Vector2(2, 1)), c.lightened(0.3))
			&"leaf":
				draw_rect(Rect2(at + Vector2(-2, 0), Vector2(3, 2)), c)
				draw_rect(Rect2(at + Vector2(0, -1), Vector2(2, 2)), c.lightened(0.25))
			&"bubble":
				draw_arc(at, 2.5, 0, TAU, 8, c, 1.0)
				draw_rect(Rect2(at + Vector2(-1, -2), Vector2(1, 1)), Color(1, 1, 1, c.a))
			&"orb":
				draw_circle(at, 2.5, c)
				draw_rect(Rect2(at + Vector2(-1, -1), Vector2(1, 1)), Color(1, 1, 1, c.a))
			&"puff":
				draw_circle(at, p.size + t * 6.0, c)
			&"ring":
				draw_arc(at, p.size + t * 26.0, 0, TAU, 20, c, 2.0)
			&"slash":
				var grow := clampf(t * 3.0, 0.0, 1.0)
				var tip := p.pos.lerp(p.to, grow)
				draw_line(p.pos, tip, c, p.size)
				draw_line(p.pos + Vector2(1, 0), tip + Vector2(1, 0), Color(0.75, 0.9, 1.0, c.a * 0.7), 1.0)
			&"spark":
				var mid := (p.pos + p.to) / 2.0 + Vector2(4, 0)
				draw_polyline(PackedVector2Array([p.pos, mid, p.to]), c, 2.0)
			&"z":
				var s := 4.0
				draw_line(at, at + Vector2(s, 0), c, 1.0)
				draw_line(at + Vector2(s, 0), at + Vector2(0, s), c, 1.0)
				draw_line(at + Vector2(0, s), at + Vector2(s, s), c, 1.0)
			&"arrow_up", &"arrow_down":
				var d := -1.0 if p.kind == &"arrow_up" else 1.0
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, 3 * d), at + Vector2(-3, 0), at + Vector2(3, 0)]), c)
				draw_rect(Rect2(at + Vector2(-1, -4.0 if d > 0 else 0.0), Vector2(2, 4)), c)
			&"star":
				var r := p.size * (0.6 + t)
				var pts := PackedVector2Array()
				for i in 8:
					pts.append(at + Vector2.from_angle(TAU * i / 8.0) * (r if i % 2 == 0 else r * 0.45))
				draw_colored_polygon(pts, c)
		if doubled:
			draw_set_transform(Vector2.ZERO)
