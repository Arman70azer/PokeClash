class_name NewGameConfig
extends Resource
## Ce que reçoit un joueur qui commence une partie (data/config/new_game.tres) : son
## premier Pokémon, les Pokémon déjà rangés dans son PC, ses objets et son argent. Sa
## position de départ est celle de la carte de départ du monde (World.start_map,
## GameMap.spawn_cells).

## Pokémon de départ, en attendant le choix du starter.
@export var starter: PokemonSpecies
@export_range(1, 100) var starter_level := 5
## Objets de départ et leur quantité, dans le même ordre.
@export var items: Array[ItemData] = []
@export var item_counts := PackedInt32Array()
@export var money := 0
## Lieu de rencontre noté sur les Pokémon de départ.
@export var start_location := "Accumula"
## Pokémon déjà rangés dans le PC (boîte 1, dans l'ordre), et leur niveau.
@export var stored_species: Array[PokemonSpecies] = []
@export var stored_levels := PackedInt32Array()


## Nouvelles données de joueur.
func create_player(player_name: String) -> PlayerData:
	var data := PlayerData.new()
	data.player_name = player_name
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var party: Array[PokemonInstance] = []
	if starter != null:
		party.append(_given(PokemonInstance.create(starter, starter_level, rng), player_name))
	data.party = party
	for i in items.size():
		data.bag.add(items[i], item_counts[i] if i < item_counts.size() else 1)
	data.money = money
	for i in stored_species.size():
		var level := stored_levels[i] if i < stored_levels.size() else 5
		var pokemon := _given(PokemonInstance.create(stored_species[i], level, rng), player_name)
		data.storage.boxes[0].slots[i] = pokemon
	return data


## Pokémon donné au joueur : il en est le dresseur d'origine, rencontré au départ.
func _given(pokemon: PokemonInstance, player_name: String) -> PokemonInstance:
	pokemon.original_trainer = player_name
	pokemon.met_location = start_location
	return pokemon
