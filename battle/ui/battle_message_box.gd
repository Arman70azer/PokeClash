class_name BattleMessageBox
extends Control
## Boîte de messages du combat : panneau clair aux coins arrondis, double liseré, dans
## l'esprit de Noir et Blanc (dessiné en code).
## show_message() écrit le texte lettre par lettre puis attend un court instant ; une
## pression sur « interact » accélère ou passe au message suivant.

## Vitesse d'écriture (lettres par seconde) et attente après un message.
const CHARS_PER_SECOND := 60.0
const HOLD_TIME := 0.9

signal _advanced

var _label: Label
var _waiting := false
var _serial := 0


func _ready() -> void:
	theme = GameFont.get_theme()
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.offset_left = 14
	_label.offset_top = 9
	_label.offset_right = -14
	_label.offset_bottom = -6
	add_child(_label)


## Affiche un message et rend la main quand il a été lu.
func show_message(text: String) -> void:
	_label.text = text
	_label.visible_characters = 0
	_waiting = true
	var total := text.length()
	var shown := 0.0
	while shown < total and _waiting:
		await get_tree().process_frame
		shown += get_process_delta_time() * CHARS_PER_SECOND
		_label.visible_characters = int(shown)
	_label.visible_characters = -1
	_waiting = true
	_serial += 1
	var serial := _serial
	# Seul le minuteur de ce message peut le faire passer (pas celui d'un message précédent).
	get_tree().create_timer(HOLD_TIME).timeout.connect(func() -> void:
		if serial == _serial and _waiting:
			_advanced.emit())
	await _advanced
	_waiting = false
	queue_redraw()


## Affiche un texte sans attendre (question au-dessus d'un menu).
func show_prompt(text: String) -> void:
	_waiting = false
	_label.text = text
	_label.visible_characters = -1
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	DsUi.draw_message_frame(self, rect)
	# Petite flèche qui clignote quand le message attend d'être lu.
	if _waiting and _label.visible_characters == -1:
		DsUi.draw_more_arrow(self, Vector2(size.x - 18, size.y - 14))


func _process(_delta: float) -> void:
	if _waiting:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting and is_visible_in_tree() and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _label.visible_characters != -1:
			_waiting = false  # termine l'écriture tout de suite
		else:
			_advanced.emit()
