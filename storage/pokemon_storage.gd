class_name PokemonStorage
extends RefCounted
## Le PC de stockage d'un joueur : ses boîtes, et toutes les règles pour y déposer, en
## retirer, déplacer ou échanger des Pokémon. Seul endroit où ces règles sont écrites :
## l'interface ne fait que demander une opération (chez l'hôte, voir PlayerProfiles) et
## afficher le résultat.
##
## Un emplacement est désigné par un Vector2i(zone, place) :
## - zone PARTY (-1) : l'équipe, place 0 à 5 (une place après le dernier Pokémon = libre) ;
## - zone 0, 1, 2… : la boîte de cet indice, place 0 à capacité - 1.
## Toute opération est vérifiée avant de toucher aux données : si elle est refusée, rien
## ne change. Les Pokémon sont toujours les mêmes objets PokemonInstance : jamais copiés.

const PARTY := -1
const DEFAULT_CONFIG := "res://data/config/storage.tres"

var config: StorageConfig
var boxes: Array[PokemonBox] = []


func _init(p_config: StorageConfig = null) -> void:
	config = p_config if p_config != null else load(DEFAULT_CONFIG) as StorageConfig
	ensure_boxes()


## Ajoute les boîtes manquantes d'après la configuration (une sauvegarde qui en a plus
## les garde toutes).
func ensure_boxes() -> void:
	while boxes.size() < config.box_count:
		var i := boxes.size()
		boxes.append(PokemonBox.new(StringName("box_%d" % (i + 1)), config.default_box_name(i),
			config.box_capacity, config.default_wallpaper(i)))


static func party_slot(index: int) -> Vector2i:
	return Vector2i(PARTY, index)


static func box_slot(box: int, index: int) -> Vector2i:
	return Vector2i(box, index)


## Pokémon à un emplacement, ou null (place vide ou invalide).
func get_pokemon(party: Array[PokemonInstance], at: Vector2i) -> PokemonInstance:
	if at.x == PARTY:
		return party[at.y] if at.y >= 0 and at.y < party.size() else null
	if at.x < 0 or at.x >= boxes.size():
		return null
	return boxes[at.x].get_pokemon(at.y)


## Vrai si l'emplacement existe (même vide).
func is_valid(at: Vector2i) -> bool:
	if at.x == PARTY:
		return at.y >= 0 and at.y < PlayerData.MAX_PARTY
	return at.x >= 0 and at.x < boxes.size() and at.y >= 0 and at.y < boxes[at.x].capacity()


## Déplace le Pokémon de `from` vers `to` : vers une place vide, il s'y installe ; vers une
## place occupée, les deux Pokémon s'échangent. Renvoie un message d'erreur, ou "" si
## l'opération a été faite. En cas d'erreur, rien n'a changé.
func move(party: Array[PokemonInstance], from: Vector2i, to: Vector2i) -> String:
	if not is_valid(from) or not is_valid(to):
		return "Emplacement invalide."
	var moving := get_pokemon(party, from)
	if moving == null:
		return "Il n'y a pas de Pokémon ici."
	if from == to:
		return ""
	var other := get_pokemon(party, to)
	# État après l'opération, calculé à part : l'équipe et les places des boîtes touchées.
	var new_party: Array[PokemonInstance] = party.duplicate()
	var box_changes := {}  # Vector2i -> PokemonInstance ou null
	if from.x == PARTY and to.x == PARTY:
		if other == null:
			new_party.erase(moving)
			new_party.append(moving)
		else:
			new_party[from.y] = other
			new_party[to.y] = moving
	elif from.x == PARTY:
		box_changes[to] = moving
		if other == null:
			new_party.remove_at(from.y)
		else:
			new_party[from.y] = other
	elif to.x == PARTY:
		if other == null:
			if party.size() >= PlayerData.MAX_PARTY:
				return "Votre équipe est pleine."
			new_party.append(moving)
		else:
			new_party[to.y] = moving
		box_changes[from] = other
	else:
		box_changes[to] = moving
		box_changes[from] = other
	if (from.x == PARTY or to.x == PARTY) and not _has_usable(new_party):
		return "Il faut garder au moins un Pokémon en état de se battre dans l'équipe."
	# Tout est valide : on applique.
	for at: Vector2i in box_changes:
		boxes[at.x].slots[at.y] = box_changes[at]
	party.assign(new_party)
	# Un Pokémon déposé dans une boîte est soigné.
	if config.heal_on_deposit:
		for at: Vector2i in box_changes:
			if box_changes[at] != null and box_changes[at] in [moving, other] and _came_from_party(box_changes[at], from, to, moving, other):
				(box_changes[at] as PokemonInstance).restore()
	return ""


## Dépose le Pokémon de l'équipe `party_index` à la première place libre de la boîte.
func deposit(party: Array[PokemonInstance], party_index: int, box: int) -> String:
	if box < 0 or box >= boxes.size():
		return "Boîte invalide."
	var free := boxes[box].first_free()
	if free == -1:
		return "Cette boîte est pleine."
	return move(party, party_slot(party_index), box_slot(box, free))


