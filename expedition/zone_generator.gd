class_name ZoneGenerator
extends RefCounted
## Tire au hasard le plan d'une zone d'expédition (ZoneLayout) d'après un biome et une
## graine : la même graine donne la même zone sur tous les ordinateurs.
##
## Étapes : une caverne par automate cellulaire (les cases fermées deviennent des
## arbres, rochers…), un couloir d'entrée en bas, puis mares ou bords liquides, chemins
## de l'entrée vers les dresseurs, hautes herbes, décors isolés et détails au sol. À
## chaque étape qui bloque des cases, on vérifie que tout reste atteignable.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Taille de la zone (bords compris) et épaisseur du bord toujours fermé.
## (Le bord est assez épais pour que la caméra ne voie jamais le vide au-delà.)
const SIZE := Vector2i(56, 48)
const MARGIN := 10
const OPEN_CHANCE := 0.56
const SMOOTH_STEPS := 4
## Part minimale de cases ouvertes à l'intérieur ; sinon on retire une caverne.
const MIN_OPEN := 0.38
const MAX_TRIES := 12
## Dresseurs : nombre, distance minimale à l'entrée et entre eux.
const TRAINERS := Vector2i(3, 5)
const TRAINER_SPACING := 7
## Hautes herbes : part visée des cases libres, et zone sans herbe autour de l'entrée.
const ENCOUNTER_SHARE := 0.3
const SAFE_RADIUS := 3

var _rng := RandomNumberGenerator.new()
var _seed := 0
## Cases occupées par un décor déjà posé.
var _prop_cells := {}
## Chemin de sortie, sous l'entrée (ni décor ni herbe).
var _exit_lane := {}


func generate(biome: ExpeditionBiome, seed: int, origin := Vector2i.ZERO) -> ZoneLayout:
	_seed = seed
	_rng.seed = seed
	_prop_cells = {}
	_exit_lane = {}
	var layout := ZoneLayout.new()
	layout.origin = origin
	layout.size = SIZE
	var open := {}
	for attempt in MAX_TRIES:
		open = _cave()
		if open.size() >= (SIZE.x - 2 * MARGIN) * (SIZE.y - 2 * MARGIN) * MIN_OPEN:
			break
	layout.entry = Vector2i(SIZE.x / 2, SIZE.y - MARGIN)
	layout.walkable = open
	# Seule la partie reliée à l'entrée reste ouverte.
	layout.walkable = layout.reachable(layout.entry)
	layout.exit_cells = [layout.entry, layout.entry + Vector2i.LEFT]
	# Sous l'entrée, le chemin continue jusqu'au bord : c'est la sortie.
	for y in range(layout.entry.y + 1, SIZE.y):
		for cell in layout.exit_cells:
			_exit_lane[Vector2i(cell.x, y)] = true
	var liquid := _liquid(biome, layout)
	_trainers(layout)
	var paths := _paths(biome, layout)
	_encounters(biome, layout, paths)
	_scatter(biome, layout, paths)
	_walls(biome, layout, liquid)
	_ground(biome, layout, liquid, paths)
	return layout


## Remplit de décors les cases fermées d'un plan dessiné à la main (passage vers les
## expéditions) ; `reserved` : cases déjà occupées.
func fill_walls(biome: ExpeditionBiome, layout: ZoneLayout, reserved: Dictionary, seed := 1) -> void:
	_seed = seed
	_rng.seed = seed
	_prop_cells = reserved.duplicate()
	_exit_lane = {}
	_walls(biome, layout, {})


# --- Forme de la zone -------------------------------------------------------------------

