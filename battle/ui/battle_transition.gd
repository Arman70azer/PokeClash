class_name BattleTransition
extends Control
## Transition d'entrée et de sortie de combat : l'écran clignote deux fois, puis des
## bandes noires le balaient en alternance depuis la gauche et la droite ; ensuite elles
## s'ouvrent depuis le centre pour révéler la scène suivante.

const BANDS := 8
const FLASHES := 2

## 0 = rien, 1 = écran entièrement noir.
var _cover := 0.0
## Ouverture depuis le centre (0 = fermé, 1 = ouvert) pendant la sortie.
var _opening := 0.0
var _flash := 0.0
var _closing := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Clignote puis noircit l'écran ; rend la main quand il est entièrement noir.
func cover() -> void:
	_closing = true
	_cover = 0.0
	_opening = 0.0
	for i in FLASHES:
		await _set_flash(0.85, 0.07)
		await _set_flash(0.0, 0.07)
	var tween := create_tween()
	tween.tween_method(_set_cover, 0.0, 1.0, 0.55)
	await tween.finished


## Ouvre l'écran noir depuis le centre ; rend la main quand tout est visible.
func reveal() -> void:
	_closing = false
	var tween := create_tween()
	tween.tween_method(_set_opening, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_cover = 0.0
	queue_redraw()


func _set_flash(value: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_flash = v
		queue_redraw(), _flash, value, duration)
	await tween.finished


func _set_cover(value: float) -> void:
	_cover = value
	queue_redraw()


func _set_opening(value: float) -> void:
	_opening = value
	queue_redraw()


func _draw() -> void:
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _flash))
	if _cover <= 0.0:
		return
	var band_height := ceilf(size.y / BANDS)
	if _closing:
		for i in BANDS:
			# Chaque bande part un peu après la précédente, une sur deux par la droite.
			var t := clampf(_cover * 1.6 - i * 0.6 / BANDS, 0.0, 1.0)
			var w := roundf(size.x * t)
			var x := 0.0 if i % 2 == 0 else size.x - w
			draw_rect(Rect2(x, i * band_height, w, band_height), Color.BLACK)
	else:
		# Ouverture : deux volets qui s'écartent du centre vers le haut et le bas.
		var half := size.y / 2.0
		var gap := roundf(half * _opening)
		draw_rect(Rect2(0, 0, size.x, half - gap), Color.BLACK)
		draw_rect(Rect2(0, half + gap, size.x, half - gap + 1), Color.BLACK)
