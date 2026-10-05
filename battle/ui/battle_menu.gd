class_name BattleMenu
extends Control
## Menu de choix du combat (commandes, attaques, équipe, sac) : une grille de boutons
## colorés, parcourue au clavier ou à la manette (actions move_*), validée par
## « interact », annulée par « cancel ». Le bouton choisi est éclairci et entouré ; les
## entrées désactivées sont grisées et ne se valident pas.

signal chosen(index: int)
signal cancelled
signal hovered(index: int)

var columns := 1
## Le menu peut-il être fermé avec « cancel » ?
var can_cancel := true
## Hauteur d'un bouton, en pixels.
var cell_height := 28.0
## Hauteur ajustée au nombre d'entrées (menus d'équipe et de sac).
var fit_to_content := false
var _grid: GridContainer
var _cells: Array[Control] = []
var _enabled: Array[bool] = []
var _colors: Array[Color] = []
var _index := 0
var _pulse := 0.0


func _ready() -> void:
	theme = GameFont.get_theme()
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.position = Vector2(4, 4)
	add_child(_grid)


## Remplit le menu. `enabled` : une valeur par entrée (toutes actives si vide) ;
## `colors` : couleur de chaque bouton (gris clair si vide) ; `details` : deuxième
## ligne facultative de chaque bouton (PP d'une attaque...).
func set_entries(entries: PackedStringArray, p_columns := 1, enabled: Array[bool] = [],
		colors: Array[Color] = [], details: PackedStringArray = PackedStringArray()) -> void:
	if _grid == null:
		await ready
	columns = maxi(1, p_columns)
	_grid.columns = columns
	for cell in _cells:
		cell.queue_free()
	_cells.clear()
	_enabled.clear()
	_colors.clear()
	var cell_width := (size.x - 8 - 4 * (columns - 1)) / columns
	for i in entries.size():
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(cell_width, cell_height)
		cell.draw.connect(_draw_cell.bind(cell, i))
		var label := Label.new()
		label.text = entries[i]
		label.position = Vector2(16, 1 if i < details.size() else (cell_height - 16) / 2.0)
		cell.add_child(label)
		if i < details.size() and not details[i].is_empty():
			var detail := Label.new()
			detail.text = details[i]
			detail.position = Vector2(cell_width - 8 - detail.get_minimum_size().x, cell_height - 16)
			cell.add_child(detail)
		_grid.add_child(cell)
		_cells.append(cell)
		_enabled.append(enabled.is_empty() or (i < enabled.size() and enabled[i]))
		_colors.append(colors[i] if i < colors.size() else BattleStyle.PANEL_SHADE)
	_index = 0
	if fit_to_content:
		var rows := ceili(float(entries.size()) / columns)
		size.y = rows * cell_height + (rows - 1) * 4 + 8
		queue_redraw()
	hovered.emit(_index)
	_redraw()


func selected_index() -> int:
	return _index


func _process(delta: float) -> void:
	if is_visible_in_tree() and not _cells.is_empty():
		_pulse = fmod(_pulse + delta * 4.0, TAU)
		_cells[_index].queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _cells.is_empty():
		return
	var step := 0
	if event.is_action_pressed("move_right"):
		step = 1
	elif event.is_action_pressed("move_left"):
		step = -1
	elif event.is_action_pressed("move_down"):
		step = columns
	elif event.is_action_pressed("move_up"):
		step = -columns
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _enabled[_index]:
			chosen.emit(_index)
		return
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		if can_cancel:
			cancelled.emit()
		return
	if step == 0:
		return
	get_viewport().set_input_as_handled()
	var target := _index + step
	if target >= 0 and target < _cells.size():
		_index = target
		hovered.emit(_index)
		_redraw()


func _draw() -> void:
	# Fond du menu, sous les boutons, comme l'écran tactile de Noir et Blanc : brun
	# sombre, liseré noir, petits points.
	DsUi.draw_touch_panel(self, Rect2(Vector2.ZERO, size))


func _redraw() -> void:
	for cell in _cells:
		cell.queue_redraw()


func _draw_cell(cell: Control, i: int) -> void:
	DsUi.draw_button(cell, Rect2(Vector2.ZERO, cell.size), _colors[i], i == _index, _pulse, _enabled[i])
