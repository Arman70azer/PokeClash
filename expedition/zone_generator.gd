class_name ZoneGenerator
extends RefCounted
## Tire au hasard le plan d'une zone d'expédition (ZoneLayout) d'après un biome et une
## graine : la même graine donne la même zone sur tous les ordinateurs.
##
## La forme est un labyrinthe organique, à la manière des forêts et des routes des jeux :
## des clairières reliées par des couloirs qui serpentent, quelques boucles et des
## recoins sans issue. Il est tracé sur une grille de CELL cases (la taille d'un arbre),
## pour que les murs se remplissent de décors sans trou. Ensuite : un couloir d'entrée en
## bas, mares ou bords liquides, dresseurs, chemins de l'entrée vers eux, hautes herbes,
## décors isolés et détails au sol. À chaque étape qui bloque des cases, on vérifie que
## tout reste atteignable.

const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Taille de la zone (bords compris) et épaisseur du bord toujours fermé.
## (Le bord est assez épais pour que la caméra ne voie jamais le vide au-delà.)
const SIZE := Vector2i(56, 48)
const MARGIN := 10
## Côté d'une case du labyrinthe, en cases de la zone, et nombre de ces cases.
const CELL := 2
const GRID := Vector2i((SIZE.x - 2 * MARGIN) / CELL, (SIZE.y - 2 * MARGIN) / CELL)
## Clairières (nombre, rayon en cases du labyrinthe), points de passage, recoins.
const CLEARINGS := Vector2i(3, 4)
const CLEARING_RADIUS := Vector2i(2, 3)
const WAYPOINTS := Vector2i(6, 9)
## Plan à salles (crypte) : plus de salles, bien espacées, et moins de points de passage :
## des salles reliées par quelques couloirs, pas un dédale de couloirs.
const HALLS := Vector2i(4, 5)
const HALL_SPACING := 7.0
const HALL_WAYPOINTS := Vector2i(1, 3)
## Les rangées de tombes prennent de la place : un peu plus d'intérieur ouvert.
const HALL_MIN_OPEN := 140
const NOOKS := Vector2i(2, 4)
## Taille minimale de l'intérieur ouvert, en cases du labyrinthe.
const MIN_OPEN := 120
## Couloirs : coût du bruit (plus il est fort, plus ils serpentent), coût d'un virage
## (des lignes droites plutôt qu'un escalier) ; boucles ajoutées.
const WINDING := 4.0
const TURN_COST := 1.5
const LOOPS := Vector2i(1, 2)
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
## Clairières, en cases du labyrinthe.
var _rooms := {}
## Salles rectangulaires (biome à salles), en cases du labyrinthe.
var _halls: Array[Rect2i] = []


func generate(biome: ExpeditionBiome, seed: int, origin := Vector2i.ZERO) -> ZoneLayout:
	_seed = seed
	_rng.seed = seed
	_prop_cells = {}
	_exit_lane = {}
	_rooms = {}
	_halls = []
	var layout := ZoneLayout.new()
	layout.origin = origin
	layout.size = SIZE
	layout.sheet = biome.sheet
	layout.encounter_mesh = biome.encounter_mesh
	layout.step_effect = biome.step_effect
	layout.cliffs = biome.cliffs
	layout.cliff_clearance = biome.cliff_clearance
	# Entrée : en bas au milieu, deux cases de large alignées sur la grille du labyrinthe.
	layout.entry = Vector2i(MARGIN + GRID.x / 2 * CELL, SIZE.y - MARGIN)
	layout.exit_cells = [layout.entry, layout.entry + Vector2i.RIGHT]
	layout.walkable = _maze(biome, layout)
	# Sous l'entrée, le chemin continue jusqu'au bord : c'est la sortie.
	for y in range(layout.entry.y + 1, SIZE.y):
		for cell in layout.exit_cells:
			_exit_lane[Vector2i(cell.x, y)] = true
	var liquid := _liquid(biome, layout)
	layout.liquid = liquid
	_trainers(layout)
	var paths := _paths(biome, layout)
	if biome.prop_rows:
		_rows(biome, layout)
	_encounters(biome, layout, paths)
	if not biome.prop_rows:
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


