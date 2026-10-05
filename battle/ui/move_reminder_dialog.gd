class_name MoveReminderDialog
extends Control
## Dialogue pour permettre au joueur de choisir quelle attaque oublier
## quand son Pokémon apprend une nouvelle attaque (5ème attaque).

signal move_selected(index: int)
signal cancelled

var pokemon: PokemonInstance
var new_move: MoveData
var _panel: PanelContainer
var _message: Label
var _menu: BattleMenu


func _ready() -> void:
	theme = GameFont.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.position = Vector2(20, 80)
	_panel.size = Vector2(312, 100)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	_panel.add_child(vbox)

	_message = Label.new()
	_message.text = "Quelle attaque oublier ?"
	_message.custom_minimum_size = Vector2(300, 30)
	vbox.add_child(_message)

	_menu = BattleMenu.new()
	_menu.size = Vector2(312, 64)
	_menu.cell_height = 26.0
	_menu.chosen.connect(_on_move_chosen)
	_menu.cancelled.connect(_on_cancelled)
	vbox.add_child(_menu)

	hide()


## Configure et affiche le dialogue.
func show_for_pokemon(p_pokemon: PokemonInstance, p_new_move: MoveData) -> void:
	pokemon = p_pokemon
	new_move = p_new_move

	_message.text = "%s veut apprendre %s.\nQuelle attaque oublier ?" % [pokemon.display_name(), new_move.name]

	var move_names := PackedStringArray()
	var move_details := PackedStringArray()

	for move in pokemon.moves:
		if move != null:
			move_names.append(move.name)
			move_details.append("PP: %d/%d" % [pokemon.pp_left(pokemon.moves.find(move)), move.pp])

	_menu.set_entries(move_names, 1, [], [], move_details)
	show()


func _on_move_chosen(index: int) -> void:
	move_selected.emit(index)
	hide()


func _on_cancelled() -> void:
	cancelled.emit()
	hide()
