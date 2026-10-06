class_name MapMaterials
extends RefCounted
## Matériaux des modèles 3D de la carte (zones entières et objets posés dessus).
## Rendu façon DS : pas d'éclairage, textures nettes, et l'ombrage peint dans les
## couleurs de sommets du modèle quand il y en a. Les matériaux gèrent aussi le fondu
## de niveau (voir shaders/map_zone.gdshaderinc et MapZone).

const SHADER := preload("res://shaders/map_zone.gdshader")
const SHADOW_SHADER := preload("res://shaders/map_zone_shadow.gdshader")
## Couche physique des volumes qui servent seulement à savoir si le décor cache un
## personnage (halo de vision, voir World.is_hidden_from_camera). Rien d'autre ne
## l'utilise : les déplacements passent par les grilles des zones.
const VISION_LAYER := 1 << 19

static var _mtl_cache := {}  # chemin du .obj -> {nom du matériau -> opacité}
static var _shaded_cache := {}  # modèle -> copie portant ses matériaux (voir shaded)
## Volume de vision de chaque modèle, calculé une fois pour toute la partie : le
## reconstruire à chaque retour en ville coûtait autant que de charger la carte.
static var _vision_shapes := {}  # modèle -> ConcavePolygonShape3D (null : rien d'opaque)


## Remplace les matériaux importés de chaque surface du modèle.
static func apply(instance: MeshInstance3D) -> void:
	var mesh := instance.mesh
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var mat := _material_for(mesh, i)
		if mat != null:
			instance.set_surface_override_material(i, mat)


## Copie du modèle dont les surfaces portent déjà leurs matériaux, partagée par tous ses
## exemplaires : pour les décors répétés (MultiMesh), qui n'ont pas de matériau par
## exemplaire.
static func shaded(mesh: Mesh) -> Mesh:
	if not _shaded_cache.has(mesh):
		var copy := mesh.duplicate() as ArrayMesh
		for i in copy.get_surface_count():
			var mat := _material_for(mesh, i)
			if mat != null:
				copy.surface_set_material(i, mat)
		_shaded_cache[mesh] = copy
	return _shaded_cache[mesh]


static func _material_for(mesh: Mesh, surface: int) -> ShaderMaterial:
	# Seuls les maillages importés (ArrayMesh) portent un nom par surface.
	var surface_name := ""
	if mesh is ArrayMesh:
		surface_name = (mesh as ArrayMesh).surface_get_name(surface)
	var texture := _texture_for(mesh, surface, surface_name)
	if texture == null:
		return null
	var mat := ShaderMaterial.new()
	# "kage" = ombre portée semi-transparente peinte dans le modèle. Certains
	# modèles rendent l'ombre transparente par le matériau plutôt que par la texture.
	var opacity := _mtl_opacity(mesh, surface_name)
	var see_through := "kage" in surface_name or "kage" in texture.resource_path.get_file() or opacity < 0.99
	mat.shader = SHADOW_SHADER if see_through else SHADER
	mat.set_shader_parameter("albedo_tex", texture)
	mat.set_shader_parameter("opacity", opacity)
	return mat


## Règle le fondu de niveau sur toutes les surfaces du modèle.
static func set_fade(instance: MeshInstance3D, box: AABB, amount: float) -> void:
	for i in instance.get_surface_override_material_count():
		var mat := instance.get_surface_override_material(i) as ShaderMaterial
		if mat == null and instance.mesh != null:
			mat = instance.mesh.surface_get_material(i) as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("fade_min", box.position)
		mat.set_shader_parameter("fade_max", box.end)
		mat.set_shader_parameter("fade_amount", amount)