# --- Forme de la zone : labyrinthe organique ----------------------------------------------

## Cases praticables de la zone : le labyrinthe (en cases de CELL), son couloir d'entrée,
## et des bords grignotés si le biome a des petits décors pour boucher les creux.
func _maze(biome: ExpeditionBiome, layout: ZoneLayout) -> Dictionary:
	var start := Vector2i(GRID.x / 2, GRID.y - 1)
	var open := {start: true}
	# Clairières : la première tout au fond, les autres réparties sur la zone.
	var nodes: Array[Vector2i] = [start]
	var counts := HALLS if biome.halls else CLEARINGS
	var spacing := HALL_SPACING if biome.halls else 5.0
	var clearings := _rng.randi_range(counts.x, counts.y)
	for i in clearings:
		var center := _spot(nodes, spacing, 0 if i == 0 else GRID.y - 4, 0 if i > 0 else 2)
		nodes.append(center)
		if biome.halls:
			_hall(open, center)
		else:
			_clearing(open, center)
	# Points de passage : les couloirs y tournent, et les feuilles deviennent des impasses.
	var waypoints := HALL_WAYPOINTS if biome.halls else WAYPOINTS
	for i in _rng.randi_range(waypoints.x, waypoints.y):
		nodes.append(_spot(nodes, 3, GRID.y - 1, 0))
	var winding := 0.0 if biome.halls else WINDING
	for edge in _tree_edges(nodes):
		_corridor(open, edge[0], edge[1], winding)
	# Recoins : de courtes impasses qui partent des couloirs.
	for i in _rng.randi_range(NOOKS.x, NOOKS.y):
		_nook(open)
	# Trop petit : on ajoute des passages jusqu'à la taille voulue.
	var guard := 0
	var min_open := HALL_MIN_OPEN if biome.halls else MIN_OPEN
	while open.size() < min_open and guard < 20:
		guard += 1
		var extra := _spot(nodes, 2, GRID.y - 1, 0)
		_corridor(open, extra, nodes[_rng.randi_range(0, nodes.size() - 1)], winding)
		nodes.append(extra)
	var tiles := {}
	for c: Vector2i in open:
		for dy in CELL:
			for dx in CELL:
				var tile := Vector2i(MARGIN + c.x * CELL + dx, MARGIN + c.y * CELL + dy)
				tiles[tile] = true
				if _rooms.has(c):
					layout.rooms[tile] = true
	for cell in layout.exit_cells:
		tiles[cell] = true
	if _has_small_walls(biome):
		_roughen(tiles)
	return tiles


## Case du labyrinthe libre, loin d'au moins `spacing` des points déjà choisis (rangées
## de `top` à `bottom`, ou n'importe où si c'est impossible).
func _spot(taken: Array[Vector2i], spacing: float, bottom: int, top: int) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := -1.0
	for attempt in 30:
		var cell := Vector2i(_rng.randi_range(0, GRID.x - 1), _rng.randi_range(mini(top, bottom), maxi(top, bottom)))
		var nearest := INF
		for other in taken:
			nearest = minf(nearest, Vector2(cell - other).length())
		if nearest >= spacing:
			return cell
		if nearest > best_distance:
			best_distance = nearest
			best = cell
	return best


## Clairière : un disque aux bords irréguliers (bruit), en cases du labyrinthe.
func _clearing(open: Dictionary, center: Vector2i) -> void:
	var radius := Vector2(_rng.randi_range(CLEARING_RADIUS.x, CLEARING_RADIUS.y),
		_rng.randi_range(CLEARING_RADIUS.x, CLEARING_RADIUS.y)) + Vector2(0.5, 0.5)
	for y in range(center.y - int(radius.y) - 1, center.y + int(radius.y) + 2):
		for x in range(center.x - int(radius.x) - 1, center.x + int(radius.x) + 2):
			var cell := Vector2i(x, y)
			if not _in_grid(cell):
				continue
			var d := Vector2(cell - center) / radius
			if d.length_squared() + (_noise(cell, 2.0, 31) - 0.5) * 0.9 <= 1.0:
				open[cell] = true
				_rooms[cell] = true


