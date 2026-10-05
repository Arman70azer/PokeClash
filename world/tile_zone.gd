class_name TileZone
extends Node3D
## Zone de la carte construite avec des tuiles 2D et des objets 3D, plutôt qu'avec un
## seul grand modèle (voir MapZone). Pratique pour créer ses propres quartiers.
##
## Calques de tuiles (enfants, peints dans l'éditeur en vue 2D, coordonnées des cases
## du monde : x vers la droite, y vers le bas de la carte) :
## - Ground : le sol de base (herbe) ; une case sans sol n'est pas praticable
## - GroundDetail : ce qui se pose sur le sol (pavés, chemins, eau)
## - GroundDecor : décor posé par-dessus (motifs, bordures)
## - Obstacles : décor debout qui bloque la case (arbres, réverbères, buissons)
## Ces trois premiers calques sont rendus dans une texture posée à plat, à la hauteur
## `ground_height` ; les tuiles marquées "solid" dans le TileSet (eau) bloquent.
## Les bâtiments sont des MapObject3D placés sous le nœud Buildings.

const TILE := GameConfig.TILE
const PIXEL_SPRITE_SHADER := preload("res://shaders/pixel_sprite.gdshader")
## Image du tileset (version en deux colonnes de assets/tilesets/tileset.png, dont la
## hauteur d'origine dépasse la taille maximale d'une texture).
const TILESHEET := preload("res://assets/tilesets/tileset_wide.png")

## Arbres : un arbre occupe 2x2 cases sur le calque Obstacles, peintes avec les quatre
## tuiles centrales de l'arbre. La tuile en haut à gauche identifie l'arbre et donne la
## zone complète (64x48) à afficher ; les trois autres ne servent qu'à bloquer.
const TREE_REGIONS := {
	Vector2i(1, 2): Rect2(0, 16, 64, 48),
	Vector2i(5, 2): Rect2(64, 16, 64, 48),
	Vector2i(1, 5): Rect2(0, 64, 64, 48),
	Vector2i(5, 5): Rect2(64, 64, 64, 48),
}
const TREE_BODY_COLUMNS := [1, 2, 5, 6]
const TREE_BODY_ROWS := [2, 3, 5, 6]
## Décors hauts d'une case de large : on peint seulement leur tuile du bas, qui donne
## la zone complète à afficher (réverbères, sapins).
const TALL_PROPS := {
	Vector2i(5, 97): Rect2(80, 95 * 16, 16, 48),
	Vector2i(5, 100): Rect2(80, 98 * 16, 16, 48),
	Vector2i(4, 102): Rect2(64, 101 * 16, 16, 32),
}

## Hauteur du sol de la zone.
@export var ground_height := 0.0

var _grid: MapGrid


func _ready() -> void:
	grid()
	_build_ground()
	_build_props()


## Grille de déplacement de la zone, calculée d'après les calques de tuiles.
func grid() -> MapGrid:
	if _grid == null:
		_grid = _build_grid()
	return _grid


func _layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	for n in ["Ground", "GroundDetail", "GroundDecor"]:
		var layer := get_node_or_null(n) as TileMapLayer
		if layer != null:
			layers.append(layer)
	return layers


func _build_grid() -> MapGrid:
	var ground := $Ground as TileMapLayer
	var obstacles := get_node_or_null("Obstacles") as TileMapLayer
	var rect := ground.get_used_rect()
	var g := MapGrid.new()
	g.origin = rect.position
	g.size = rect.size
	g.heights.resize(rect.size.x * rect.size.y)
	g.heights.fill(ground_height)
	g.flags.resize(rect.size.x * rect.size.y)
	var standable := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var ok := ground.get_cell_source_id(cell) != -1
			for layer in _layers():
				var data := layer.get_cell_tile_data(cell)
				if data != null and data.get_custom_data("solid"):
					ok = false
			if obstacles != null and obstacles.get_cell_source_id(cell) != -1:
				ok = false
			if ok:
				standable[cell] = true
	for cell: Vector2i in standable:
		var i: int = (cell.y - rect.position.y) * rect.size.x + (cell.x - rect.position.x)
		var f := MapGrid.STANDABLE
		if standable.has(cell + Vector2i.RIGHT):
			f |= MapGrid.EAST
		if standable.has(cell + Vector2i.DOWN):
			f |= MapGrid.SOUTH
		g.flags[i] = f
	return g


