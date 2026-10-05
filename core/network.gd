extends Node
## Autoload "Network" : crée / rejoint / quitte une session multijoueur (ENet).

signal session_started
signal session_ended
signal connection_failed

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 4

## Vrai tant qu'une session (hôte ou client) est en cours.
var active := false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(leave)


func host(port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	# L'hôte compte comme un joueur, d'où MAX_PLAYERS - 1 clients.
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	active = true
	session_started.emit()
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func leave() -> void:
	if active:
		active = false
		session_ended.emit()
	var peer := multiplayer.multiplayer_peer
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if peer != null and not peer is OfflineMultiplayerPeer:
		peer.close()


func _on_connected_to_server() -> void:
	active = true
	session_started.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connection_failed.emit()
