class_name ExpeditionZone
extends Node3D
## Zone affichée d'après un plan (ZoneLayout) plutôt que d'après des calques peints à la
## main : le sol est composé en une seule image à partir des tuiles, les décors sont des
## modèles 3D ou des sprites debout (comme les arbres de TileZone), les murs peuvent être
## des falaises. Un pas dans les rencontres s'anime (on_step) : les hautes herbes bougent
## et cachent les pieds, le sable vole. Sert aux zones d'expédition générées au hasard et
## au passage qui y mène depuis Accumula.

const TILE := GameConfig.TILE
## Animation des herbes et du sable, en secondes.
const RUSTLE_TIME := 0.35
const PUFF_TIME := 0.4
## Herbe devant les pieds : hauteur (elle couvre le bas des jambes) et départ, un peu au
## sud des pieds, en unités.
const FRONT_GRASS_HEIGHT := 18.0
const FRONT_GRASS_SOUTH := 3.0
## Avancée vers la caméra (et autant vers le haut : même place à l'écran) des effets
## posés sur un personnage, pour qu'ils passent devant son sprite, dessiné debout.
const OVER_SHIFT := 12.0
## Particules d'un pas : côté et force de chacune (les feuilles jaillissent de part et
## d'autre du personnage, hors de sa silhouette).
const LEAVES: Array[float] = [-1.0, -0.55, 0.55, 1.0]
const PUFFS: Array[float] = [-1.0, 0.0, 1.0]

## Hauteur du sol de la zone.
@export var ground_height := 0.0

var layout: ZoneLayout
var _grid: MapGrid
## Images des tuiles en RGBA8, préparées une seule fois par image (le tileset fait 13 Mo :
## le relire depuis la carte graphique à chaque zone coûte cher).
static var _sheet_images := {}
static var _particles := {}  # nom -> texture de particule (feuille, sable)
## Hautes herbes en 3D : leurs exemplaires, et la case (du monde) de chacun.
var _grass: MultiMesh
var _grass_index := {}
## Herbe dessinée devant les pieds de chaque marcheur qui est dedans (id -> nœud).
var _fronts := {}


## Construit la zone (à appeler avant ou pendant l'entrée dans l'arbre).
func build(p_layout: ZoneLayout) -> void:
	layout = p_layout
	_grid = null
	for child in get_children():
		child.queue_free()
	grid()
	_build_ground()
	_build_props()
	_build_cliffs()


## Grille de déplacement (voir GameMap.zones).
func grid() -> MapGrid:
	if _grid == null and layout != null:
		_grid = _make_grid()
	return _grid


## Vrai si cette case du monde est dans les hautes herbes.
func is_encounter(cell: Vector2i) -> bool:
	return layout != null and layout.encounter.has(layout.to_local(cell))


func _make_grid() -> MapGrid:
	var g := MapGrid.new()
	g.origin = layout.origin
	g.size = layout.size
	g.heights.resize(layout.size.x * layout.size.y)
	g.heights.fill(ground_height)
	g.flags.resize(layout.size.x * layout.size.y)
	for cell: Vector2i in layout.walkable:
		var f := MapGrid.STANDABLE
		if layout.walkable.has(cell + Vector2i.RIGHT):
			f |= MapGrid.EAST
		if layout.walkable.has(cell + Vector2i.DOWN):
			f |= MapGrid.SOUTH
		g.flags[cell.y * layout.size.x + cell.x] = f
	return g


static func _sheet_image(texture: Texture2D) -> Image:
	if not _sheet_images.has(texture):
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_sheet_images[texture] = image
	return _sheet_images[texture]


func _build_ground() -> void:
	var sheet := _sheet_image(layout.sheet if layout.sheet != null else TileZone.TILESHEET)
	var image := Image.create(layout.size.x * TILE, layout.size.y * TILE, false, Image.FORMAT_RGBA8)
	for cell: Vector2i in layout.ground:
		var tile: Vector2i = layout.ground[cell]
		image.blit_rect(sheet, Rect2i(tile * TILE, Vector2i(TILE, TILE)), cell * TILE)
	for cell: Vector2i in layout.overlay:
		var tile: Vector2i = layout.overlay[cell]
		image.blend_rect(sheet, Rect2i(tile * TILE, Vector2i(TILE, TILE)), cell * TILE)
	var size := Vector2(layout.size * TILE)
	var plane := PlaneMesh.new()
	plane.size = size
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(layout.origin.x * TILE + size.x / 2.0, ground_height, layout.origin.y * TILE + size.y / 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = MapMaterials.SHADER
	mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(image))
	floor_mesh.set_surface_override_material(0, mat)
	add_child(floor_mesh)