## Caverne : cases ouvertes au hasard, lissées ; couloir d'entrée en bas au centre.
func _cave() -> Dictionary:
	var open := {}
	for y in range(MARGIN, SIZE.y - MARGIN):
		for x in range(MARGIN, SIZE.x - MARGIN):
			if _rng.randf() < OPEN_CHANCE:
				open[Vector2i(x, y)] = true
	for step in SMOOTH_STEPS:
		var next := {}
		for y in range(MARGIN, SIZE.y - MARGIN):
			for x in range(MARGIN, SIZE.x - MARGIN):
				var closed := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if (dx != 0 or dy != 0) and not open.has(Vector2i(x + dx, y + dy)):
							closed += 1
				if closed < 5:
					next[Vector2i(x, y)] = true
		open = next
	# Couloir d'entrée : deux cases de large, du bas jusqu'à la caverne.
	var x0 := SIZE.x / 2 - 1
	for y in range(SIZE.y - MARGIN, MARGIN, -1):
		var reached := open.has(Vector2i(x0, y - 1)) or open.has(Vector2i(x0 + 1, y - 1))
		open[Vector2i(x0, y)] = true
		open[Vector2i(x0 + 1, y)] = true
		if reached and y < SIZE.y - MARGIN - 3:
			break
	return open


## Mares au milieu des passages et étendues liquides sur les bords. Renvoie les cases
## liquides (elles ne sont plus praticables).
func _liquid(biome: ExpeditionBiome, layout: ZoneLayout) -> Dictionary:
	var liquid := {}
	if biome.liquid == ExpeditionBiome.NONE:
		return liquid
	# Bords : les cases fermées proches des passages deviennent liquides par plaques.
	if biome.liquid_border > 0.0:
		for y in SIZE.y:
			for x in SIZE.x:
				var cell := Vector2i(x, y)
				if layout.walkable.has(cell) or _exit_lane.has(cell) or _distance_to_open(layout, cell, 3) > 3:
					continue
				if _noise(cell, 5.0, 11) < biome.liquid_border:
					liquid[cell] = true
	# Mares : des taches qui poussent depuis quelques cases, gardées seulement si tout
	# reste atteignable.
	var target := int(layout.walkable.size() * biome.pools)
	var cells := layout.walkable.keys()
	var tries := 0
	while target > 0 and tries < 40:
		tries += 1
		var start: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		if (start - layout.entry).length() < 7:
			continue
		var blob := _blob(layout, start, _rng.randi_range(4, 14), liquid)
		if layout.reachable(layout.entry, blob).size() < layout.walkable.size() - blob.size():
			continue
		liquid.merge(blob)
		for cell in blob:
			layout.walkable.erase(cell)
		target -= blob.size()
	return liquid


func _blob(layout: ZoneLayout, start: Vector2i, count: int, taken: Dictionary) -> Dictionary:
	var blob := {start: true}
	var frontier: Array[Vector2i] = [start]
	while blob.size() < count and not frontier.is_empty():
		var cell: Vector2i = frontier[_rng.randi_range(0, frontier.size() - 1)]
		var next: Vector2i = cell + DIRS[_rng.randi_range(0, 3)]
		if layout.walkable.has(next) and not blob.has(next) and not taken.has(next) \
				and (next - layout.entry).length() >= 5:
			blob[next] = true
			frontier.append(next)
	return blob


# --- Dresseurs, chemins, herbes, décors -------------------------------------------------

func _trainers(layout: ZoneLayout) -> void:
	var wanted := _rng.randi_range(TRAINERS.x, TRAINERS.y)
	var cells := layout.walkable.keys()
	cells.sort()
	_shuffle(cells)
	var blocked := {}
	for cell: Vector2i in cells:
		if layout.trainers.size() >= wanted:
			break
		if (cell - layout.entry).length() < 9:
			continue
		var too_close := false
		for trainer in layout.trainers:
			if (cell - trainer["cell"]).length() < TRAINER_SPACING:
				too_close = true
		if too_close:
			continue
		# Un dresseur ne doit jamais boucher un passage.
		blocked[cell] = true
		if layout.reachable(layout.entry, blocked).size() < layout.walkable.size() - blocked.size():
			blocked.erase(cell)
			continue
		var facings: Array[Vector2i] = []
		for dir in DIRS:
			if layout.walkable.has(cell + dir) and layout.walkable.has(cell + dir * 2):
				facings.append(dir)
		if facings.is_empty():
			blocked.erase(cell)
			continue
		layout.trainers.append({"cell": cell, "facing": facings[_rng.randi_range(0, facings.size() - 1)]})


