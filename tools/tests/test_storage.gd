extends SceneTree
## Tests du PC de stockage (logique seule, sans interface ni réseau) : dépôt, retrait,
## déplacements, échanges, boîtes pleines, équipe pleine, dernier Pokémon apte, soin au
## dépôt, sauvegarde puis rechargement, anciennes sauvegardes, intégrité.
##
##   godot --headless --path . -s res://tools/tests/test_storage.gd

const CHARMANDER := preload("res://data/pokemon/charmander.tres")
const BULBASAUR := preload("res://data/pokemon/bulbasaur.tres")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_test_config()
	_test_deposit_and_withdraw()
	_test_moves_and_swaps()
	_test_limits()
	_test_last_usable()
	_test_heal_on_deposit()
	_test_save_round_trip()
	_test_old_save()
	_test_integrity()
	print("Tests du PC de stockage : %d réussis, %d ratés" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _player(count := 2) -> PlayerData:
	var data := PlayerData.new()
	var party: Array[PokemonInstance] = []
	for i in count:
		party.append(PokemonInstance.create(CHARMANDER if i % 2 == 0 else BULBASAUR, 5 + i))
	data.party = party
	return data


func _test_config() -> void:
	var storage := PokemonStorage.new()
	_check(storage.boxes.size() == 8, "8 boîtes par défaut")
	_check(storage.boxes[0].capacity() == 30, "30 places par boîte")
	_check(storage.boxes[0].name == "Boîte 1" and storage.boxes[7].name == "Boîte 8", "noms par défaut")
	_check(storage.boxes[0].id != storage.boxes[1].id, "identifiants de boîte distincts")
	_check(storage.boxes[0].is_empty(), "boîte vide au départ")


func _test_deposit_and_withdraw() -> void:
	var data := _player(3)
	var storage := data.storage
	var second := data.party[1]
	_check(storage.deposit(data.party, 1, 0) == "", "dépôt d'un Pokémon de l'équipe")
	_check(data.party.size() == 2 and not second in data.party, "il quitte l'équipe")
	_check(storage.boxes[0].slots[0] == second, "il est à la première place de la boîte (même objet)")
	_check(storage.withdraw(data.party, 0, 0) == "", "retrait vers l'équipe")
	_check(data.party.size() == 3 and data.party[2] == second and storage.boxes[0].is_empty(), "il revient en fin d'équipe")


func _test_moves_and_swaps() -> void:
	var data := _player(3)
	var storage := data.storage
	var a := data.party[1]
	var b := data.party[2]
	storage.deposit(data.party, 2, 0)
	storage.deposit(data.party, 1, 1)
	# Entre deux boîtes, vers une place vide.
	_check(storage.move(data.party, Vector2i(0, 0), Vector2i(1, 7)) == "", "déplacement vers une autre boîte")
	_check(storage.boxes[0].is_empty() and storage.boxes[1].slots[7] == b, "la place d'arrivée est la bonne")
	# Échange de deux Pokémon de boîte.
	_check(storage.move(data.party, Vector2i(1, 0), Vector2i(1, 7)) == "", "échange dans une boîte")
	_check(storage.boxes[1].slots[0] == b and storage.boxes[1].slots[7] == a, "les deux ont échangé leur place")
	# Échange boîte <-> équipe.
	var lead := data.party[0]
	_check(storage.move(data.party, Vector2i(1, 0), PokemonStorage.party_slot(0)) == "", "échange entre une boîte et l'équipe")
	_check(data.party[0] == b and storage.boxes[1].slots[0] == lead, "le Pokémon de l'équipe va dans la boîte")
	# Réordonner l'équipe.
	storage.withdraw(data.party, 1, 7)
	var first := data.party[0]
	var last := data.party[1]
	_check(storage.move(data.party, PokemonStorage.party_slot(0), PokemonStorage.party_slot(1)) == "", "échange dans l'équipe")
	_check(data.party[0] == last and data.party[1] == first, "ordre de l'équipe modifié")
	_check(storage.move(data.party, Vector2i(1, 0), Vector2i(1, 0)) == "", "déposer à sa propre place ne change rien")
	_check(storage.move(data.party, Vector2i(2, 0), Vector2i(1, 3)) != "", "refus : place de départ vide")
	_check(storage.move(data.party, Vector2i(1, 0), Vector2i(9, 0)) != "", "refus : boîte inexistante")
	_check(storage.move(data.party, Vector2i(1, 0), Vector2i(1, 30)) != "", "refus : place hors de la boîte")
	_check(storage.validate(data.party).is_empty(), "intégrité après les déplacements")


func _test_limits() -> void:
	# Boîte pleine.
	var data := _player(2)
	var storage := data.storage
	for i in 30:
		storage.boxes[0].slots[i] = PokemonInstance.create(BULBASAUR, 3)
	_check(storage.boxes[0].is_full(), "boîte pleine")
	var before := data.party.size()
	_check(storage.deposit(data.party, 1, 0) != "", "refus : dépôt dans une boîte pleine")
	_check(data.party.size() == before and storage.boxes[0].count() == 30, "rien n'a changé")
	# Équipe pleine.
	var full := _player(6)
	full.storage.boxes[2].slots[4] = PokemonInstance.create(BULBASAUR, 3)
	var waiting: PokemonInstance = full.storage.boxes[2].slots[4]
	_check(full.storage.withdraw(full.party, 2, 4) != "", "refus : retrait avec une équipe pleine")
	_check(full.party.size() == 6 and full.storage.boxes[2].slots[4] == waiting, "le Pokémon reste dans sa boîte")
	_check(full.storage.move(full.party, Vector2i(2, 4), PokemonStorage.party_slot(3)) == "", "échange possible même équipe pleine")
	_check(full.party[3] == waiting and full.party.size() == 6, "il remplace un Pokémon de l'équipe")


func _test_last_usable() -> void:
	var data := _player(1)
	_check(data.storage.deposit(data.party, 0, 0) != "", "refus : déposer le dernier Pokémon de l'équipe")
	_check(data.party.size() == 1 and data.storage.count() == 0, "il reste dans l'équipe")
	# Le seul Pokémon apte, à côté d'un K.O.
	var two := _player(2)
	two.party[1].current_hp = 0
	_check(two.storage.deposit(two.party, 0, 0) != "", "refus : déposer le dernier Pokémon en état de se battre")
	_check(two.storage.deposit(two.party, 1, 0) == "", "on peut déposer le Pokémon K.O.")


func _test_heal_on_deposit() -> void:
	var data := _player(2)
	var hurt := data.party[1]
	hurt.current_hp = 3
	hurt.status = &"poison"
	data.storage.deposit(data.party, 1, 0)
	_check(hurt.hp() == hurt.max_hp() and hurt.status.is_empty(), "un Pokémon déposé est soigné")


func _test_save_round_trip() -> void:
	var data := _player(3)
	var stored := data.party[2]
	stored.nickname = "Flammy"
	stored.experience = 1234
	stored.held_item = load("res://data/items/potion.tres")
	stored.move_pp[0] = 7
	stored.gender = &"female"
	stored.original_trainer = "Arman"
	stored.met_location = "Accumula"
	stored.met_level = 5
	data.storage.deposit(data.party, 2, 4)
	data.storage.move(data.party, Vector2i(4, 0), Vector2i(4, 17))
	data.storage.rename(4, "Équipe feu")
	data.storage.set_wallpaper(4, 12)
	var json := JSON.stringify(data.to_dict())
	var loaded := PlayerData.from_dict(JSON.parse_string(json))
	var box := loaded.storage.boxes[4]
	var copy := box.slots[17] as PokemonInstance
	_check(box.name == "Équipe feu" and box.wallpaper == 12 and box.id == data.storage.boxes[4].id, "nom, fond et identifiant de la boîte conservés")
	_check(copy != null and copy.uid == stored.uid, "le Pokémon est à sa place, même identifiant")
	_check(copy != null and copy.nickname == "Flammy" and copy.experience == 1234 and copy.level == stored.level
		and copy.species == stored.species and copy.nature == stored.nature and copy.ivs == stored.ivs
		and copy.held_item == stored.held_item and copy.moves == stored.moves, "toutes ses données conservées")
	_check(copy != null and copy.gender == &"female" and copy.original_trainer == "Arman" and copy.met_location == "Accumula"
		and copy.met_level == 5, "genre et origine conservés")
	_check(loaded.party.size() == 2 and loaded.storage.count() == 1, "aucun Pokémon dupliqué ni perdu")
	_check(loaded.storage.validate(loaded.party).is_empty(), "intégrité après rechargement")
	_check(loaded.storage.boxes.size() == 8, "les 8 boîtes rechargées")


func _test_old_save() -> void:
	# Sauvegarde de version 1 : ni PC, ni identifiants de Pokémon.
	var data := _player(2)
	var old := data.to_dict()
	old.erase("storage")
	for entry in old["party"]:
		entry.erase("uid")
	var loaded := PlayerData.from_dict(old)
	_check(loaded.party.size() == 2, "ancienne sauvegarde : l'équipe est intacte")
	_check(loaded.storage.boxes.size() == 8 and loaded.storage.count() == 0, "ancienne sauvegarde : boîtes vides créées")
	_check(not loaded.party[0].uid.is_empty() and loaded.party[0].uid != loaded.party[1].uid, "ancienne sauvegarde : identifiants créés")
	var old_genders := []
	for entry in _player(1).to_dict()["party"]:
		entry.erase("gender")
		old_genders.append(PokemonInstance.from_dict(entry).gender)
	_check(old_genders[0] in [&"male", &"female"], "ancienne sauvegarde : genre tiré d'après l'espèce")
	# Pokémon sauvegardé à une place impossible : rangé ailleurs, pas perdu.
	var bad := _player(1).to_dict()
	var pokemon_dict: Dictionary = _player(1).party[0].to_dict()
	bad["storage"] = {"boxes": [{"id": "box_1", "name": "A", "capacity": 30, "pokemon": [{"slot": 99, "pokemon": pokemon_dict}]}]}
	var fixed := PlayerData.from_dict(bad)
	_check(fixed.storage.count() == 1, "place invalide : le Pokémon est rangé ailleurs, pas perdu")


func _test_integrity() -> void:
	var data := _player(2)
	data.storage.boxes[3].slots[0] = data.party[1]
	_check(not data.storage.validate(data.party).is_empty(), "un même Pokémon dans l'équipe et une boîte est détecté")
	var twin := _player(2)
	twin.storage.boxes[0].slots[0] = PokemonInstance.create(BULBASAUR, 4)
	twin.storage.boxes[0].slots[1] = PokemonInstance.create(BULBASAUR, 4)
	twin.storage.boxes[0].slots[1].uid = twin.storage.boxes[0].slots[0].uid
	_check(not twin.storage.validate(twin.party).is_empty(), "deux Pokémon au même identifiant sont détectés")
	var reloaded := PlayerData.from_dict(twin.to_dict())
	_check(reloaded.storage.validate(reloaded.party).is_empty(), "au rechargement, l'identifiant en double est corrigé")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  ÉCHEC : ", label)