func _build_props() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	# Décors 3D : un seul MultiMesh par modèle, quel que soit leur nombre (une zone de
	# forêt compte des centaines d'arbres).
	var models := {}  # Mesh -> positions
	for entry in layout.props:
		var prop: ExpeditionProp = entry["prop"]
		var cell: Vector2i = layout.to_world(entry["cell"])
		if prop.mesh != null:
			var at := Vector3((cell.x + prop.footprint.x / 2.0) * TILE, ground_height, (cell.y + prop.footprint.y / 2.0) * TILE)
			models.get_or_add(prop.mesh, []).append(at)
			continue
		var sprite := TileZone.standing_sprite(Rect2(prop.region), prop.sheet)
		# Pied du sprite : au milieu du bas de son emprise.
		sprite.position = Vector3((cell.x + prop.footprint.x / 2.0) * TILE, ground_height,
			(cell.y + prop.footprint.y) * TILE - 3.0)
		props.add_child(sprite)
	for model: Mesh in models:
		props.add_child(_repeated(model, models[model]))
	_grass = null
	_grass_index.clear()
	if layout.encounter_mesh != null:
		var positions := []
		for local: Vector2i in layout.encounter:
			var cell := layout.to_world(local)
			_grass_index[cell] = positions.size()
			positions.append(_cell_center(cell))
		var node := _repeated(layout.encounter_mesh, positions)
		node.name = "Grass"
		_grass = node.multimesh
		props.add_child(node)


func _cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * TILE, ground_height, (cell.y + 0.5) * TILE)


## Exemplaires d'un modèle 3D posés aux positions données.
static func _repeated(model: Mesh, positions: Array) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = MapMaterials.shaded(model)
	multimesh.instance_count = positions.size()
	for i in positions.size():
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	return node


# --- Falaises -------------------------------------------------------------------------------

## Murs en falaises : un seul maillage (une surface par texture). Chaque case de mur a son
## dessus, et une paroi sur chaque côté qui donne sur plus bas qu'elle.
func _build_cliffs() -> void:
	if layout.cliffs.is_empty():
		return
	var styles := {}  # case locale -> style
	for y in layout.size.y:
		for x in layout.size.x:
			var cell := Vector2i(x, y)
			# Décors éparpillés : posés sur le sol, pas sur un bloc de falaise.
			if not layout.walkable.has(cell) and not layout.is_exit_lane(cell) and not layout.scattered.has(cell):
				styles[cell] = _cliff_style(cell)
	var tools := {}  # texture -> SurfaceTool
	for cell: Vector2i in styles:
		var style: CliffStyle = styles[cell]
		var corner := Vector3((layout.origin.x + cell.x) * TILE, ground_height, (layout.origin.y + cell.y) * TILE)
		var h := style.height
		# Dessus : la texture se répète à un pixel par unité.
		var top: Array = [corner + Vector3(0, h, 0), corner + Vector3(TILE, h, 0),
			corner + Vector3(TILE, h, TILE), corner + Vector3(0, h, TILE)]
		var size := Vector2(style.top.get_size())
		_quad(tools, style.top, top, Color.WHITE, top.map(func(p: Vector3) -> Vector2: return Vector2(p.x, p.z) / size))
		for dir in ZoneGenerator.DIRS:
			var next: Vector2i = cell + dir
			if not layout.in_bounds(next):
				continue
			var low := (styles[next] as CliffStyle).height if styles.has(next) else 0.0
			if low < h:
				_wall(tools, style, corner, dir, low, h)
	var mesh := ArrayMesh.new()
	for texture: Texture2D in tools:
		var st: SurfaceTool = tools[texture]
		st.commit(mesh)
		var mat := ShaderMaterial.new()
		mat.shader = MapMaterials.SHADER
		mat.set_shader_parameter("albedo_tex", texture)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var node := MeshInstance3D.new()
	node.name = "Cliffs"
	node.mesh = mesh
	add_child(node)


