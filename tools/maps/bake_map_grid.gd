extends SceneTree
## Calcule la grille de déplacement (MapGrid) d'une zone 3D à partir de son modèle.
##
## Usage, depuis le dossier du projet :
##   godot --headless -s res://tools/maps/bake_map_grid.gd -- <modèle.obj> <grille.tres> [échelle]
##
## `échelle` : agrandissement du modèle (1,3 pour les intérieurs) ; ses marches sont
## agrandies d'autant, et les seuils de hauteur (MAX_JUMP, MAX_CLIMB, STEP_RISE) aussi.
##
## Pour chaque case de 16x16 unités, des rayons verticaux mesurent la hauteur du
## dessus du modèle :
## - la case est praticable si son sol est régulier : pas de marche infranchissable entre
##   deux points de mesure voisins (un escalier, le pied d'un angle arrondi, les rainures
##   du pavage le sont ; un arbre, un toit bosselé ou le vide ne le sont pas) ;
## - le passage vers une case voisine est possible si la hauteur ne fait aucun saut
##   brusque le long du trajet (mur, rebord de terrasse) et si aucun obstacle ne le
##   barre à hauteur de personnage (clôture, arbre).
## La grille affichée à la fin marque 'o' les cases atteignables depuis la plus grande
## zone praticable, '.' les cases praticables mais isolées, '#' les cases bloquées.
## Les corrections manuelles de la grille existante (`blocked`, `opened`) sont conservées.

const TILE := 16.0
## Pente maximale d'une case praticable (unités de hauteur par unité de distance).
const MAX_SLOPE := 1.3
## Marche maximale franchissable d'un coup : saut de hauteur entre deux points du
## trajet distants d'une unité.
const MAX_JUMP := 4.5
## Montée en pente maximale sur CLIMB_WINDOW unités de trajet. Un escalier monte de 4
## sur cette distance ; un rebord arrondi (muret de pelouse, angle de bâtiment) monte
## bien plus vite et doit arrêter, même si chacun de ses points pris isolément
## ressemble à une pente.
## Les vraies marches (montée de plus de STEP_RISE d'un coup) ne comptent pas dans ce
## cumul : elles sont limitées une par une par MAX_JUMP. Sinon le pied d'un escalier
## qui commence par une marche serait pris pour un rebord.
const CLIMB_WINDOW := 4
const MAX_CLIMB := 5.0
const STEP_RISE := 3.0
## Hauteurs, au-dessus du sol, où l'on vérifie que rien ne barre le passage d'un
## personnage (murs, clôtures, et arbres faits de panneaux fins invisibles d'en haut).
## La plus basse est au-dessus d'une marche franchissable, pour ne pas la confondre
## avec un obstacle.
const BODY_HEIGHTS := [6.0, 12.0, 18.0, 24.0]

var _space: PhysicsDirectSpaceState3D
var _frames := 0
var _model := ""
var _output := ""
var _scale := 1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() == 3:
		_scale = float(args[2])
	if args.size() != 2 and args.size() != 3:
		print("Usage: godot --headless -s res://tools/maps/bake_map_grid.gd -- <modèle.obj> <grille.tres> [échelle]")
		quit(1)
		return
	_model = args[0]
	_output = args[1]
	var mesh: Mesh = load(_model)
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)


func _physics_process(_delta: float) -> bool:
	# Le moteur physique a besoin de quelques images pour enregistrer le modèle.
	_frames += 1
	if _frames < 3:
		return false
	_space = root.world_3d.direct_space_state
	_bake()
	return true


func _height_at(x: float, z: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 4000.0, z), Vector3(x, -4000.0, z))
	var hit := _space.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else NAN