## Salle : un rectangle aux murs droits, en cases du labyrinthe (une crypte, une tour).
func _hall(open: Dictionary, center: Vector2i) -> void:
	var half := Vector2i(_rng.randi_range(CLEARING_RADIUS.x, CLEARING_RADIUS.y),
		_rng.randi_range(CLEARING_RADIUS.x, CLEARING_RADIUS.y))
	var rect := Rect2i(center - half, half * 2 + Vector2i.ONE).intersection(Rect2i(Vector2i.ZERO, GRID))
	_halls.append(rect)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			open[Vector2i(x, y)] = true
			_rooms[Vector2i(x, y)] = true


## Arbre couvrant des points (le plus court d'abord, à peu près), plus quelques boucles
## entre des points voisins.
func _tree_edges(nodes: Array[Vector2i]) -> Array:
	var edges := []
	var linked: Array[int] = [0]
	var left: Array[int] = []
	for i in range(1, nodes.size()):
		left.append(i)
	while not left.is_empty():
		var best := [-1, -1]
		var best_cost := INF
		for a in linked:
			for b in left:
				var cost := Vector2(nodes[a] - nodes[b]).length() * _rng.randf_range(0.8, 1.2)
				if cost < best_cost:
					best_cost = cost
					best = [a, b]
		edges.append([nodes[best[0]], nodes[best[1]]])
		linked.append(best[1])
		left.erase(best[1])
	var loops := _rng.randi_range(LOOPS.x, LOOPS.y)
	for attempt in 40:
		if loops <= 0:
			break
		var a := nodes[_rng.randi_range(0, nodes.size() - 1)]
		var b := nodes[_rng.randi_range(0, nodes.size() - 1)]
		var length := Vector2(a - b).length()
		if a != b and length > 3.0 and length < 8.0:
			edges.append([a, b])
			loops -= 1
	return edges


## Couloir d'une case de large entre deux cases : plus court chemin à travers un champ de
## bruit (il serpente), qui préfère les lignes droites aux escaliers et emprunte
## volontiers les passages déjà ouverts.
func _corridor(open: Dictionary, from: Vector2i, to: Vector2i, winding := WINDING) -> void:
	# État : case et direction d'arrivée (pour compter les virages).
	var start := Vector3i(from.x, from.y, -1)
	var cost := {start: 0.0}
	var came := {start: start}
	var frontier: Array = [[0.0, start]]
	var reached := start
	while not frontier.is_empty():
		var best := 0
		for i in frontier.size():
			if frontier[i][0] < frontier[best][0]:
				best = i
		var state: Vector3i = frontier[best][1]
		frontier.remove_at(best)
		var cell := Vector2i(state.x, state.y)
		if cell == to:
			reached = state
			break
		for d in DIRS.size():
			var next := cell + DIRS[d]
			if not _in_grid(next):
				continue
			var step := 0.6 if open.has(next) else 1.0 + _noise(next, 3.0, 47) * winding
			if state.z >= 0 and state.z != d:
				step += TURN_COST
			var next_state := Vector3i(next.x, next.y, d)
			var total: float = cost[state] + step
			if not cost.has(next_state) or total < cost[next_state]:
				cost[next_state] = total
				came[next_state] = state
				frontier.append([total + Vector2(to - next).length() * 0.5, next_state])
	var state := reached
	while state != start:
		open[Vector2i(state.x, state.y)] = true
		state = came[state]
	open[from] = true


## Impasse : depuis un couloir, quelques cases dans le fourré, sans toucher d'autre
## passage (un vrai cul-de-sac).
func _nook(open: Dictionary) -> void:
	var cells := open.keys()
	cells.sort()
	for attempt in 20:
		var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		var dir := DIRS[_rng.randi_range(0, 3)]
		var length := _rng.randi_range(2, 4)
		var dug: Array[Vector2i] = []
		var ok := true
		for k in range(1, length + 1):
			var next := cell + dir * k
			var side := Vector2i(dir.y, dir.x)
			if not _in_grid(next) or open.has(next) or open.has(next + side) or open.has(next - side) \
					or open.has(next + dir):
				ok = false
				break
			dug.append(next)
		if ok:
			for c in dug:
				open[c] = true
			return


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID.x and cell.y < GRID.y