## Falaise basse près des passages (rien de caché derrière elle), haute au-delà.
func _cliff_style(cell: Vector2i) -> CliffStyle:
	if layout.cliffs.size() == 1:
		return layout.cliffs[0]
	for dy in range(1, layout.cliff_clearance + 1):
		for dx in range(-1, 2):
			var near := cell + Vector2i(dx, -dy)
			if layout.walkable.has(near) or layout.is_exit_lane(near):
				return layout.cliffs[0]
	return layout.cliffs[1]


## Paroi d'un côté de la case, de `low` à `high` : les bandes du style, rognées.
func _wall(tools: Dictionary, style: CliffStyle, corner: Vector3, dir: Vector2i, low: float, high: float) -> void:
	var a: Vector3
	var b: Vector3
	match dir:
		Vector2i.DOWN:
			a = corner + Vector3(0, 0, TILE)
			b = corner + Vector3(TILE, 0, TILE)
		Vector2i.UP:
			a = corner + Vector3(TILE, 0, 0)
			b = corner
		Vector2i.LEFT:
			a = corner
			b = corner + Vector3(0, 0, TILE)
		_:
			a = corner + Vector3(TILE, 0, TILE)
			b = corner + Vector3(TILE, 0, 0)
	# Ombrage peint : la face vers la caméra plus claire que les côtés.
	var shade := Color(0.92, 0.92, 0.92) if dir == Vector2i.DOWN else Color(0.75, 0.75, 0.78)
	# Le long de la paroi, la texture se répète à un pixel par unité.
	var along := func(p: Vector3) -> float: return p.x if dir.y != 0 else p.z
	var bottom := 0.0
	for i in style.bands.size():
		var top := bottom + style.band_heights[i]
		var from := maxf(bottom, low)
		var to := minf(top, high)
		if to > from:
			var size := Vector2(style.bands[i].get_size())
			var span := top - bottom if style.stretch_bands else size.y
			var v_top := (top - to) / span
			var v_bottom := (top - from) / span
			var u_a: float = along.call(a) / size.x
			var u_b: float = along.call(b) / size.x
			_quad(tools, style.bands[i], [a + Vector3(0, to, 0), b + Vector3(0, to, 0), b + Vector3(0, from, 0),
				a + Vector3(0, from, 0)], shade, [Vector2(u_a, v_top), Vector2(u_b, v_top), Vector2(u_b, v_bottom), Vector2(u_a, v_bottom)])
		bottom = top


## Un quadrilatère texturé (coins dans l'ordre), ajouté à la surface de sa texture.
static func _quad(tools: Dictionary, texture: Texture2D, corners: Array, shade: Color,
		uvs: Array = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]) -> void:
	if not tools.has(texture):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[texture] = st
	var tool: SurfaceTool = tools[texture]
	for k in [0, 1, 2, 0, 2, 3]:
		tool.set_color(shade)
		tool.set_uv(uvs[k])
		tool.add_vertex(corners[k])


# --- Pas dans les rencontres ----------------------------------------------------------------

## Un personnage (joueur) avance sur cette case du monde, en `step_time` secondes : les
## herbes bougent et cachent ses pieds, ou le sable vole, comme dans les jeux.
func on_step(walker: Node3D, cell: Vector2i, step_time := 0.2) -> void:
	if layout == null or not is_inside_tree():
		return
	var inside := layout.encounter.has(layout.to_local(cell))
	match layout.step_effect:
		&"grass":
			_show_front_grass(walker, cell if inside else null, step_time)
			if inside:
				_rustle(cell)
				for i in LEAVES.size():
					_particle(&"leaf", cell, LEAVES[i])
		&"sand":
			if inside:
				for i in PUFFS.size():
					_particle(&"sand", cell, PUFFS[i])