func _bake() -> void:
	var mesh: Mesh = load(_model)
	var aabb := mesh.get_aabb()
	var origin := Vector2i(floori(aabb.position.x / TILE), floori(aabb.position.z / TILE))
	var end := Vector2i(ceili(aabb.end.x / TILE), ceili(aabb.end.z / TILE))
	var size := end - origin

	var grid := MapGrid.new()
	if ResourceLoader.exists(_output):
		var previous := load(_output) as MapGrid
		if previous != null:
			grid.blocked = previous.blocked
			grid.opened = previous.opened
			grid.walkable = previous.walkable
			grid.offsets = previous.offsets
			grid.bounds = previous.bounds
	grid.origin = origin
	grid.size = size
	grid.heights.resize(size.x * size.y)
	grid.flags.resize(size.x * size.y)

	# 1. Hauteur et praticabilité de chaque case.
	for cy in size.y:
		for cx in size.x:
			var x0 := (origin.x + cx) * TILE
			var z0 := (origin.y + cy) * TILE
			var i := cy * size.x + cx
			var result := _fit_cell(x0, z0)
			grid.heights[i] = result[0]
			grid.flags[i] = MapGrid.STANDABLE if result[1] else 0

	# 2. Passages vers la droite et vers le bas.
	for cy in size.y:
		for cx in size.x:
			var i := cy * size.x + cx
			if grid.flags[i] & MapGrid.STANDABLE == 0:
				continue
			var center := Vector2((origin.x + cx) * TILE + TILE / 2.0, (origin.y + cy) * TILE + TILE / 2.0)
			if cx + 1 < size.x and grid.flags[i + 1] & MapGrid.STANDABLE != 0 and _path_clear(center, Vector2.RIGHT):
				grid.flags[i] |= MapGrid.EAST
			if cy + 1 < size.y and grid.flags[i + size.x] & MapGrid.STANDABLE != 0 and _path_clear(center, Vector2.DOWN):
				grid.flags[i] |= MapGrid.SOUTH

	var err := ResourceSaver.save(grid, _output)
	print("grid origin=", origin, " size=", size, " save -> ", err)
	_print_map(grid)


## Renvoie [hauteur au centre, praticable] pour la case dont le coin est (x0, z0).
func _fit_cell(x0: float, z0: float) -> Array:
	var cx := x0 + TILE / 2.0
	var cz := z0 + TILE / 2.0
	var center := _height_at(cx, cz)
	if is_nan(center):
		return [0.0, false]
	# Points de mesure tous les 2 unités dans la partie centrale de la case (les bords
	# sont laissés aux tests de passage, pour qu'une clôture en bordure ne condamne pas
	# la case).
	var offsets := range(3, 14, 2)
	var heights := []
	for sz in offsets:
		var row := []
		for sx in offsets:
			var h := _height_at(x0 + sx, z0 + sz)
			if is_nan(h):
				return [0.0, false]
			row.append(h)
		heights.append(row)
	# Sol régulier : entre deux points voisins, pas de marche plus haute que MAX_JUMP.
	# Le test reste tolérant (rainures décoratives du pavage, pied d'une pente douce) :
	# ce sont les tests de passage entre cases qui arrêtent les rebords trop raides.
	var n := offsets.size()
	for i in n:
		for k in n:
			if k + 1 < n and absf(heights[i][k + 1] - heights[i][k]) > MAX_JUMP * _scale:
				return [center, false]
			if i + 1 < n and absf(heights[i + 1][k] - heights[i][k]) > MAX_JUMP * _scale:
				return [center, false]
	# Pente moyenne de la case (plan des moindres carrés), pour que les rayons de
	# contrôle suivent le sol d'un escalier.
	var sum_xh := 0.0
	var sum_zh := 0.0
	var sum_xx := 0.0
	for i in n:
		for k in n:
			var dx: float = offsets[k] - 8.0
			var dz: float = offsets[i] - 8.0
			sum_xh += dx * heights[i][k]
			sum_zh += dz * heights[i][k]
			sum_xx += dx * dx
	var a := sum_xh / sum_xx
	var b := sum_zh / sum_xx
	# Rien ne doit occuper le volume de la case : on la traverse de part en part.
	# Les rayons partent un peu plus haut que pour les passages, pour ignorer le pied
	# d'une pente douce qui déborde sur la case (angle arrondi d'une estrade).
	var r := TILE / 2.0 - 2.0
	for up in BODY_HEIGHTS:
		if up < 10.0:
			continue
		var y: float = center + up
		for dir in [Vector2(r, 0), Vector2(0, r), Vector2(r, r) * 0.7, Vector2(r, -r) * 0.7]:
			var rise: float = a * dir.x + b * dir.y
			if _blocked(Vector3(cx - dir.x, y - rise, cz - dir.y), Vector3(cx + dir.x, y + rise, cz + dir.y)):
				return [center, false]
	return [center, true]


