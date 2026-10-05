extends SceneTree
## Tests des expéditions (logique seule) : génération des 7 zones (même graine, même
## zone ; tout reste atteignable ; dresseurs et herbes bien placés) et Pokémon sauvages
## (type de la zone, forme adaptée au niveau).
##
##   godot --headless --path . -s res://tools/tests/test_expedition.gd

const BIOMES := ["aquatique", "volcan", "foret", "jungle", "desert", "montagne", "cimetiere"]
## 101 et 15851 : la Lagune y bouclait sans fin (mare enfermée), et y perdait tous ses
## dresseurs (mare commencée sur une case déjà en eau).
const SEEDS := [1, 4242, 98765, 101, 15851]

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_test_generation()
	_test_forms()
	_test_wild()
	print("Tests des expéditions : %d réussis, %d ratés" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_generation() -> void:
	for id in BIOMES:
		var biome: ExpeditionBiome = load("res://data/expeditions/%s.tres" % id)
		_check(biome != null and not biome.props.is_empty() and not biome.trainers.is_empty(), "%s : zone chargée" % id)
		for seed in SEEDS:
			var a := ZoneGenerator.new().generate(biome, seed, Vector2i(600, 0))
			var b := ZoneGenerator.new().generate(biome, seed, Vector2i(600, 0))
			var label := "%s (graine %d)" % [id, seed]
			_check(a.walkable == b.walkable and a.props.size() == b.props.size() and a.trainers == b.trainers
				and a.encounter == b.encounter, "%s : même graine, même zone" % label)
			_check(a.walkable.has(a.entry), "%s : l'entrée est praticable" % label)
			_check(a.walkable.size() > 400, "%s : assez de place (%d cases)" % [label, a.walkable.size()])
			var blocked := {}
			for trainer in a.trainers:
				blocked[trainer["cell"]] = true
			_check(a.reachable(a.entry, blocked).size() == a.walkable.size() - blocked.size(),
				"%s : tout est atteignable, dresseurs compris" % label)
			_check(a.trainers.size() >= 3, "%s : au moins trois dresseurs" % label)
			var facing_ok := true
			for trainer in a.trainers:
				facing_ok = facing_ok and a.walkable.has(trainer["cell"] + trainer["facing"])
			_check(facing_ok, "%s : chaque dresseur regarde un passage" % label)
			var grass_ok := a.encounter.size() > 30
			for cell in a.encounter:
				grass_ok = grass_ok and a.walkable.has(cell)
			_check(grass_ok, "%s : hautes herbes praticables (%d cases)" % [label, a.encounter.size()])
			var props_ok := true
			for entry in a.props:
				var prop: ExpeditionProp = entry["prop"]
				for dy in prop.footprint.y:
					for dx in prop.footprint.x:
						props_ok = props_ok and not a.walkable.has(entry["cell"] + Vector2i(dx, dy))
			_check(props_ok, "%s : aucun décor sur une case praticable" % label)
			_check(a.exit_cells.size() == 2 and a.walkable.has(a.exit_cells[0]) and a.walkable.has(a.exit_cells[1]),
				"%s : sortie praticable" % label)
		var regions_ok := true
		for prop in biome.props:
			var image_size := (prop.sheet if prop.sheet != null else TileZone.TILESHEET).get_size()
			regions_ok = regions_ok and Rect2i(Vector2i.ZERO, Vector2i(image_size)).encloses(prop.region)
		_check(regions_ok, "%s : chaque décor est dans son image" % id)
		if id == "cimetiere":
			var graves := biome.props.filter(func(p: ExpeditionProp) -> bool: return p.sheet != null)
			_check(graves.size() >= 3, "cimetière : des tombes parmi les décors (%d)" % graves.size())
		var other := ZoneGenerator.new().generate(biome, SEEDS[1], Vector2i.ZERO)
		var first := ZoneGenerator.new().generate(biome, SEEDS[0], Vector2i.ZERO)
		_check(other.walkable != first.walkable, "%s : une autre graine donne une autre zone" % id)


func _test_forms() -> void:
	var bulbasaur := PokemonSpecies.find(&"bulbasaur")
	var venusaur := PokemonSpecies.find(&"venusaur")
	_check_eq(WildPokemon.form_at_level(bulbasaur, 10).id, &"bulbasaur", "Bulbizarre niveau 10 : Bulbizarre")
	_check_eq(WildPokemon.form_at_level(bulbasaur, 20).id, &"ivysaur", "Bulbizarre niveau 20 : Herbizarre")
	_check_eq(WildPokemon.form_at_level(bulbasaur, 40).id, &"venusaur", "Bulbizarre niveau 40 : Florizarre")
	_check_eq(WildPokemon.form_at_level(venusaur, 8).id, &"bulbasaur", "Florizarre niveau 8 : Bulbizarre")
	_check_eq(WildPokemon.form_at_level(venusaur, 20).id, &"ivysaur", "Florizarre niveau 20 : Herbizarre")
	_check_eq(WildPokemon.form_at_level(PokemonSpecies.find(&"magikarp"), 19).id, &"magikarp", "Magicarpe niveau 19")
	_check_eq(WildPokemon.form_at_level(PokemonSpecies.find(&"magikarp"), 20).id, &"gyarados", "Magicarpe niveau 20 : Léviator")
	_check_eq(WildPokemon.form_at_level(PokemonSpecies.find(&"pikachu"), 40).id, &"raichu", "Pikachu niveau 40 : Raichu (pierre)")
	_check_eq(WildPokemon.form_at_level(PokemonSpecies.find(&"zubat"), 40).id, &"golbat", "Nosferapti niveau 40 : Nosferalto (Nostenfer hors 1re génération)")


func _test_wild() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for id in BIOMES:
		var biome: ExpeditionBiome = load("res://data/expeditions/%s.tres" % id)
		var pool := WildPokemon.species_of_type(biome.type)
		_check(not pool.is_empty(), "%s : des espèces de type %s" % [id, PokemonType.type_name(biome.type)])
		var ok := true
		for i in 30:
			var level := rng.randi_range(3, 60)
			var pokemon := WildPokemon.create(biome.type, level, rng)
			ok = ok and pokemon != null and biome.type in pokemon.species.types and pokemon.level == level \
				and pokemon.species.dex_number <= WildPokemon.MAX_DEX and pokemon.validate().is_empty()
		_check(ok, "%s : Pokémon sauvages du bon type, du bon niveau, de la 1re génération" % id)
	_check_eq(WildPokemon.species_of_type(PokemonType.Type.GHOST).size(), 3, "trois Spectre en 1re génération")


func _check(ok: bool, label: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  ÉCHEC : ", label)


func _check_eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (obtenu %s, attendu %s)" % [label, actual, expected])