func _build_ground() -> void:
	# Les calques de sol sont rendus dans une texture, plaquée sur un plan horizontal.
	var rect := ($Ground as TileMapLayer).get_used_rect()
	var size := rect.size * TILE
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for layer in _layers():
		layer.reparent(viewport, false)
		layer.position = Vector2(-rect.position * TILE)
	var obstacles := get_node_or_null("Obstacles") as TileMapLayer
	if obstacles != null:
		obstacles.visible = false

	var plane := PlaneMesh.new()
	plane.size = Vector2(size)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(rect.position.x * TILE + size.x / 2.0, ground_height, rect.position.y * TILE + size.y / 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = MapMaterials.SHADER
	mat.set_shader_parameter("albedo_tex", viewport.get_texture())
	floor_mesh.set_surface_override_material(0, mat)
	# Le sol participe au fondu de niveau : vu d'une place en contrebas, il passe devant
	# le fond de la place.
	floor_mesh.add_to_group("fade_receivers")
	add_child(floor_mesh)


func _build_props() -> void:
	# Chaque tuile du calque Obstacles devient un sprite debout (un seul par arbre).
	var obstacles := get_node_or_null("Obstacles") as TileMapLayer
	if obstacles == null:
		return
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	for cell in obstacles.get_used_cells():
		var atlas := obstacles.get_cell_atlas_coords(cell)
		var sprite: MeshInstance3D
		if TREE_REGIONS.has(atlas):
			sprite = _standing_sprite(TREE_REGIONS[atlas])
			sprite.position = Vector3((cell.x + 1) * TILE, ground_height, (cell.y + 2) * TILE - 3.0)
		elif atlas.x in TREE_BODY_COLUMNS and atlas.y in TREE_BODY_ROWS:
			continue
		elif TALL_PROPS.has(atlas):
			sprite = _standing_sprite(TALL_PROPS[atlas])
			sprite.position = Vector3(cell.x * TILE + TILE / 2.0, ground_height, cell.y * TILE + TILE - 3.0)
		else:
			sprite = _standing_sprite(Rect2(Vector2(atlas * TILE), Vector2(TILE, TILE)))
			sprite.position = Vector3(cell.x * TILE + TILE / 2.0, ground_height, cell.y * TILE + TILE - 3.0)
		sprite.add_to_group("fade_receivers")
		props.add_child(sprite)


## Sprite debout, toujours face à l'écran, qui rétrécit avec la distance comme le sol.
## L'origine est le pied du sprite (bas, centre).
func _standing_sprite(region: Rect2) -> MeshInstance3D:
	return standing_sprite(region)


## Sprite debout découpé dans le tileset (voir _standing_sprite) ; aussi utilisé par les
## zones générées (ExpeditionZone).
static func standing_sprite(region: Rect2) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = region.size
	quad.center_offset = Vector3(0.0, region.size.y / 2.0, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = PIXEL_SPRITE_SHADER
	mat.set_shader_parameter("sheet", TILESHEET)
	var sheet_size := Vector2(TILESHEET.get_size())
	mat.set_shader_parameter("region", Vector4(region.position.x / sheet_size.x, region.position.y / sheet_size.y,
		region.size.x / sheet_size.x, region.size.y / sheet_size.y))
	mat.set_shader_parameter("perspective_scale", true)
	quad.material = mat
	var sprite := MeshInstance3D.new()
	sprite.mesh = quad
	# Le shader déplace les sommets : marge pour ne pas être masqué à tort hors champ.
	sprite.extra_cull_margin = 64.0
	return sprite
