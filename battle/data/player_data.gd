class_name PlayerData
extends Resource
## Ce qu'un joueur possède et où il en est : son nom, son équipe, son PC de stockage,
## son sac, son argent et sa position. Conservé par l'hôte (qui fait autorité) pour chaque joueur connecté,
## et sauvegardé par lui (voir PlayerProfiles et SaveService).

const MAX_PARTY := 6

@export var party: Array[PokemonInstance] = []
## Boîtes du PC (les Pokémon hors de l'équipe).
var storage: PokemonStorage = PokemonStorage.new()
@export var bag: Bag = Bag.new()
@export var money := 0
## Pseudo du joueur, qui identifie sa sauvegarde.
@export var player_name := ""
## Dernière position connue ; carte vide = nouvelle partie (case de départ).
@export var map_id: StringName
@export var cell := Vector2i.ZERO
@export var facing := Vector2i.DOWN
## Temps de jeu, en secondes.
@export var play_time := 0.0


func has_usable_pokemon() -> bool:
	for pokemon in party:
		if pokemon != null and not pokemon.is_fainted():
			return true
	return false


## Accueille un nouveau Pokémon (capture) : dans l'équipe s'il y a de la place, sinon
## au PC. Renvoie le message à afficher.
func receive_pokemon(pokemon: PokemonInstance) -> String:
	if party.size() < MAX_PARTY:
		party.append(pokemon)
		return "%s rejoint l'équipe !" % pokemon.display_name()
	var box := storage.store(pokemon)
	return "%s est envoyé au PC (%s)." % [pokemon.display_name(), box.name if box != null else "PC"]


## Soigne toute l'équipe (Centre Pokémon, ou après une défaite).
func heal_party() -> void:
	for pokemon in party:
		pokemon.restore()


## Données à sauvegarder : un dictionnaire de valeurs simples, jamais de nœuds.
func to_dict() -> Dictionary:
	var team := []
	for pokemon in party:
		team.append(pokemon.to_dict())
	return {
		"player_name": player_name,
		"party": team,
		"bag": bag.to_dict(),
		"money": money,
		"map_id": String(map_id),
		"cell": [cell.x, cell.y],
		"facing": [facing.x, facing.y],
		"play_time": play_time,
		"storage": storage.to_dict(),
	}


static func from_dict(data: Dictionary) -> PlayerData:
	var result := PlayerData.new()
	result.player_name = data.get("player_name", "")
	var team: Array[PokemonInstance] = []
	for entry in data.get("party", []):
		var pokemon := PokemonInstance.from_dict(entry)
		if pokemon != null:
			team.append(pokemon)
	result.party = team
	result.bag = Bag.from_dict(data.get("bag", {}))
	result.money = int(data.get("money", 0))
	result.map_id = StringName(data.get("map_id", ""))
	var c: Array = data.get("cell", [0, 0])
	result.cell = Vector2i(int(c[0]), int(c[1]))
	var f: Array = data.get("facing", [0, 1])
	result.facing = Vector2i(int(f[0]), int(f[1]))
	result.play_time = float(data.get("play_time", 0.0))
	# Sauvegarde d'avant le PC : boîtes vides.
	result.storage = PokemonStorage.from_dict(data.get("storage", {}))
	result._fix_duplicate_uids()
	return result


## Deux Pokémon avec le même identifiant (sauvegarde abîmée) : le second en reçoit un neuf.
func _fix_duplicate_uids() -> void:
	var seen := {}
	var all: Array = party.duplicate()
	for box in storage.boxes:
		for pokemon in box.slots:
			if pokemon != null:
				all.append(pokemon)
	for pokemon: PokemonInstance in all:
		if seen.has(pokemon.uid):
			push_warning("PlayerData : identifiant en double pour %s, remplacé" % pokemon.display_name())
			pokemon.uid = PokemonInstance.new_uid()
		seen[pokemon.uid] = true
