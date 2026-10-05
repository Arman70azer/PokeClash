class_name BattleInfoBox
extends Control
## Cadre d'un Pokémon au combat, avec les barres de la planche « Battle HUD » (Noir et
## Blanc) : nom au-dessus de la barre, niveau à côté de l'icône « Lv. », jauge de PV
## verte, jaune ou rouge, et pour le Pokémon du joueur, PV en chiffres et barre
## d'expérience. Pastille de statut à droite du nom.

## Position de la barre dans le cadre (le nom est au-dessus).
const STRIP_POS := Vector2(0, 14)
## Où écrire le niveau et les PV, relativement à la barre (après l'icône « Lv. », de part
## et d'autre de la barre oblique).
const OPPONENT_LEVEL := Vector2(94, -1)
const PLAYER_LEVEL := Vector2(90, -2)
const PLAYER_HP_RIGHT := 79.0
const PLAYER_MAX_LEFT := 89.0
const PLAYER_HP_Y := 11.0
## Barre d'expérience (bleue, comme dans Noir et Blanc).
const EXP_COLOR := Color8(57, 164, 247)

## Cadre du joueur (PV en chiffres, barre d'expérience) ou de l'adversaire.
var is_player := false
var _name_label: Label
var _status_label: Label
var _strip: Texture2D
var _level := 1
var _hp := 0.0
var _max_hp := 1
var _status := ""
var _exp := 0.0
var _tween: Tween


func _ready() -> void:
	theme = GameFont.get_theme()
	_strip = BattleSprites.hud(BattleSprites.HUD_PLAYER_STRIP if is_player else BattleSprites.HUD_OPPONENT_STRIP)
	size = Vector2(_strip.get_width(), STRIP_POS.y + _strip.get_height())
	custom_minimum_size = size
	_name_label = Label.new()
	_name_label.position = Vector2(4, -3)
	add_child(_name_label)
	_status_label = Label.new()
	_status_label.position = _status_rect().position + Vector2(3, -3)
	_status_label.visible = false
	add_child(_status_label)


## Affiche un Pokémon (dictionnaire de BattleEngine.snapshot / évènement send_out).
func set_pokemon(info: Dictionary) -> void:
	_name_label.text = info["name"]
	_level = int(info["level"])
	_max_hp = maxi(1, int(info["max_hp"]))
	set_status(info.get("status", ""))
	_exp = float(info.get("exp_ratio", 0.0))
	_set_hp(float(info["hp"]))


## Fait avancer la barre d'expérience jusqu'à `ratio`, après `levels` niveaux gagnés
## (la barre se remplit puis repart de zéro à chaque niveau).
func animate_exp(ratio: float, levels: int) -> void:
	for i in levels:
		await _tween_exp(1.0)
		_exp = 0.0
	await _tween_exp(ratio)


func set_level(level: int, hp: int, max_hp: int) -> void:
	_level = level
	_max_hp = maxi(1, max_hp)
	_set_hp(float(hp))


func _tween_exp(target: float) -> void:
	if not is_player or target <= _exp:
		_exp = target
		queue_redraw()
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_exp = v
		queue_redraw(), _exp, target, clampf((target - _exp) * 1.2, 0.15, 1.0))
	await tween.finished


func set_status(short_name: String) -> void:
	_status = short_name
	_status_label.text = short_name
	_status_label.visible = not short_name.is_empty()
	queue_redraw()


## Fait glisser la jauge jusqu'à `hp`.
func animate_hp(hp: int, max_hp: int) -> void:
	_max_hp = maxi(1, max_hp)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	var duration := clampf(absf(hp - _hp) / _max_hp * 1.2, 0.15, 0.8)
	_tween.tween_method(_set_hp, _hp, float(hp), duration)
	await _tween.finished


## Glisse depuis le bord de l'écran jusqu'à sa place.
func slide_in(target: Vector2) -> void:
	position = target + Vector2(180 if is_player else -180, 0)
	visible = true
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target, 0.3)
	await tween.finished


func _set_hp(value: float) -> void:
	_hp = value
	queue_redraw()


func _draw() -> void:
	# Plaque claire derrière le nom : il reste lisible sur le ciel comme sur l'herbe.
	var name_width := _name_label.get_minimum_size().x
	BattleStyle.draw_rounded(self, Rect2(1, 0, name_width + 8, 13), 3.0, BattleStyle.NAME_PLATE)
	draw_texture(_strip, STRIP_POS)
	_draw_gauge()
	_draw_number(_level, STRIP_POS + (PLAYER_LEVEL if is_player else OPPONENT_LEVEL), false)
	if is_player:
		var slot := BattleSprites.HUD_PLAYER_EXP
		var width := floorf(slot.size.x * clampf(_exp, 0.0, 1.0))
		if width > 0.0:
			draw_rect(Rect2(STRIP_POS + Vector2(slot.position), Vector2(width, slot.size.y)), EXP_COLOR)
		_draw_number(roundi(_hp), STRIP_POS + Vector2(PLAYER_HP_RIGHT, PLAYER_HP_Y), true)
		_draw_number(_max_hp, STRIP_POS + Vector2(PLAYER_MAX_LEFT, PLAYER_HP_Y), false)
	if not _status.is_empty():
		_draw_status()


func _draw_gauge() -> void:
	var slot: Rect2i = BattleSprites.HUD_PLAYER_GAUGE if is_player else BattleSprites.HUD_OPPONENT_GAUGE
	var ratio := _hp / _max_hp if _hp > 0.0 else 0.0
	DsUi.draw_hud_gauge(self, Rect2(STRIP_POS + Vector2(slot.position), Vector2(slot.size)), ratio)


## Écrit un nombre avec les chiffres du HUD ; `right_aligned` : `at` est son bord droit.
func _draw_number(value: int, at: Vector2, right_aligned: bool) -> void:
	DsUi.draw_hud_number(self, value, at, right_aligned)


## Pastille de statut (PSN, BRL...) à droite du nom ; son texte est _status_label.
func _draw_status() -> void:
	var pill := _status_rect()
	var color: Color = BattleStyle.STATUS_COLORS.get(_status, Color.GRAY)
	draw_colored_polygon(BattleStyle.panel_points(pill, 2), BattleStyle.OUTLINE)
	draw_colored_polygon(BattleStyle.panel_points(pill.grow(-1), 2), color.lightened(0.3))


func _status_rect() -> Rect2:
	return Rect2(size.x - 34 if not is_player else 50, 0, 28, 12)