## Vrai si le biome a des décors d'une seule case pour remplir les murs.
func _has_small_walls(biome: ExpeditionBiome) -> bool:
	for prop in biome.props_for(true):
		if prop.footprint == Vector2i.ONE:
			return true
	return false


## Bords irréguliers : des cases du fourré qui touchent un passage s'ouvrent (bruit), pour
## que les couloirs n'aient pas l'air tirés à la règle.
func _roughen(tiles: Dictionary) -> void:
	var added: Array[Vector2i] = []
	for y in range(MARGIN, SIZE.y - MARGIN):
		for x in range(MARGIN, SIZE.x - MARGIN):
			var cell := Vector2i(x, y)
			if tiles.has(cell) or _noise(cell, 2.5, 53) < 0.62:
				continue
			for dir in DIRS:
				if tiles.has(cell + dir):
					added.append(cell)
					break
	for cell in added:
		tiles[cell] = true


## Mares au milieu des passages et étendues liquides sur les bords. Renvoie les cases
## liquides (elles ne sont plus praticables).
func _liquid(biome: ExpeditionBiome, layout: ZoneLayout) -> Dictionary:
	var liquid := {}
	if biome.liquid == ExpeditionBiome.NONE:
		return liquid
	# Une mer autour des passages : tout ce qui n'est pas praticable.
	if biome.walls_liquid:
		for y in SIZE.y:
			for x in SIZE.x:
				var cell := Vector2i(x, y)
				if not layout.walkable.has(cell) and not _exit_lane.has(cell):
					liquid[cell] = true
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
		# Une case déjà prise par une mare précédente ne peut pas en commencer une autre.
		if (start - layout.entry).length() < 7 or not layout.walkable.has(start):
			continue
		var blob := _blob(layout, start, _rng.randi_range(4, 14), liquid)
		if not _keeps_connected(layout, blob, {}):
			continue
		liquid.merge(blob)
		for cell in blob:
			layout.walkable.erase(cell)
		target -= blob.size()
	return liquid


func _blob(layout: ZoneLayout, start: Vector2i, count: int, taken: Dictionary) -> Dictionary:
	var blob := {start: true}
	var frontier: Array[Vector2i] = [start]
	var can_take := func(next: Vector2i) -> bool:
		return layout.walkable.has(next) and not blob.has(next) and not taken.has(next) \
			and (next - layout.entry).length() >= 5
	while blob.size() < count and not frontier.is_empty():
		var index := _rng.randi_range(0, frontier.size() - 1)
		var cell: Vector2i = frontier[index]
		# Une case qui ne peut plus s'étendre sort de la liste : sans cela, une tache
		# enfermée (cul-de-sac) tirerait les mêmes cases sans fin.
		if not DIRS.any(func(dir: Vector2i) -> bool: return can_take.call(cell + dir)):
			frontier.remove_at(index)
			continue
		var next: Vector2i = cell + DIRS[_rng.randi_range(0, 3)]
		if can_take.call(next):
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
		if not _keeps_connected(layout, {cell: true}, blocked):
			continue
		blocked[cell] = true
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
		if (biome.islands or biome.halls) and not layout.rooms.has(cell):
			continue
		candidates.append(cell)
	# Les plaques d'herbe suivent un bruit lissé : on garde les cases les plus « hautes ».
	# Le bruit est calculé une fois par case, pas à chaque comparaison du tri.
	# Plaques alignées sur la grille du labyrinthe : de vrais carrés d'herbe, pas des
	# taches d'une case.
	var height := {}
	for cell in candidates:
		height[cell] = _noise(Vector2i((cell - Vector2i(MARGIN, MARGIN)) / CELL), 2.5, 23)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return height[a] > height[b])
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
	var trainer_cells := _trainer_cells(layout)
	for cell: Vector2i in cells:
		if wanted <= 0:
			break
		var prop := _pick(props)
		var area := _footprint(cell, prop)
		var ok := true
		for c in area:
			if not layout.walkable.has(c) or paths.has(c) or _is_trainer(layout, c) or layout.encounter.has(c) \
					or (c - layout.entry).length() <= SAFE_RADIUS or (biome.islands and not layout.rooms.has(c)):
				ok = false
		if not ok:
			continue
		var cells_taken := {}
		for c in area:
			cells_taken[c] = true
		if not _keeps_connected(layout, cells_taken, trainer_cells):
			continue
		for c in area:
			layout.walkable.erase(c)
			layout.scattered[c] = true
			_prop_cells[c] = true
		layout.props.append({"cell": cell, "prop": prop})
		wanted -= 1