## Chemins de l'entrée vers chaque dresseur et vers le fond de la zone.
func _paths(biome: ExpeditionBiome, layout: ZoneLayout) -> Dictionary:
	var paths := {}
	var goals: Array[Vector2i] = []
	for trainer in layout.trainers:
		goals.append(trainer["cell"] + trainer["facing"])
	var far := layout.entry
	for cell: Vector2i in layout.walkable:
		if cell.y < far.y:
			far = cell
	goals.append(far)
	var blocked := {}
	for trainer in layout.trainers:
		blocked[trainer["cell"]] = true
	for goal in goals:
		for cell in _route(layout, layout.entry, goal, blocked):
			paths[cell] = true
	return paths


## Plus court chemin (largeur d'abord, voisins dans un ordre tiré au hasard).
func _route(layout: ZoneLayout, from: Vector2i, to: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == to:
			break
		var order := DIRS.duplicate()
		_shuffle(order)
		for dir: Vector2i in order:
			var next := cell + dir
			if layout.walkable.has(next) and not blocked.has(next) and not came.has(next):
				came[next] = cell
				queue.append(next)
	var route: Array[Vector2i] = []
	if not came.has(to):
		return route
	var cell := to
	while cell != from:
		route.append(cell)
		cell = came[cell]
	route.append(from)
	return route


func _encounters(biome: ExpeditionBiome, layout: ZoneLayout, paths: Dictionary) -> void:
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in layout.walkable:
		if paths.has(cell) or (cell - layout.entry).length() <= SAFE_RADIUS or _is_trainer(layout, cell):
			continue
		candidates.append(cell)
	# Les plaques d'herbe suivent un bruit lissé : on garde les cases les plus « hautes ».
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _noise(a, 4.0, 23) > _noise(b, 4.0, 23))
	var count := int(candidates.size() * ENCOUNTER_SHARE)
	for i in count:
		layout.encounter[candidates[i]] = true


func _scatter(biome: ExpeditionBiome, layout: ZoneLayout, paths: Dictionary) -> void:
	var props := biome.props_for(false)
	if props.is_empty():
		return
	var cells := layout.walkable.keys()
	cells.sort()
	_shuffle(cells)
	var wanted := int(cells.size() * biome.scatter_density)
	for cell: Vector2i in cells:
		if wanted <= 0:
			break
		var prop := _pick(props)
		var area := _footprint(cell, prop)
		var ok := true
		for c in area:
			if not layout.walkable.has(c) or paths.has(c) or _is_trainer(layout, c) or layout.encounter.has(c) \
					or (c - layout.entry).length() <= SAFE_RADIUS:
				ok = false
		if not ok:
			continue
		var blocked := _trainer_cells(layout)
		for c in area:
			blocked[c] = true
		if layout.reachable(layout.entry, blocked).size() < layout.walkable.size() - blocked.size():
			continue
		for c in area:
			layout.walkable.erase(c)
			_prop_cells[c] = true
		layout.props.append({"cell": cell, "prop": prop})
		wanted -= 1


