class_name ExpeditionScreen
extends Control
## Écran du gardien des expéditions : la liste des zones (bande de la couleur de leur
## type, étiquette du type), la description de la zone choisie en bas, ou, si une
## expédition est en cours, la proposition de la rejoindre. Même habillage que la
## boutique (DsUi). Haut / bas pour choisir, `interact` pour valider, `cancel` pour partir.

const PANEL := Rect2(176, 4, 172, 202)
const HINT := Rect2(4, 210, 344, 50)
const ROW_HEIGHT := 23.0
const ROW_STEP := 25.0
const OPEN_TIME := 0.18
const CANCEL_COLOR := Color8(232, 88, 72)

## Entrées : {"label", "color", "type" (ou -1), "biome" (id, vide pour annuler ou rejoindre),
## "join": bool, "text"}.
var _entries: Array[Dictionary] = []
var _index := 0
var _open := false
var _open_amount := 0.0
var _pulse := 0.0
var _tween: Tween


func _enter_tree() -> void:
	Game.register(&"expedition_screen", self)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameFont.get_theme()
	visible = false
	Network.session_ended.connect(close)


func is_open() -> bool:
	return _open


func open() -> void:
	_entries.clear()
	var expeditions := Game.expeditions
	if expeditions != null and expeditions.is_running():
		var biome := expeditions.biome()
		_entries.append({"label": "Rejoindre : %s" % biome.name, "color": BattleStyle.type_color(biome.type),
			"type": biome.type, "biome": &"", "text": biome.description})
	else:
		for id in ExpeditionService.BIOME_IDS:
			var biome := ExpeditionService.load_biome(id)
			if biome != null:
				_entries.append({"label": biome.name, "color": BattleStyle.type_color(biome.type), "type": biome.type,
					"biome": id, "text": "%s Tu pourras lancer %d Poké Balls au plus." % [biome.description, ExpeditionService.BALL_LIMIT]})
	_entries.append({"label": "Annuler", "color": CANCEL_COLOR, "type": -1, "biome": &"", "cancel": true,
		"text": "Reviens quand tu veux partir à l'aventure."})
	_index = 0
	_open = true
	visible = true
	_animate(1.0)


func close() -> void:
	if not _open:
		return
	_open = false
	_animate(0.0)


func _animate(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(v: float) -> void:
		_open_amount = v
		queue_redraw(), _open_amount, target, OPEN_TIME)
	if target == 0.0:
		_tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if not _open:
		return
	_pulse = fmod(_pulse + delta * 4.0, TAU)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	var handled := true
	if event.is_action_pressed("move_up", true):
		_index = posmod(_index - 1, _entries.size())
	elif event.is_action_pressed("move_down", true):
		_index = posmod(_index + 1, _entries.size())
	elif event.is_action_pressed("interact"):
		_choose()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("menu"):
		close()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _choose() -> void:
	var entry := _entries[_index]
	close()
	if entry.get("cancel", false) or Game.expeditions == null:
		return
	Game.expeditions.request_start(entry["biome"])


func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.03, 0.05, 0.3 * _open_amount))
	draw_set_transform(Vector2(roundf((1.0 - _open_amount) * 190.0), 0))
	var panel := Rect2(PANEL.position.x, PANEL.end.y - _entries.size() * ROW_STEP - 9, PANEL.size.x, _entries.size() * ROW_STEP + 9)
	DsUi.draw_touch_panel(self, panel)
	for i in _entries.size():
		var entry := _entries[i]
		var row := Rect2(panel.position + Vector2(5, 5 + i * ROW_STEP), Vector2(panel.size.x - 10, ROW_HEIGHT))
		DsUi.draw_button(self, row, entry["color"], i == _index, _pulse)
		DsUi.draw_text(self, row.position + Vector2(16, 3), entry["label"], false, row.size.x - 58)
		if entry["type"] >= 0:
			var label := MenuSprites.type_label(entry["type"])
			if label != null:
				draw_texture(label, Vector2(row.end.x - label.get_width() - 6, row.position.y + 6))
	draw_set_transform(Vector2(0, roundf((1.0 - _open_amount) * 60.0)))
	DsUi.draw_message_frame(self, HINT)
	if not _entries.is_empty():
		draw_multiline_string(GameFont.get_font(), Vector2(HINT.position.x + 9, HINT.position.y + 4 + GameFont.ASCENT),
			_entries[_index]["text"], HORIZONTAL_ALIGNMENT_LEFT, HINT.size.x - 22, GameFont.CELL, 2)
	draw_set_transform(Vector2.ZERO)
