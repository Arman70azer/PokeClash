class_name PlayerProfiles
extends Node
## Données de chaque joueur (PlayerData), gardées et sauvegardées par l'hôte.
##
## À la connexion, chaque joueur annonce son pseudo ; l'hôte charge sa sauvegarde (ou lui
## crée une nouvelle partie d'après data/config/new_game.tres), puis émet profile_ready :
## le monde fait alors apparaître le joueur là où il s'était arrêté.
## L'hôte sauvegarde un joueur quand il part, à la fin de la session, en quittant le jeu,
## après un combat ou un soin, et toutes les AUTOSAVE_INTERVAL secondes.
## À placer une fois dans la scène principale (même chemin chez tous les joueurs).

## Un joueur a ses données chargées : il peut apparaître (chez l'hôte).
signal profile_ready(peer_id: int)
## Copie des données du joueur de cet ordinateur, reçue de l'hôte (menu du jeu).
signal snapshot_received(data: PlayerData)
## Résultat d'une demande du menu (objet utilisé, partie sauvegardée…), à afficher.
signal request_answered(message: String)

const NEW_GAME := preload("res://data/config/new_game.tres")
const AUTOSAVE_INTERVAL := 60.0
const DEFAULT_NAME := "Joueur"

## Pseudo du joueur de cet ordinateur (saisi dans le menu).
var local_name := DEFAULT_NAME

var _profiles := {}  # identifiant réseau -> PlayerData (chez l'hôte)
var _autosave := 0.0


func _enter_tree() -> void:
	Game.register(&"profiles", self)


func _ready() -> void:
	Network.session_started.connect(_on_session_started)
	Network.session_ended.connect(_on_session_ended)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(delta: float) -> void:
	if not (Network.active and multiplayer.is_server()):
		return
	for profile in _profiles.values():
		profile.play_time += delta
	_autosave += delta
	if _autosave >= AUTOSAVE_INTERVAL:
		_autosave = 0.0
		save_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and Network.active and multiplayer.is_server():
		save_all()


## Données d'un joueur (chez l'hôte), ou null s'il ne s'est pas encore annoncé.
func data(peer_id: int) -> PlayerData:
	return _profiles.get(peer_id)


func has_profile(peer_id: int) -> bool:
	return _profiles.has(peer_id)


## Sauvegarde un joueur, position comprise (chez l'hôte).
func save(peer_id: int) -> void:
	var profile := data(peer_id)
	if profile == null:
		return
	# Le nœud du joueur peut être en cours de suppression (départ, fin de session).
	var player := Game.world.players.get_node_or_null(str(peer_id)) as Player if Game.world != null else null
	if player != null and not player.map_id.is_empty():
		profile.map_id = player.map_id
		profile.cell = player.cell
		profile.facing = player.facing
		# En expédition : la zone disparaît à la fin, on sauvegarde le retour.
		if player.map_id == ExpeditionService.MAP_ID:
			profile.map_id = ExpeditionService.RETURN_MAP
			profile.cell = ExpeditionService.RETURN_CELL
			profile.facing = ExpeditionService.RETURN_FACING
	SaveService.save(profile)


func save_all() -> void:
	for peer_id in _profiles:
		save(peer_id)


# --- Demandes du menu du jeu ------------------------------------------------------------
# Le joueur de cet ordinateur demande ; l'hôte, qui a les données, répond avec une copie
# à jour (snapshot_received) et un message (request_answered).

## Demande une copie à jour de ses données.
func request_snapshot() -> void:
	_ask(&"_handle_snapshot", [])


## Demande à l'hôte de sauvegarder sa partie.
func request_save() -> void:
	_ask(&"_handle_save", [])


## Demande à acheter `quantity` objets dans une boutique.
func request_buy(shop_path: String, item_path: String, quantity: int) -> void:
	_ask(&"_handle_buy", [shop_path, item_path, quantity])


## Demande à vendre `quantity` objets du sac.
func request_sell(item_path: String, quantity: int) -> void:
	_ask(&"_handle_sell", [item_path, quantity])


