class_name WildPokemon
extends RefCounted
## Pokémon sauvages et équipes des dresseurs d'expédition : une espèce du type de la zone,
## au bon niveau, sous la forme qu'elle aurait à ce niveau (évoluée ou non). Sans état
## (utilisable par les tests).

## Numéro de Pokédex maximal (1re génération pour l'instant).
const MAX_DEX := 151
## Niveau à partir duquel une évolution qui ne se fait pas par le niveau (pierre, échange,
## bonheur) est considérée comme faite.
const OTHER_EVOLUTION_LEVEL := 32
const MAX_TRIES := 12
const INDEX := "res://data/pokemon/index.json"

static var _by_type := {}  # type -> Array[PokemonSpecies]


## Espèces (dans la limite de MAX_DEX) qui ont ce type.
static func species_of_type(type: int) -> Array[PokemonSpecies]:
	if _by_type.has(type):
		return _by_type[type]
	# L'index (écrit par tools/data/import_pokeapi.py) évite de charger les 649 espèces.
	var found: Array[PokemonSpecies] = []
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INDEX)) if FileAccess.file_exists(INDEX) else {}
	for id in index:
		var entry: Dictionary = index[id]
		if int(entry["dex"]) > MAX_DEX or not float(type) in entry["types"]:
			continue
		var species := PokemonSpecies.find(StringName(id))
		if species != null:
			found.append(species)
	found.sort_custom(func(a: PokemonSpecies, b: PokemonSpecies) -> bool: return a.dex_number < b.dex_number)
	_by_type[type] = found
	return found


## Un Pokémon de ce type à ce niveau (sa forme finale a toujours le type demandé).
static func create(type: int, level: int, rng: RandomNumberGenerator) -> PokemonInstance:
	var pool := species_of_type(type)
	if pool.is_empty():
		return null
	var species: PokemonSpecies = null
	for i in MAX_TRIES:
		species = form_at_level(pool[rng.randi_range(0, pool.size() - 1)], level)
		if type in species.types:
			break
	return PokemonInstance.create(species, level, rng)


## Forme d'une espèce à un niveau : elle revient à sa forme précédente si elle est trop
## évoluée pour ce niveau, puis évolue tant que le niveau le permet.
static func form_at_level(species: PokemonSpecies, level: int) -> PokemonSpecies:
	var current := species
	while not String(current.evolves_from).is_empty():
		var previous := PokemonSpecies.find(current.evolves_from)
		if previous == null or previous.dex_number > MAX_DEX or level >= evolution_level(previous, current.id):
			break
		current = previous
	var changed := true
	while changed:
		changed = false
		for evolution in current.evolutions:
			var next := evolution.species()
			if next != null and next.dex_number <= MAX_DEX and level >= evolution_level(current, next.id):
				current = next
				changed = true
				break
	return current


## Niveau auquel `from` devient `to` (OTHER_EVOLUTION_LEVEL pour une pierre, un échange…).
static func evolution_level(from: PokemonSpecies, to: StringName) -> int:
	for evolution in from.evolutions:
		if evolution.species_id == to:
			if evolution.method == EvolutionData.Method.LEVEL and evolution.min_level > 0:
				return evolution.min_level
			return OTHER_EVOLUTION_LEVEL
	return 101