## Décors en rangées dans chaque salle : de part et d'autre d'une allée centrale de deux
## cases (une seule file au milieu dans une salle étroite), une case libre entre deux
## décors et le long des murs (les allées d'un cimetière).
## Une place sur un dresseur, devant lui ou qui couperait un passage reste vide (le tour
## de la salle reste libre : on circule toujours autour des rangées).
func _rows(biome: ExpeditionBiome, layout: ZoneLayout) -> void:
	var props := biome.props_for(false)
	if props.is_empty():
		return
	var trainer_cells := _trainer_cells(layout)
	var reserved := trainer_cells.duplicate()
	for trainer in layout.trainers:
		reserved[trainer["cell"] + trainer["facing"]] = true
	for hall in _halls:
		var x0 := MARGIN + hall.position.x * CELL
		var x1 := MARGIN + hall.end.x * CELL - 1
		var y0 := MARGIN + hall.position.y * CELL
		var y1 := MARGIN + hall.end.y * CELL - 1
		# Un seul modèle par salle : des rangées toutes pareilles.
		var prop := _pick(props)
		var size := prop.footprint
		var center := (x0 + x1 + 1) / 2
		var columns: Array[int] = []
		var x := center + 1
		while x + size.x - 1 <= x1 - 1:
			columns.append(x)
			x += size.x + 1
		x = center - 1 - size.x
		while x >= x0 + 1:
			columns.append(x)
			x -= size.x + 1
		# Salle étroite : une seule file de décors au milieu, une allée de chaque côté.
		if columns.size() < 2:
			columns = [center - size.x / 2]
		var y := y0 + 1
		while y + size.y - 1 <= y1 - 1:
			for column in columns:
				_place_in_row(layout, prop, Vector2i(column, y), reserved, trainer_cells)
			y += size.y + 1


func _place_in_row(layout: ZoneLayout, prop: ExpeditionProp, cell: Vector2i, reserved: Dictionary,
		trainer_cells: Dictionary) -> void:
	var area := _footprint(cell, prop)
	var taken := {}
	for c in area:
		if not layout.walkable.has(c) or reserved.has(c) or (c - layout.entry).length() <= SAFE_RADIUS:
			return
		taken[c] = true
	if not _keeps_connected(layout, taken, trainer_cells):
		return
	for c in area:
		layout.walkable.erase(c)
		layout.scattered[c] = true
		_prop_cells[c] = true
	layout.props.append({"cell": cell, "prop": prop})


## Remplit les cases fermées (hors liquide) de décors : les plus gros d'abord.
func _walls(biome: ExpeditionBiome, layout: ZoneLayout, liquid: Dictionary) -> void:
	var props := biome.props_for(true)
	if props.is_empty():
		return
	var big := props.duplicate()
	big.sort_custom(func(a: ExpeditionProp, b: ExpeditionProp) -> bool:
		return a.footprint.x * a.footprint.y > b.footprint.x * b.footprint.y)
	var taken := _prop_cells
	var width := layout.size.x
	var height := layout.size.y
	# Cases encore libres pour un décor (1 : libre), une par case, ligne après ligne.
	var free := PackedByteArray()
	free.resize(width * height)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if not (taken.has(c) or layout.walkable.has(c) or liquid.has(c) or _exit_lane.has(c)):
				free[y * width + x] = 1
	for y in height:
		for x in width:
			if free[y * width + x] == 0:
				continue
			# Un gros décor si la place le permet (au hasard), sinon le plus petit qui tienne.
			var choices: Array[ExpeditionProp] = []
			for prop: ExpeditionProp in big:
				var fits := x + prop.footprint.x <= width and y + prop.footprint.y <= height
				for dy in prop.footprint.y if fits else 0:
					for dx in prop.footprint.x:
						if free[(y + dy) * width + x + dx] == 0:
							fits = false
							break
					if not fits:
						break
				if fits:
					choices.append(prop)
			if choices.is_empty():
				continue
			var prop := _pick(choices)
			for c in _footprint(Vector2i(x, y), prop):
				taken[c] = true
				free[c.y * width + c.x] = 0
			layout.props.append({"cell": Vector2i(x, y), "prop": prop})