## Retire le Pokémon d'une boîte et l'ajoute à la fin de l'équipe.
func withdraw(party: Array[PokemonInstance], box: int, slot: int) -> String:
	if party.size() >= PlayerData.MAX_PARTY:
		return "Votre équipe est pleine."
	return move(party, box_slot(box, slot), party_slot(party.size()))


func rename(box: int, new_name: String) -> String:
	if box < 0 or box >= boxes.size():
		return "Boîte invalide."
	var clean := new_name.strip_edges().left(config.name_max_length)
	boxes[box].name = clean if not clean.is_empty() else config.default_box_name(box)
	return ""


func set_wallpaper(box: int, wallpaper: int) -> String:
	if box < 0 or box >= boxes.size() or wallpaper < 0:
		return "Fond invalide."
	boxes[box].wallpaper = wallpaper
	return ""


## Nombre total de Pokémon dans les boîtes.
func count() -> int:
	var n := 0
	for box in boxes:
		n += box.count()
	return n


## Vérifie l'intégrité de l'équipe et des boîtes ; renvoie les problèmes trouvés (vide :
## tout va bien). Un Pokémon ne doit être qu'à un seul endroit.
func validate(party: Array[PokemonInstance]) -> PackedStringArray:
	var problems := PackedStringArray()
	var seen := {}
	var places := []
	for i in party.size():
		places.append([party[i], "équipe %d" % (i + 1)])
	for b in boxes.size():
		if boxes[b].capacity() < config.box_capacity:
			problems.append("%s : capacité %d trop petite" % [boxes[b].name, boxes[b].capacity()])
		for s in boxes[b].capacity():
			if boxes[b].slots[s] != null:
				places.append([boxes[b].slots[s], "%s place %d" % [boxes[b].name, s + 1]])
	for entry in places:
		var pokemon: PokemonInstance = entry[0]
		if pokemon == null:
			problems.append("%s : place vide dans l'équipe" % entry[1])
			continue
		var key: String = pokemon.uid if not pokemon.uid.is_empty() else str(pokemon.get_instance_id())
		if seen.has(key):
			problems.append("%s est à la fois en %s et en %s" % [pokemon.display_name(), seen[key], entry[1]])
		else:
			seen[key] = entry[1]
	return problems


func to_dict() -> Dictionary:
	var list := []
	for box in boxes:
		list.append(box.to_dict())
	return {"boxes": list}


## Recrée le stockage sauvegardé. Une sauvegarde sans PC donne des boîtes vides ; un
## Pokémon mal placé est rangé à la première place libre, jamais perdu.
static func from_dict(data: Dictionary, p_config: StorageConfig = null) -> PokemonStorage:
	var storage := PokemonStorage.new(p_config)
	if data.is_empty():
		return storage
	var problems := PackedStringArray()
	var overflow := []
	var loaded: Array[PokemonBox] = []
	for entry in data.get("boxes", []):
		var box := PokemonBox.from_dict(entry, storage.config.box_capacity, problems, overflow)
		if String(box.id).is_empty():
			box.id = StringName("box_%d" % (loaded.size() + 1))
		if box.name.is_empty():
			box.name = storage.config.default_box_name(loaded.size())
		loaded.append(box)
	storage.boxes = loaded
	storage.ensure_boxes()
	for pokemon in overflow:
		storage._store_anywhere(pokemon)
	for problem in problems:
		push_warning("PokemonStorage : " + problem)
	return storage


## Range un Pokémon à la première place libre (Pokémon capturé, équipe pleine). Renvoie
## la boîte où il est rangé.
func store(pokemon: PokemonInstance) -> PokemonBox:
	_store_anywhere(pokemon)
	for box in boxes:
		if pokemon in box.slots:
			return box
	return null


## Range un Pokémon à la première place libre, en ajoutant une boîte s'il le faut.
func _store_anywhere(pokemon: PokemonInstance) -> void:
	for box in boxes:
		var free := box.first_free()
		if free != -1:
			box.slots[free] = pokemon
			return
	var i := boxes.size()
	var box := PokemonBox.new(StringName("box_%d" % (i + 1)), config.default_box_name(i), config.box_capacity, config.default_wallpaper(i))
	box.slots[0] = pokemon
	boxes.append(box)


static func _has_usable(party: Array[PokemonInstance]) -> bool:
	for pokemon in party:
		if pokemon != null and not pokemon.is_fainted():
			return true
	return false


## Vrai si ce Pokémon, maintenant dans une boîte, vient de l'équipe.
static func _came_from_party(pokemon: PokemonInstance, from: Vector2i, to: Vector2i, moving: PokemonInstance, other: PokemonInstance) -> bool:
	return (pokemon == moving and from.x == PARTY) or (pokemon == other and to.x == PARTY)