## L'herbe devant les pieds du marcheur (null : il n'est plus dans l'herbe). Elle apparaît
## à mi-pas, quand il entre dans la case.
func _show_front_grass(walker: Node3D, cell: Variant, step_time: float) -> void:
	for id in _fronts.keys():
		if not is_instance_id_valid(id):
			(_fronts[id] as Node).queue_free()
			_fronts.erase(id)
	var front: MeshInstance3D = _fronts.get(walker.get_instance_id())
	if cell == null:
		if front != null:
			front.visible = false
		return
	if front == null:
		front = _front_grass_node()
		_fronts[walker.get_instance_id()] = front
		add_child(front)
	front.visible = false
	var rest := _cell_center(cell) + Vector3(0, OVER_SHIFT + FRONT_GRASS_HEIGHT / 2.0, FRONT_GRASS_SOUTH + OVER_SHIFT)
	front.position = rest
	# Elle apparaît à mi-pas, quand il entre dans la case, en s'agitant.
	var tween := create_tween()
	tween.tween_callback(func(): front.visible = true).set_delay(step_time * 0.5)
	tween.tween_method(func(t: float) -> void:
		var swing := sin(t * TAU * 2.0) * (1.0 - t)
		front.position = rest + Vector3(swing * 2.0, 0, 0)
		front.scale = Vector3(1.0 + 0.15 * absf(swing), 1.0 + 0.2 * (1.0 - t), 1.0)
		, 0.0, 1.0, RUSTLE_TIME)


func _front_grass_node() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(TILE, FRONT_GRASS_HEIGHT)
	var node := MeshInstance3D.new()
	node.name = "FrontGrass"
	node.mesh = quad
	# La texture de la touffe d'herbe (sa première couche).
	var shaded := MapMaterials.shaded(layout.encounter_mesh)
	node.material_override = shaded.surface_get_material(0)
	return node


## La touffe tremble : elle s'écarte de part et d'autre puis se remet en place.
func _rustle(cell: Vector2i) -> void:
	if _grass == null or not _grass_index.has(cell):
		return
	var index: int = _grass_index[cell]
	var center := _cell_center(cell)
	var shake := func(t: float) -> void:
		var swing := sin(t * TAU * 2.0) * (1.0 - t)
		var basis := Basis.from_scale(Vector3(1.0 + 0.12 * absf(swing), 1.0, 1.0 + 0.12 * absf(swing)))
		_grass.set_instance_transform(index, Transform3D(basis, center + Vector3(swing * 1.5, 0, 0)))
	create_tween().tween_method(shake, 0.0, 1.0, RUSTLE_TIME)


## Une petite particule (feuille ou grain de sable) qui jaillit du pied et retombe ;
## `side` : de -1 (à gauche) à 1 (à droite).
func _particle(kind: StringName, cell: Vector2i, side: float) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = _particle_texture(kind)
	sprite.pixel_size = 1.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var start := _cell_center(cell) + Vector3(side * 5.0, 2.0 + OVER_SHIFT, 4.0 + OVER_SHIFT)
	sprite.position = start
	add_child(sprite)
	var leaf := kind == &"leaf"
	var time := RUSTLE_TIME + 0.15 if leaf else PUFF_TIME
	var rise := (14.0 - 5.0 * absf(side)) if leaf else 3.0
	var drift := Vector3(side * (9.0 if leaf else 8.0), 0, 0)
	var tween := create_tween().set_parallel()
	tween.tween_method(func(t: float) -> void:
		sprite.position = start + drift * t + Vector3(0, rise * 4.0 * t * (1.0 - t), 0)
		if kind == &"sand":
			sprite.scale = Vector3.ONE * (1.0 + t)
		, 0.0, 1.0, time)
	tween.tween_property(sprite, "modulate:a", 0.0, time).set_delay(time * 0.4)
	tween.chain().tween_callback(sprite.queue_free)


## Petites textures dessinées une fois : une feuille verte, une bouffée de sable.
static func _particle_texture(kind: StringName) -> Texture2D:
	if not _particles.has(kind):
		var rows: PackedStringArray
		var colors := {}
		if kind == &"leaf":
			rows = PackedStringArray([".aa.", "aabb", ".bb.", "..b."])
			colors = {"a": Color8(184, 240, 128), "b": Color8(88, 168, 72)}
		else:
			rows = PackedStringArray([".aab.", "aaabb", "abbb.", ".bb.."])
			colors = {"a": Color8(248, 224, 160), "b": Color8(216, 176, 112)}
		var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				var key := rows[y][x]
				image.set_pixel(x, y, colors[key] if colors.has(key) else Color(0, 0, 0, 0))
		_particles[kind] = ImageTexture.create_from_image(image)
	return _particles[kind]

