class_name ExpeditionZone
extends Node3D
## Zone affichée d'après un plan (ZoneLayout) plutôt que d'après des calques peints à la
## main : le sol est composé en une seule image à partir des tuiles du tileset, les
## décors sont des sprites debout (comme les arbres de TileZone). Sert aux zones
## d'expédition générées au hasard et au passage qui y mène depuis Accumula.

const TILE := GameConfig.TILE

## Hauteur du sol de la zone.
@export var ground_height := 0.0

var layout: ZoneLayout
var _grid: MapGrid


## Construit la zone (à appeler avant ou pendant l'entrée dans l'arbre).
func build(p_layout: ZoneLayout) -> void:
	layout = p_layout
	_grid = null
	for child in get_children():
		child.queue_free()
	grid()
	_build_ground()
	_build_props()


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


func _build_ground() -> void:
	var sheet := TileZone.TILESHEET.get_image()
	if sheet.is_compressed():
		sheet.decompress()
	sheet.convert(Image.FORMAT_RGBA8)
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
	for entry in layout.props:
		var prop: ExpeditionProp = entry["prop"]
		var cell: Vector2i = layout.to_world(entry["cell"])
		var sprite := TileZone.standing_sprite(Rect2(prop.region), prop.sheet)
		# Pied du sprite : au milieu du bas de son emprise.
		sprite.position = Vector3((cell.x + prop.footprint.x / 2.0) * TILE, ground_height,
			(cell.y + prop.footprint.y) * TILE - 3.0)
		props.add_child(sprite)