## Remplit les cases fermées (hors liquide) de décors : les plus gros d'abord.
func _walls(biome: ExpeditionBiome, layout: ZoneLayout, liquid: Dictionary) -> void:
	var props := biome.props_for(true)
	if props.is_empty():
		return
	var big := props.duplicate()
	big.sort_custom(func(a: ExpeditionProp, b: ExpeditionProp) -> bool:
		return a.footprint.x * a.footprint.y > b.footprint.x * b.footprint.y)
	var taken := _prop_cells
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			if taken.has(cell) or layout.walkable.has(cell) or liquid.has(cell) or _exit_lane.has(cell):
				continue
			# Un gros décor si la place le permet (au hasard), sinon le plus petit qui tienne.
			var choices: Array[ExpeditionProp] = []
			for prop in big:
				var fits := true
				for c in _footprint(cell, prop):
					if not layout.in_bounds(c) or taken.has(c) or layout.walkable.has(c) or liquid.has(c) or _exit_lane.has(c):
						fits = false
				if fits:
					choices.append(prop)
			if choices.is_empty():
				continue
			var prop := _pick(choices)
			for c in _footprint(cell, prop):
				taken[c] = true
			layout.props.append({"cell": cell, "prop": prop})


func _ground(biome: ExpeditionBiome, layout: ZoneLayout, liquid: Dictionary, paths: Dictionary) -> void:
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var tile := biome.ground
			if not biome.ground_variants.is_empty() and _rng.randf() < biome.variant_density:
				tile = biome.ground_variants[_rng.randi_range(0, biome.ground_variants.size() - 1)]
			if liquid.has(cell):
				tile = biome.liquid
			elif layout.encounter.has(cell):
				tile = biome.encounter
			elif (paths.has(cell) or _exit_lane.has(cell)) and biome.path != ExpeditionBiome.NONE:
				tile = biome.path
			elif layout.walkable.has(cell) and not biome.decor.is_empty() and _rng.randf() < biome.decor_density:
				layout.overlay[cell] = biome.decor[_rng.randi_range(0, biome.decor.size() - 1)]
			layout.ground[cell] = tile


# --- Outils -------------------------------------------------------------------------------

## Cases bloquées par un décor posé avec son coin haut-gauche en `cell`.
static func _footprint(cell: Vector2i, prop: ExpeditionProp) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in prop.footprint.y:
		for dx in prop.footprint.x:
			cells.append(cell + Vector2i(dx, dy))
	return cells


func _is_trainer(layout: ZoneLayout, cell: Vector2i) -> bool:
	for trainer in layout.trainers:
		if trainer["cell"] == cell:
			return true
	return false


func _trainer_cells(layout: ZoneLayout) -> Dictionary:
	var cells := {}
	for trainer in layout.trainers:
		cells[trainer["cell"]] = true
	return cells


func _distance_to_open(layout: ZoneLayout, cell: Vector2i, limit: int) -> int:
	for d in range(1, limit + 1):
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				if layout.walkable.has(cell + Vector2i(dx, dy)):
					return d
	return limit + 1


func _pick(props: Array) -> ExpeditionProp:
	var total := 0.0
	for prop: ExpeditionProp in props:
		total += prop.weight
	var roll := _rng.randf() * total
	for prop: ExpeditionProp in props:
		roll -= prop.weight
		if roll <= 0.0:
			return prop
	return props.back()


func _shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap: Variant = array[i]
		array[i] = array[j]
		array[j] = swap


## Bruit lissé de 0 à 1 (valeurs tirées aux coins d'une grille de `scale` cases, puis
## interpolées), qui dépend de la graine de la zone.
func _noise(cell: Vector2i, scale: float, salt: int) -> float:
	var p := Vector2(cell) / scale
	var base := Vector2i(floori(p.x), floori(p.y))
	var f := p - Vector2(base)
	var a := _hash(base, salt)
	var b := _hash(base + Vector2i(1, 0), salt)
	var c := _hash(base + Vector2i(0, 1), salt)
	var d := _hash(base + Vector2i(1, 1), salt)
	var sx := f.x * f.x * (3.0 - 2.0 * f.x)
	var sy := f.y * f.y * (3.0 - 2.0 * f.y)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sy)


func _hash(cell: Vector2i, salt: int) -> float:
	var h := hash([cell.x, cell.y, salt, _seed])
	return float(h & 0xffff) / 65535.0
