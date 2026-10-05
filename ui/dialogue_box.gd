class_name DialogueBox
extends Control
## Boîte de dialogue en bas de l'écran, construite en code.
## open() affiche la première réplique ; advance() passe à la suivante ou ferme.

var _panel: PanelContainer
var _name_label: Label
var _text_label: Label
var _more: Control
var _lines: PackedStringArray = []
var _index := 0


func _ready() -> void:
	Game.register(&"dialogue", self)
	Events.message_requested.connect(open)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameFont.get_theme()

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE, Control.PRESET_MODE_MINSIZE, 6)
	# Le nom + deux lignes de texte.
	_panel.custom_minimum_size.y = 3 * GameFont.CELL + 16
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	# Même cadre que les messages du combat et le menu du jeu (DsUi).
	var frame := StyleBoxEmpty.new()
	frame.set_content_margin_all(8)
	frame.content_margin_top = 5
	_panel.add_theme_stylebox_override("panel", frame)
	_panel.draw.connect(func() -> void: DsUi.draw_message_frame(_panel, Rect2(Vector2.ZERO, _panel.size)))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_panel.add_child(box)

	_name_label = Label.new()
	box.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text_label)

	# Petit triangle en bas à droite quand il reste des répliques.
	# Posé sur la boîte elle-même et non dans le panneau, qui replacerait son contenu.
	_more = Control.new()
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_more.offset_left = -24
	_more.offset_top = -19
	_more.draw.connect(_draw_more)
	add_child(_more)

	_panel.visible = false
	_more.visible = false


func is_open() -> bool:
	return _panel.visible


func open(speaker: String, lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = 0
	_name_label.text = speaker
	_panel.visible = true
	_show_line()


## Passe à la réplique suivante ; ferme la boîte après la dernière.
func advance() -> void:
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		_show_line()


func close() -> void:
	_panel.visible = false
	_more.visible = false


func _show_line() -> void:
	_text_label.text = _lines[_index]
	_more.visible = _index < _lines.size() - 1
	_more.queue_redraw()


func _draw_more() -> void:
	var points := PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(4, 5)])
	_more.draw_colored_polygon(points, Color(0.85, 0.3, 0.25))
