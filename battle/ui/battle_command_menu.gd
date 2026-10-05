class_name BattleCommandMenu
extends Control
## Menu principal du combat, avec les boutons de la planche « Battle HUD » (écran tactile
## de Noir et Blanc) : FIGHT sur le dôme rouge de la Poké Ball, puis BAG, RUN et
## POKÉMON. Gauche / droite pour choisir, « interact » pour valider. Le bouton choisi
## est éclairé et se soulève ; les autres sont assombris.

signal chosen(index: int)

## Indices renvoyés, dans l'ordre d'affichage : Combat (0), Sac (1), Fuite (3), Pokémon (2).
const ORDER := [0, 1, 3, 2]
## Position de chaque bouton dans le menu (même ordre qu'ORDER).
const POSITIONS := [Vector2(4, 6), Vector2(108, 4), Vector2(190, 20), Vector2(270, 4)]

var _buttons: Array[Texture2D] = []
var _fight_text: Texture2D
var _index := 0
var _time := 0.0


func _ready() -> void:
	size = Vector2(352, 68)
	_buttons = [
		BattleSprites.hud(BattleSprites.HUD_FIGHT_DOME),
		BattleSprites.hud(BattleSprites.HUD_BAG),
		BattleSprites.hud(BattleSprites.HUD_RUN),
		BattleSprites.hud(BattleSprites.HUD_POKEMON),
	]
	_fight_text = BattleSprites.hud(BattleSprites.HUD_FIGHT_TEXT)
	visibility_changed.connect(func() -> void: _index = 0)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		_index = mini(_index + 1, ORDER.size() - 1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		_index = maxi(_index - 1, 0)
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		chosen.emit(ORDER[_index])
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	# Fond de l'écran tactile : brun sombre, liseré noir, petits points.
	DsUi.draw_touch_panel(self, Rect2(Vector2.ZERO, size), false, 6)
	for i in _buttons.size():
		var selected := i == _index
		var lift := Vector2(0, -2 - roundf(sin(_time * 6.0))) if selected else Vector2.ZERO
		var tint := Color(1.2, 1.2, 1.2) if selected else Color(0.72, 0.72, 0.72)
		var pos: Vector2 = POSITIONS[i] + lift
		if i == 0:
			_draw_fight(pos, tint)
		else:
			draw_texture(_buttons[i], pos, tint)


## Bouton FIGHT : un dôme (demi-ellipse posée sur un pied droit) découpé dans le haut
## rouge de la grande Poké Ball, cerclé de noir avec un reflet clair, le mot FIGHT!
## au centre.
func _draw_fight(pos: Vector2, tint: Color) -> void:
	var dome := _buttons[0]
	var w := dome.get_width()
	var h := dome.get_height()
	var shoulder := h * 0.45
	var points := PackedVector2Array([Vector2(0, h)])
	for k in 17:
		var angle := PI + PI * k / 16.0
		points.append(Vector2(w / 2.0 + cos(angle) * w / 2.0, shoulder + sin(angle) * shoulder))
	points.append(Vector2(w, h))
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for p in points:
		uvs.append(Vector2(p.x / w, p.y / h))
		colors.append(tint)
	var placed := PackedVector2Array()
	for p in points:
		placed.append(pos + p)
	draw_polygon(placed, colors, uvs, dome)
	var outline := placed.duplicate()
	outline.append(placed[0])
	draw_polyline(outline, Color.BLACK, 2.0)
	# Reflet : arc clair un peu sous le bord.
	var shine := PackedVector2Array()
	for k in range(3, 9):
		var angle := PI + PI * k / 16.0
		shine.append(pos + Vector2(w / 2.0 + cos(angle) * (w / 2.0 - 6), shoulder + sin(angle) * (shoulder - 5)))
	draw_polyline(shine, Color(1, 1, 1, 0.55), 2.0)
	var text_pos := pos + Vector2((w - _fight_text.get_width()) / 2.0, h * 0.5)
	draw_texture(_fight_text, text_pos.round(), tint)