## PC de stockage : déplace le Pokémon de `from` vers `to` (voir PokemonStorage.move).
func request_pc_move(from: Vector2i, to: Vector2i) -> void:
	_ask(&"_handle_pc_move", [from, to])


## PC de stockage : renomme une boîte.
func request_pc_rename(box: int, new_name: String) -> void:
	_ask(&"_handle_pc_rename", [box, new_name])


## PC de stockage : change le fond d'une boîte.
func request_pc_wallpaper(box: int, wallpaper: int) -> void:
	_ask(&"_handle_pc_wallpaper", [box, wallpaper])


## Demande à utiliser un objet du sac sur un Pokémon de l'équipe.
func request_use_item(item_path: String, party_index: int) -> void:
	_ask(&"_handle_use_item", [item_path, party_index])


func _ask(method: StringName, args: Array) -> void:
	if not Network.active:
		return
	if multiplayer.is_server():
		callv(method, [multiplayer.get_unique_id()] + args)
	else:
		rpc_id.callv([1, &"_forward"] + [method, args])


@rpc("any_peer", "call_remote", "reliable")
func _forward(method: StringName, args: Array) -> void:
	if multiplayer.is_server() and method in [&"_handle_snapshot", &"_handle_save", &"_handle_use_item", &"_handle_buy", &"_handle_sell",
			&"_handle_pc_move", &"_handle_pc_rename", &"_handle_pc_wallpaper"]:
		callv(method, [multiplayer.get_remote_sender_id()] + args)


func _handle_snapshot(peer_id: int) -> void:
	_reply(peer_id, "")


func _handle_save(peer_id: int) -> void:
	if data(peer_id) == null:
		return
	save(peer_id)
	_reply(peer_id, "%s a sauvegardé la partie." % data(peer_id).player_name)


func _handle_use_item(peer_id: int, item_path: String, party_index: int) -> void:
	var profile := data(peer_id)
	if profile == null or Game.battles == null or Game.battles.is_in_battle(peer_id):
		return
	if not ResourceLoader.exists(item_path) or party_index < 0 or party_index >= profile.party.size():
		return
	var item := load(item_path) as ItemData
	if item == null or profile.bag.count(item) <= 0:
		_reply(peer_id, "Il n'y en a plus.")
		return
	var pokemon: PokemonInstance = profile.party[party_index]
	var refused := item.can_use_on_pokemon(pokemon)
	if not refused.is_empty():
		_reply(peer_id, refused)
		return
	var message := item.use_on_pokemon(pokemon)
	profile.bag.remove(item)
	save(peer_id)
	_reply(peer_id, message)


func _handle_buy(peer_id: int, shop_path: String, item_path: String, quantity: int) -> void:
	var profile := data(peer_id)
	if profile == null or quantity <= 0 or quantity > 99:
		return
	if not ResourceLoader.exists(shop_path) or not ResourceLoader.exists(item_path):
		return
	var shop := load(shop_path) as ShopData
	var item := load(item_path) as ItemData
	if shop == null or item == null or not shop.sells(item):
		return
	var cost := item.price * quantity
	if cost > profile.money:
		_reply(peer_id, "Vous n'avez pas assez d'argent.")
		return
	profile.money -= cost
	profile.bag.add(item, quantity)
	save(peer_id)
	_reply(peer_id, "Voici %s ! Merci beaucoup !" % _quantity_name(item, quantity))


func _handle_sell(peer_id: int, item_path: String, quantity: int) -> void:
	var profile := data(peer_id)
	if profile == null or quantity <= 0 or not ResourceLoader.exists(item_path):
		return
	var item := load(item_path) as ItemData
	var price := ShopData.sell_price(item)
	if price <= 0:
		_reply(peer_id, "Je ne peux pas acheter ça, désolé.")
		return
	if not profile.bag.remove(item, quantity):
		_reply(peer_id, "Vous n'en avez pas autant.")
		return
	profile.money += price * quantity
	save(peer_id)
	_reply(peer_id, "Vous avez vendu %s pour %d Pokédollars." % [_quantity_name(item, quantity), price * quantity])


