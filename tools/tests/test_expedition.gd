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
	# Les animations ont besoin de l'arbre de scène en marche : après la première image.
	_finish_with_step_effects.call_deferred()


func _finish_with_step_effects() -> void:
	_test_step_effects()
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
			# Murs pleins : chaque case fermée porte un décor (ou du liquide), sauf le
			# chemin de sortie sous l'entrée.
			var covered := {}
			for entry in a.props:
				var prop: ExpeditionProp = entry["prop"]
				for dy in prop.footprint.y:
					for dx in prop.footprint.x:
						covered[entry["cell"] + Vector2i(dx, dy)] = true
			var holes := 0
			for y in a.size.y:
				for x in a.size.x:
					var cell := Vector2i(x, y)
					var exit_lane := y > a.entry.y and (x == a.exit_cells[0].x or x == a.exit_cells[1].x)
					if not a.walkable.has(cell) and not covered.has(cell) and not exit_lane \
							and not a.liquid.has(cell):
						holes += 1
			_check(holes == 0 or not biome.cliffs.is_empty(), "%s : pas de trou dans les murs (%d)" % [label, holes])
			_check(a.exit_cells.size() == 2 and a.walkable.has(a.exit_cells[0]) and a.walkable.has(a.exit_cells[1]),
				"%s : sortie praticable" % label)
		var regions_ok := true
		for prop in biome.props:
			var image_size := (prop.sheet if prop.sheet != null else TileZone.TILESHEET).get_size()
			regions_ok = regions_ok and Rect2i(Vector2i.ZERO, Vector2i(image_size)).encloses(prop.region)
		_check(regions_ok, "%s : chaque décor est dans son image" % id)
		if id == "foret":
			var models := biome.props.filter(func(p: ExpeditionProp) -> bool: return p.mesh != null)
			_check(models.size() == biome.props.size() and biome.encounter_mesh != null and biome.sheet != null,
				"forêt : arbres, souches et hautes herbes en 3D, sol de Lostlorn Forest")
		if id == "aquatique":
			var lagoon := ZoneGenerator.new().generate(biome, SEEDS[0], Vector2i.ZERO)
			var on_islands := true
			for cell in lagoon.encounter:
				on_islands = on_islands and lagoon.rooms.has(cell)
			for entry in lagoon.props:
				on_islands = on_islands and lagoon.rooms.has(entry["cell"])
			var sea := true
			var under_props := {}
			for entry in lagoon.props:
				for dy in entry["prop"].footprint.y:
					for dx in entry["prop"].footprint.x:
						under_props[entry["cell"] + Vector2i(dx, dy)] = true
			for y in lagoon.size.y:
				for x in lagoon.size.x:
					var cell := Vector2i(x, y)
					var lane := y > lagoon.entry.y and (x == lagoon.exit_cells[0].x or x == lagoon.exit_cells[1].x)
					sea = sea and (lagoon.walkable.has(cell) or lane or lagoon.liquid.has(cell) or under_props.has(cell))
			_check(on_islands, "lagune : herbes et décors sur les îlots seulement")
			_check(sea and lagoon.props.all(func(e: Dictionary) -> bool: return e["prop"].mesh != null),
				"lagune : la mer entoure les passages, palmiers et rochers en 3D")
		if id == "montagne":
			_check(biome.cliffs.size() == 2 and not biome.cliffs[1].stretch_bands,
				"montagne : terrasses et sommets enneigés")
		if id == "cimetiere":
			var graves := biome.props.filter(func(p: ExpeditionProp) -> bool: return p.sheet != null)
			_check(graves.size() >= 3, "cimetière : des tombes parmi les décors (%d)" % graves.size())
		var other := ZoneGenerator.new().generate(biome, SEEDS[1], Vector2i.ZERO)
		var first := ZoneGenerator.new().generate(biome, SEEDS[0], Vector2i.ZERO)
		_check(other.walkable != first.walkable, "%s : une autre graine donne une autre zone" % id)


## Un pas dans les rencontres s'anime : herbes de la forêt (et l'herbe devant les pieds),
## sable du désert ; les falaises du désert sont construites.
func _test_step_effects() -> void:
	var forest: ExpeditionBiome = load("res://data/expeditions/foret.tres")
	var zone := ExpeditionZone.new()
	zone.build(ZoneGenerator.new().generate(forest, 7, Vector2i(600, 0)))
	root.add_child(zone)
	var walker := Node3D.new()
	root.add_child(walker)
	var grass_cell: Vector2i = zone.layout.to_world(zone.layout.encounter.keys()[0])
	var before := zone.get_child_count()
	zone.on_step(walker, grass_cell)
	var front := zone.get_node_or_null("FrontGrass")
	_check(front != null, "forêt : l'herbe passe devant les pieds")
	_check(zone.get_child_count() >= before + 4, "forêt : des feuilles s'envolent")
	var bare: Vector2i = Vector2i.ZERO
	for cell in zone.layout.walkable:
		if not zone.layout.encounter.has(cell):
			bare = zone.layout.to_world(cell)
			break
	zone.on_step(walker, bare)
	_check(front != null and not front.visible, "forêt : hors de l'herbe, plus rien devant les pieds")
	var desert: ExpeditionBiome = load("res://data/expeditions/desert.tres")
	var dunes := ExpeditionZone.new()
	dunes.build(ZoneGenerator.new().generate(desert, 7, Vector2i(600, 0)))
	root.add_child(dunes)
	var cliffs := dunes.get_node_or_null("Cliffs") as MeshInstance3D
	_check(cliffs != null and cliffs.mesh.get_surface_count() >= 4, "désert : falaises construites")
	var sand: Vector2i = dunes.layout.to_world(dunes.layout.encounter.keys()[0])
	var count := dunes.get_child_count()
	dunes.on_step(walker, sand)
	_check(dunes.get_child_count() == count + 3, "désert : le sable vole dans les rencontres")
	dunes.on_step(walker, dunes.layout.to_world(dunes.layout.entry))
	_check(dunes.get_child_count() == count + 3, "désert : rien hors des rencontres")
	for node in [zone, dunes, walker]:
		node.queue_free()


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