## Cache net la géométrie du modèle comprise dans la boîte (repère du monde) : une porte
## peinte remplacée par son battant animé (voir PanelDoor). Les boîtes s'ajoutent.
static func hide_box(instance: MeshInstance3D, box: AABB) -> void:
	var boxes: Array = instance.get_meta(&"hidden_boxes", [])
	boxes.append(box)
	instance.set_meta(&"hidden_boxes", boxes)
	var mins := PackedVector3Array()
	var maxs := PackedVector3Array()
	for b: AABB in boxes:
		mins.append(b.position)
		maxs.append(b.end)
	for i in instance.get_surface_override_material_count():
		var mat := instance.get_surface_override_material(i) as ShaderMaterial
		if mat == null:
			continue
		mat.set_shader_parameter("hide_count", boxes.size())
		mat.set_shader_parameter("hide_min", mins)
		mat.set_shader_parameter("hide_max", maxs)


## Opacité d'un matériau d'après le réglage « d » du fichier .mtl voisin du modèle.
## On le lit directement : ces fichiers renseignent aussi « Tr » de façon incohérente,
## et l'importeur de Godot en déduit une opacité fausse.
static func _mtl_opacity(mesh: Mesh, material_name: String) -> float:
	var obj_path := mesh.resource_path
	if not _mtl_cache.has(obj_path):
		var values := {}
		var obj := FileAccess.open(obj_path, FileAccess.READ)
		if obj != null:
			# « mtllib » est dans l'en-tête : inutile de lire les milliers de sommets qui
			# suivent (c'était l'essentiel du temps de chargement d'un intérieur).
			while not obj.eof_reached():
				var line := obj.get_line().strip_edges()
				if line.begins_with("mtllib "):
					_read_mtl(obj_path.get_base_dir().path_join(line.substr(7).strip_edges()), values)
				elif line.begins_with("v ") or line.begins_with("usemtl "):
					break
		_mtl_cache[obj_path] = values
	return _mtl_cache[obj_path].get(material_name, 1.0)


static func _read_mtl(path: String, values: Dictionary) -> void:
	var mtl := FileAccess.open(path, FileAccess.READ)
	if mtl == null:
		return
	var current := ""
	while not mtl.eof_reached():
		var parts := mtl.get_line().strip_edges().split(" ", false)
		if parts.size() >= 2 and parts[0] == "newmtl":
			current = parts[1]
		elif parts.size() >= 2 and parts[0] == "d" and current != "":
			values[current] = parts[1].to_float()


## Texture d'une surface : celle du matériau importé, sinon un fichier portant le nom
## de la surface dans le dossier du modèle (cas des .obj dont le .mtl est introuvable).
static func _texture_for(mesh: Mesh, surface: int, surface_name: String) -> Texture2D:
	var imported := mesh.surface_get_material(surface) as BaseMaterial3D
	if imported != null and imported.albedo_texture != null:
		return imported.albedo_texture
	var path := mesh.resource_path.get_base_dir().path_join(surface_name + ".png")
	if not surface_name.is_empty() and ResourceLoader.exists(path):
		return load(path)
	return null


## Ajoute au modèle un volume de collision fait de ses surfaces opaques (les ombres
## peintes au sol, transparentes, n'en font pas partie), sur la couche VISION_LAYER.
## Le volume est un enfant du modèle : il suit ses déplacements (bateaux qui tanguent).
static func add_vision_collider(instance: MeshInstance3D) -> void:
	var mesh := instance.mesh
	if mesh == null:
		return
	if not _vision_shapes.has(mesh):
		_vision_shapes[mesh] = _vision_shape(instance)
	var shape: ConcavePolygonShape3D = _vision_shapes[mesh]
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.collision_layer = VISION_LAYER
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	instance.add_child(body)


static func _vision_shape(instance: MeshInstance3D) -> ConcavePolygonShape3D:
	var mesh := instance.mesh
	var faces := PackedVector3Array()
	for i in mesh.get_surface_count():
		var mat := instance.get_surface_override_material(i) as ShaderMaterial
		if mat != null and mat.shader == SHADOW_SHADER:
			continue
		var arrays := mesh.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices is PackedInt32Array and not indices.is_empty():
			for k in indices:
				faces.append(vertices[k])
		else:
			faces.append_array(vertices)
	if faces.is_empty():
		return null
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape
