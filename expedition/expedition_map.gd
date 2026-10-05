class_name ExpeditionMap
extends GameMap
## Carte d'une expédition (maps/expedition) : au chargement, elle construit la zone
## d'après le plan reçu de l'hôte (ExpeditionService.plan) : sol et décors, sortie vers le
## gardien, et dresseurs. Le même plan donne la même carte sur tous les ordinateurs ; les
## nœuds (dresseurs, sortie) ont donc les mêmes noms partout.

const FRONT_SHEET := preload("res://assets/Trainers - Trainers (Front).png")
## Cases du sprite de combat d'un dresseur dans la planche (voir TrainerData).
const FRONT_CELL := Vector2i(81, 98)
const FRONT_ORIGIN := Vector2i(1, 18)
const FRONT_BACKGROUNDS: Array[Color] = [Color(0.5764706, 0.73333335, 0.9254902, 1), Color(0.32941177, 0.64705884, 0.29411766, 1)]
const NAMES := ["Lucas", "Inès", "Hugo", "Léa", "Nathan", "Chloé", "Théo", "Manon", "Enzo", "Camille", "Louis",
	"Jade", "Gabin", "Zoé", "Adam", "Lina", "Arthur", "Rose", "Noé", "Alice", "Sacha", "Mila", "Paul", "Elsa"]
const TEAM_SIZE := Vector2i(1, 3)
const PRIZE_PER_LEVEL := 24


func _ready() -> void:
	var expeditions := Game.expeditions
	var biome := expeditions.biome() if expeditions != null else null
	if biome == null:
		push_error("ExpeditionMap : aucune expédition en cours")
		return
	var layout := expeditions.layout()
	display_name = biome.name
	var zone := $Zone as ExpeditionZone
	zone.build(layout)
	_add_exit(layout)
	_add_trainers(biome, layout, int(expeditions.plan["seed"]), int(expeditions.plan["level"]))


func _add_exit(layout: ZoneLayout) -> void:
	var warp := Warp.new()
	warp.name = "Exit"
	for cell in layout.exit_cells:
		warp.trigger_cells.append(layout.to_world(cell + Vector2i.DOWN))
	warp.direction = Vector2i.DOWN
	warp.target_map = ExpeditionService.RETURN_MAP
	warp.target_cell = ExpeditionService.RETURN_CELL
	warp.target_facing = ExpeditionService.RETURN_FACING
	$Warps.add_child(warp)


## Dresseurs tirés d'après la graine : mêmes noms, mêmes équipes sur tous les ordinateurs
## (seule l'équipe de l'hôte sert en combat).
func _add_trainers(biome: ExpeditionBiome, layout: ZoneLayout, seed: int, level: int) -> void:
	if biome.trainers.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 7919
	var names := NAMES.duplicate()
	for i in layout.trainers.size():
		var spot: Dictionary = layout.trainers[i]
		var look: Dictionary = biome.trainers[rng.randi_range(0, biome.trainers.size() - 1)]
		var trainer_name: String = names.pop_at(rng.randi_range(0, names.size() - 1))
		var data := TrainerData.new()
		data.name = trainer_name
		data.title = look["title"]
		data.ai = &"trainer"
		var team: Array[PokemonInstance] = []
		var best := 1
		for n in rng.randi_range(TEAM_SIZE.x, TEAM_SIZE.y):
			var pokemon_level := clampi(level + rng.randi_range(-2, 1), 2, 100)
			var pokemon := WildPokemon.create(biome.type, pokemon_level, rng)
			if pokemon != null:
				team.append(pokemon)
				best = maxi(best, pokemon_level)
		data.team = team
		data.prize_money = best * PRIZE_PER_LEVEL
		data.defeat_line = "Tu es vraiment fort !"
		data.victory_line = "Les Pokémon de la zone %s, ça ne pardonne pas !" % biome.name
		var front: Vector2i = look["front"]
		data.battle_sheet = FRONT_SHEET
		data.front_region = Rect2i(FRONT_ORIGIN + Vector2i(front.y * FRONT_CELL.x, front.x * FRONT_CELL.y), Vector2i(80, 80))
		data.sheet_background_colors = FRONT_BACKGROUNDS
		var npc := ExpeditionTrainer.new()
		npc.name = "Trainer%d" % i
		npc.cell = layout.to_world(spot["cell"])
		npc.facing = spot["facing"]
		npc.sheet = look["sheet"]
		npc.display_name = "%s %s" % [data.title, trainer_name]
		npc.wander_radius = 0
		npc.looks_around = false
		npc.trainer = data
		npc.lines = PackedStringArray(["Hé ! Tu es venu chercher des Pokémon %s ? Voyons ce que tu vaux !" % PokemonType.type_name(biome.type)])
		npc.defeated_lines = PackedStringArray(["Bien joué tout à l'heure. Bonne chance pour la suite !"])
		$Objects.add_child(npc)
