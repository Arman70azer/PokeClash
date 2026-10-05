extends Control
## Menu héberger / rejoindre, construit en code. En partie, on quitte la session depuis
## le menu du jeu (GameMenu, touche Échap ou X).

var _panel: PanelContainer
var _address: LineEdit
var _name: LineEdit
var _status: Label
var _hud: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = GameFont.get_theme()

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 24)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	var title := Label.new()
	title.text = "PokeClash - prototype co-op"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_name = LineEdit.new()
	_name.placeholder_text = "Pseudo (sauvegarde)"
	_name.max_length = 16
	box.add_child(_name)

	var host_button := Button.new()
	host_button.text = "Héberger"
	host_button.pressed.connect(_on_host_pressed)
	box.add_child(host_button)

	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Adresse IP de l'hôte"
	box.add_child(_address)

	var join_button := Button.new()
	join_button.text = "Rejoindre"
	join_button.pressed.connect(_on_join_pressed)
	box.add_child(join_button)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	_hud = Label.new()
	_hud.position = Vector2(2, 0)
	_hud.visible = false
	add_child(_hud)

	Network.session_started.connect(_on_session_started)
	Network.session_ended.connect(_on_session_ended)
	Network.connection_failed.connect(_on_connection_failed)


func _on_host_pressed() -> void:
	_use_name()
	var err := Network.host()
	if err != OK:
		_status.text = "Impossible d'héberger (port %d occupé ?)" % Network.DEFAULT_PORT


func _on_join_pressed() -> void:
	_use_name()
	var err := Network.join(_address.text.strip_edges())
	_status.text = "Connexion..." if err == OK else "Adresse invalide"


## Le pseudo identifie la sauvegarde du joueur chez l'hôte.
func _use_name() -> void:
	if Game.profiles != null:
		var typed := _name.text.strip_edges()
		Game.profiles.local_name = typed if not typed.is_empty() else PlayerProfiles.DEFAULT_NAME


func _on_session_started() -> void:
	_panel.visible = false
	_status.text = ""
	_hud.text = "Hôte" if multiplayer.is_server() else "Client"
	_hud.text += " - Échap : menu"
	_hud.visible = true


func _on_session_ended() -> void:
	_panel.visible = true
	_hud.visible = false
	_status.text = "Session terminée"


func _on_connection_failed() -> void:
	_status.text = "Connexion échouée"