func _ground(biome: ExpeditionBiome, layout: ZoneLayout, liquid: Dictionary, paths: Dictionary) -> void:
	for y in SIZE.y:
		for x in SIZE.x:
			var cell := Vector2i(x, y)
			var tile := _tile(biome.ground, biome.ground_pattern, cell)
			if not biome.ground_variants.is_empty() and _rng.randf() < biome.variant_density:
				tile = biome.ground_variants[_rng.randi_range(0, biome.ground_variants.size() - 1)]
			var lane := _exit_lane.has(cell)
			if biome.corridor != ExpeditionBiome.NONE and (lane or layout.walkable.has(cell)) and not layout.rooms.has(cell):
				tile = _tile(biome.corridor, biome.corridor_pattern, cell)
			if liquid.has(cell):
				tile = _tile(biome.liquid, biome.liquid_pattern, cell)
				if biome.shallow != ExpeditionBiome.NONE and _near_land(layout, cell):
					tile = _tile(biome.shallow, biome.shallow_pattern, cell)
			elif layout.encounter.has(cell) and biome.encounter_mesh == null:
				tile = _tile(biome.encounter, biome.encounter_pattern, cell)
			elif (paths.has(cell) or lane) and biome.path != ExpeditionBiome.NONE:
				tile = _tile(biome.path, biome.path_pattern, cell)
			elif layout.walkable.has(cell) and not biome.decor.is_empty() and _rng.randf() < biome.decor_density:
				layout.overlay[cell] = biome.decor[_rng.randi_range(0, biome.decor.size() - 1)]
			layout.ground[cell] = tile


# --- Outils -------------------------------------------------------------------------------

## Tuile d'un motif de `pattern` tuiles (à partir de `base`) répété sur la zone.
static func _tile(base: Vector2i, pattern: Vector2i, cell: Vector2i) -> Vector2i:
	return base + Vector2i(cell.x % pattern.x, cell.y % pattern.y)


## Vrai si une case praticable touche celle-ci (même en diagonale).
func _near_land(layout: ZoneLayout, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if layout.walkable.has(cell + Vector2i(dx, dy)) or _exit_lane.has(cell + Vector2i(dx, dy)):
				return true
	return false

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


## Vrai si bloquer `area`, en plus de `blocked`, laisse toutes les autres cases de marche
## reliées à l'entrée (elles doivent l'être avant). Test rapide d'abord : si les cases
## libres autour de `area` sont reliées entre elles sans en sortir, tout chemin qui
## traversait `area` peut la contourner. Sinon, parcours complet de la zone.
func _keeps_connected(layout: ZoneLayout, area: Dictionary, blocked: Dictionary) -> bool:
	if not area.has(layout.entry):
		var ring := {}
		for cell: Vector2i in area:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c := cell + Vector2i(dx, dy)
					if not area.has(c) and layout.walkable.has(c) and not blocked.has(c):
						ring[c] = true
		if ring.is_empty():
			return true
		var first: Vector2i = ring.keys()[0]
		var seen := {first: true}
		var queue: Array[Vector2i] = [first]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			for dir in DIRS:
				var next := cell + dir
				if ring.has(next) and not seen.has(next):
					seen[next] = true
					queue.append(next)
		if seen.size() == ring.size():
			return true
	var all_blocked := blocked.duplicate()
	all_blocked.merge(area)
	return layout.reachable(layout.entry, all_blocked).size() >= layout.walkable.size() - all_blocked.size()


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
