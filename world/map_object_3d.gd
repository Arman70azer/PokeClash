class_name MapObject3D
extends MeshInstance3D
## Objet 3D posé sur la carte en plus de la zone (maison, fontaine...), pris dans
## assets/mapobjects.
## Échelle : 16 unités = 1 case. La position du nœud est celle de l'origine du modèle :
## x = unités vers la droite, z = unités vers le bas de la carte, y = hauteur du sol.

## Cases de la carte bloquées par l'objet.
@export var footprint: Rect2i
## Cases bloquées supplémentaires (boîte aux lettres, etc.).
@export var extra_cells: Array[Vector2i] = []
## Agrandissement du modèle. Certains objets (fontaine, parasol) sont modélisés dans
## une unité 16 fois plus petite que les bâtiments.
@export var model_scale := 1.0
## Surfaces dont la texture défile, pour animer de l'eau : nom de la surface (matériau
## du .obj) -> vitesse en répétitions de texture par seconde.
@export var scrolling_surfaces: Dictionary = {}
## Balancement des objets qui flottent (bateaux, bouées) : amplitude verticale en
## unités (0 : immobile) et durée d'un aller-retour en secondes.
@export var bob_height := 0.0
@export var bob_period := 3.0

var _rest_y := 0.0
var _bob_phase := 0.0


func _ready() -> void:
	add_to_group("map_objects")
	add_to_group("fade_receivers")
	scale = Vector3.ONE * model_scale
	MapMaterials.apply(self)
	MapMaterials.add_vision_collider(self)
	for i in mesh.get_surface_count():
		var surface := (mesh as ArrayMesh).surface_get_name(i) if mesh is ArrayMesh else ""
		var mat := get_surface_override_material(i) as ShaderMaterial
		if mat != null and scrolling_surfaces.has(surface):
			mat.set_shader_parameter("uv_scroll", scrolling_surfaces[surface])
	_rest_y = position.y
	# Chaque objet a sa propre phase, d'après sa place : ils ne bougent pas tous ensemble.
	_bob_phase = fposmod(position.x * 0.037 + position.z * 0.051, TAU)
	set_process(bob_height > 0.0)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	position.y = _rest_y + sin(t * TAU / bob_period + _bob_phase) * bob_height


func blocks(cell: Vector2i) -> bool:
	return footprint.has_point(cell) or cell in extra_cells