func _handle_pc_move(peer_id: int, from: Vector2i, to: Vector2i) -> void:
	var profile := data(peer_id)
	if profile == null:
		return
	if Game.battles != null and Game.battles.is_in_battle(peer_id):
		_reply(peer_id, "Impossible pendant un combat.")
		return
	var refused := profile.storage.move(profile.party, from, to)
	var problems := profile.storage.validate(profile.party)
	if not problems.is_empty():
		push_error("PC de %s : %s" % [profile.player_name, ", ".join(problems)])
	if refused.is_empty():
		save(peer_id)
	_reply(peer_id, refused)


func _handle_pc_rename(peer_id: int, box: int, new_name: String) -> void:
	var profile := data(peer_id)
	if profile == null:
		return
	var refused := profile.storage.rename(box, new_name)
	if refused.is_empty():
		save(peer_id)
	_reply(peer_id, refused)


func _handle_pc_wallpaper(peer_id: int, box: int, wallpaper: int) -> void:
	var profile := data(peer_id)
	if profile == null:
		return
	var refused := profile.storage.set_wallpaper(box, clampi(wallpaper, 0, PcSprites.WALLPAPER_COUNT - 1))
	if refused.is_empty():
		save(peer_id)
	_reply(peer_id, refused)


static func _quantity_name(item: ItemData, quantity: int) -> String:
	if quantity == 1:
		return item.name
	# Pluriel simple : « 3 Poké Balls », « 2 Super Potions ».
	var plural := item.name if item.name.ends_with("s") or item.name.ends_with("x") else item.name + "s"
	return "%d %s" % [quantity, plural]


## Envoie au joueur une copie de ses données et un message.
func _reply(peer_id: int, message: String) -> void:
	var profile := data(peer_id)
	if profile == null:
		return
	var snapshot := profile.to_dict()
	if peer_id == multiplayer.get_unique_id():
		_receive(snapshot, message)
	else:
		_receive.rpc_id(peer_id, snapshot, message)


@rpc("authority", "call_remote", "reliable")
func _receive(snapshot: Dictionary, message: String) -> void:
	snapshot_received.emit(PlayerData.from_dict(snapshot))
	if not message.is_empty():
		request_answered.emit(message)


# --- Annonce du pseudo -----------------------------------------------------------------

func _on_session_started() -> void:
	if multiplayer.is_server():
		_register(multiplayer.get_unique_id(), local_name)
	else:
		_announce.rpc_id(1, local_name)


@rpc("any_peer", "call_remote", "reliable")
func _announce(player_name: String) -> void:
	if multiplayer.is_server():
		_register(multiplayer.get_remote_sender_id(), player_name)


func _register(peer_id: int, player_name: String) -> void:
	if _profiles.has(peer_id):
		return
	var name_used := _unique_name(player_name.strip_edges().left(16))
	var profile := SaveService.load_player(name_used)
	if profile == null:
		profile = NEW_GAME.create_player(name_used)
	profile.player_name = name_used
	_profiles[peer_id] = profile
	profile_ready.emit(peer_id)


## Deux joueurs connectés ne peuvent pas partager une sauvegarde : le second reçoit un
## pseudo numéroté.
func _unique_name(player_name: String) -> String:
	var base := player_name if not player_name.is_empty() else DEFAULT_NAME
	var candidate := base
	var n := 2
	while _name_in_use(candidate):
		candidate = "%s %d" % [base, n]
		n += 1
	return candidate


func _name_in_use(player_name: String) -> bool:
	for profile in _profiles.values():
		if SaveService.path_for(profile.player_name) == SaveService.path_for(player_name):
			return true
	return false


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server() and _profiles.has(peer_id):
		save(peer_id)
		_profiles.erase(peer_id)


func _on_session_ended() -> void:
	# Network.leave a déjà coupé la connexion : la position des joueurs est encore connue.
	if not _profiles.is_empty():
		save_all()
	_profiles.clear()
	_autosave = 0.0