func _blocked(from: Vector3, to: Vector3) -> bool:
	return not _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to)).is_empty()


## Vrai si la hauteur ne fait aucun saut le long du trajet entre deux centres de cases
## et si rien ne barre le passage à hauteur de personnage.
func _path_clear(center: Vector2, direction: Vector2) -> bool:
	var side := Vector2(direction.y, direction.x)
	for lateral in [-5.0, 0.0, 5.0]:
		var start: Vector2 = center + side * lateral
		# Profil du sol, un point par unité.
		var profile := PackedFloat32Array()
		var slope_rise := PackedFloat32Array()  # montée en pente de chaque unité (0 pour une marche)
		for d in range(0, int(TILE) + 1):
			var p: Vector2 = start + direction * d
			var h := _height_at(p.x, p.y)
			if is_nan(h):
				return false
			if d > 0:
				var rise := absf(h - profile[d - 1])
				if rise > MAX_JUMP * _scale:
					return false
				slope_rise.append(rise if rise <= STEP_RISE * _scale else 0.0)
				if slope_rise.size() >= CLIMB_WINDOW:
					var climb := 0.0
					for k in range(slope_rise.size() - CLIMB_WINDOW, slope_rise.size()):
						climb += slope_rise[k]
					if climb > MAX_CLIMB * _scale:
						return false
			profile.append(h)
		# Obstacles à hauteur de personnage. Les rayons suivent le profil du sol par
		# petits tronçons : une ligne droite de centre à centre traverserait l'arête
		# en haut d'un escalier et la prendrait pour un mur.
		for up in BODY_HEIGHTS:
			for d in range(0, int(TILE), 4):
				var a: Vector2 = start + direction * d
				var b: Vector2 = start + direction * (d + 4)
				if _blocked(Vector3(a.x, profile[d] + up, a.y), Vector3(b.x, profile[d + 4] + up, b.y)):
					return false
	return true


func _print_map(grid: MapGrid) -> void:
	# Plus grande zone d'un seul tenant : c'est là que l'on se promène.
	var seen := {}
	var best: Array[Vector2i] = []
	for cy in grid.size.y:
		for cx in grid.size.x:
			var start := grid.origin + Vector2i(cx, cy)
			if seen.has(start) or not grid.is_standable(start):
				continue
			var area: Array[Vector2i] = [start]
			seen[start] = true
			var k := 0
			while k < area.size():
				var cell := area[k]
				k += 1
				for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
					var next: Vector2i = cell + step
					if not seen.has(next) and grid.can_move(cell, next):
						seen[next] = true
						area.append(next)
			if area.size() > best.size():
				best = area
	var reachable := {}
	for cell in best:
		reachable[cell] = true
	print("largest connected area: ", best.size(), " cells")
	var header := "    "
	for cx in grid.size.x:
		header += str(absi(grid.origin.x + cx) % 10)
	print(header)
	for cy in grid.size.y:
		var line := ""
		for cx in grid.size.x:
			var cell := grid.origin + Vector2i(cx, cy)
			if reachable.has(cell):
				line += "o"
			elif grid.is_standable(cell):
				line += "."
			else:
				line += "#"
		print("%3d %s" % [grid.origin.y + cy, line])
