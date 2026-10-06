class_name PanelDoor
extends Door
## Porte plate d'une maison, d'un immeuble, d'un entrepôt… (la porte arrondie du Centre
## Pokémon est une Door). Le battant s'ouvre selon `style` : il pivote vers l'intérieur
## sur ses gonds (maisons), glisse dans le mur (portes automatiques vitrées, en un ou deux
## battants) ou remonte comme un rideau métallique.
##
## Deux façons d'obtenir le battant :
## - porte peinte sur la façade du modèle (Accumula, entrepôt frigorifique) : `zone_path`
##   désigne le modèle (MapZone ou MapObject3D), et `surface_name` la surface de la porte
##   ou `cut_box` la boîte (repère du monde) qui l'entoure. Cette partie du modèle est
##   cachée par le shader et remplacée par sa copie, devant un renfoncement sombre ;
## - embrasure sombre sans porte (les bâtiments rippés n'ont pas leurs portes, qui sont des
##   objets à part dans les jeux) : battant fait d'une texture (`leaf_texture`), posé dans
##   l'embrasure. Le nœud est alors au milieu du bas de la porte, sur la façade.
## Rien n'est calculé à chaque image : battants et renfoncement sont construits une fois,
## et seule l'ouverture anime deux ou trois nœuds.

enum Style { SWING, SLIDE, DOUBLE_SLIDE, SHUTTER }

## Couleur de l'intérieur vu par la porte ouverte (noir, comme dans les jeux).
const DARK := Color(0.04, 0.035, 0.06)
## Ouverture d'un battant à gonds (degrés) : il rentre dans le bâtiment.
const SWING_ANGLE := 92.0
## Les battants qui glissent passent juste derrière la façade, qui les cache.
const SLIDE_INSET := 1.5

@export var style := Style.SWING
## Largeur et hauteur de la porte, en unités (déduites de la surface ou de la boîte).
@export var size := Vector2(18, 28)
## Façade inclinée (degrés, le haut part vers l'intérieur) : la tour du phare.
@export var tilt := 0.0
@export_group("Battant en texture")
@export var leaf_texture: Texture2D
## Partie de la texture, en pixels (vide : toute la texture).
@export var leaf_region := Rect2()
## Répétitions de la texture sur le battant (une vitre de 16 × 16 sur toute la porte).
@export var leaf_repeat := Vector2.ONE
## Retrait du battant derrière la façade, en unités (-1 : aucun pour un battant à gonds,
## SLIDE_INSET pour les autres). Une porte vitrée au fond d'un sas glisse ainsi derrière
## les murs qui l'entourent.
@export var inset := -1.0
@export_group("Porte peinte sur le modèle")
## Boîte (repère du monde) qui entoure la porte peinte, si elle n'a pas sa propre surface.
@export var cut_box := AABB()
## Profondeur du renfoncement sombre derrière la porte (0 : aucun, l'embrasure du modèle
## est déjà sombre). Pour un battant en texture posé sur un mur plein (le phare), le mur
## est caché à cet endroit si `zone_path` désigne le modèle.
@export var dark_depth := 0.0

## Pivots animés : un par battant.
var _hinges: Array[Node3D] = []


func _ready() -> void:
	if not surface_name.is_empty() or cut_box.has_volume():
		_build_from_model()
	elif leaf_texture != null:
		_build_from_texture()
	else:
		push_error("PanelDoor %s : ni texture, ni porte du modèle" % name)
		return
	rotation.x = -deg_to_rad(tilt)
	if dark_depth > 0.0:
		add_child(_recess())


func open() -> void:
	await _animate(1.0, OPEN_TIME)


func close() -> void:
	await _animate(0.0, OPEN_TIME)


func set_open() -> void:
	for i in _hinges.size():
		_place(1.0, i)


## Amène chaque battant à `amount` (0 : fermé, 1 : ouvert).
func _animate(amount: float, duration: float) -> void:
	if _hinges.is_empty():
		return
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _hinges.size():
		tween.tween_method(_place.bind(i), _amount(i), amount, duration)
	await tween.finished


func _place(amount: float, i: int) -> void:
	var hinge := _hinges[i]
	hinge.set_meta(&"amount", amount)
	match style:
		Style.SWING:
			hinge.rotation.y = deg_to_rad(SWING_ANGLE) * amount
		Style.SLIDE:
			hinge.position.x = size.x * amount
		Style.DOUBLE_SLIDE:
			var side := -1.0 if i == 0 else 1.0
			hinge.position.x = side * size.x / 2.0 * amount
		Style.SHUTTER:
			hinge.position.y = size.y * amount


func _amount(i: int) -> float:
	return _hinges[i].get_meta(&"amount", 0.0)


## Pivot d'un battant placé en `at` (par rapport au bas de la porte) ; le battant, déjà
## placé par rapport au bas de la porte, devient son enfant.
func _add_hinge(leaf: MeshInstance3D, at: Vector3) -> void:
	var hinge := Node3D.new()
	hinge.position = at
	leaf.position = -at
	hinge.add_child(leaf)
	add_child(hinge)
	_hinges.append(hinge)


# --- Battant en texture -----------------------------------------------------------------

func _build_from_texture() -> void:
	var tex_size := leaf_texture.get_size()
	var region := leaf_region if leaf_region.has_area() else Rect2(Vector2.ZERO, tex_size)
	var uv0 := region.position / tex_size
	var uv1 := region.end / tex_size
	var z := -inset if inset >= 0.0 else (0.0 if style == Style.SWING else -SLIDE_INSET)
	var mat := ShaderMaterial.new()
	mat.shader = MapMaterials.SHADER
	mat.set_shader_parameter("albedo_tex", leaf_texture)
	var w := size.x
	if style == Style.DOUBLE_SLIDE:
		for side in 2:
			var x0 := -w / 2.0 if side == 0 else 0.0
			var u0 := uv0.x + (uv1.x - uv0.x) * leaf_repeat.x * (0.0 if side == 0 else 0.5)
			var u1 := uv0.x + (uv1.x - uv0.x) * leaf_repeat.x * (0.5 if side == 0 else 1.0)
			var leaf := _quad(x0, x0 + w / 2.0, z, Vector2(u0, uv0.y), Vector2(u1, uv0.y + (uv1.y - uv0.y) * leaf_repeat.y), mat)
			_add_hinge(leaf, Vector3.ZERO)
		return
	var leaf := _quad(-w / 2.0, w / 2.0, z, uv0, uv0 + (uv1 - uv0) * leaf_repeat, mat)
	_add_hinge(leaf, Vector3(-w / 2.0, 0, z) if style == Style.SWING else Vector3.ZERO)
	var model := get_node_or_null(zone_path) as MeshInstance3D if not zone_path.is_empty() else null
	if model != null and dark_depth > 0.0:
		var p := global_position
		MapMaterials.hide_box(model, AABB(Vector3(p.x - w / 2.0, p.y, p.z - dark_depth), Vector3(w, size.y, dark_depth + 0.5)))


## Rectangle debout de x0 à x1, de 0 à la hauteur de la porte, à la profondeur z.
func _quad(x0: float, x1: float, z: float, uv0: Vector2, uv1: Vector2, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.WHITE)
	var corners := [Vector3(x0, 0, z), Vector3(x1, 0, z), Vector3(x1, size.y, z), Vector3(x0, size.y, z)]
	var uvs := [Vector2(uv0.x, uv1.y), Vector2(uv1.x, uv1.y), Vector2(uv1.x, uv0.y), Vector2(uv0.x, uv0.y)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[k])
		st.add_vertex(corners[k])
	var leaf := MeshInstance3D.new()
	leaf.mesh = st.commit()
	leaf.material_override = mat
	return leaf


# --- Porte peinte sur le modèle ------------------------------------------------------------

func _build_from_model() -> void:
	var model := get_node_or_null(zone_path) as MeshInstance3D
	if model == null or model.mesh == null:
		push_error("PanelDoor %s : modèle introuvable (%s)" % [name, zone_path])
		return
	var mesh := model.mesh as ArrayMesh
	var to_world := model.global_transform
	var box := cut_box
	var surfaces: Array[int] = []
	for i in mesh.get_surface_count():
		if surface_name.is_empty() or mesh.surface_get_name(i) == surface_name:
			surfaces.append(i)
	if not surface_name.is_empty():
		# Boîte de la surface entière, un peu agrandie.
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surfaces[0])[Mesh.ARRAY_VERTEX]
		box = AABB(vertices[0], Vector3.ZERO)
		for v in vertices:
			box = box.expand(v)
		box = (to_world * box).grow(0.05)
	size = Vector2(box.size.x, box.size.y)
	global_position = Vector3(box.get_center().x, box.position.y, box.end.z)
	var origin := global_position
	for i in surfaces:
		var mat := model.get_surface_override_material(i) as ShaderMaterial
		var leaf := _cut(mesh, i, to_world, box, origin) if mat != null else null
		if leaf == null:
			continue
		var copy := mat.duplicate() as ShaderMaterial
		copy.set_shader_parameter("hide_count", 0)
		leaf.material_override = copy
		if _hinges.is_empty():
			var at := Vector3(-size.x / 2.0, 0, 0) if style == Style.SWING else Vector3.ZERO
			_add_hinge(leaf, at)
		else:
			# Plusieurs surfaces dans la boîte : un seul battant, plusieurs morceaux.
			leaf.position = -_hinges[0].position
			_hinges[0].add_child(leaf)
	# La porte du modèle est cachée pour de bon (son battant, identique, la remplace), et
	# avec elle ce qui se trouve derrière (mur, vitre) : la place du renfoncement sombre.
	var hidden := box
	hidden.position.z -= dark_depth
	hidden.size.z += dark_depth
	MapMaterials.hide_box(model, hidden)


## Triangles d'une surface compris dans la boîte, rognés à ses bords (UV et couleurs
## interpolées), placés par rapport au bas de la porte.
static func _cut(mesh: ArrayMesh, surface: int, to_world: Transform3D, box: AABB, origin: Vector3) -> MeshInstance3D:
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors = arrays[Mesh.ARRAY_COLOR]
	var has_colors: bool = colors is PackedColorArray and not (colors as PackedColorArray).is_empty()
	var indices = arrays[Mesh.ARRAY_INDEX]
	if not indices is PackedInt32Array or (indices as PackedInt32Array).is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for t in range(0, indices.size(), 3):
		var poly := []
		for k in 3:
			var index: int = indices[t + k]
			poly.append([to_world * vertices[index], uvs[index], colors[index] if has_colors else Color.WHITE])
		var bounds := AABB(poly[0][0], Vector3.ZERO).expand(poly[1][0]).expand(poly[2][0])
		if not bounds.intersects(box) and not box.encloses(bounds):
			continue
		for axis in 3:
			poly = _clip(poly, axis, box.position[axis], true)
			poly = _clip(poly, axis, box.end[axis], false)
		for k in range(1, poly.size() - 1):
			for p in [poly[0], poly[k], poly[k + 1]]:
				st.set_uv(p[1])
				st.set_color(p[2])
				st.add_vertex(p[0] - origin)
			count += 1
	if count == 0:
		return null
	var leaf := MeshInstance3D.new()
	leaf.mesh = st.commit()
	return leaf


## Rogne un polygone (points = [position, uv, couleur]) par le plan position[axis] = limit.
static func _clip(poly: Array, axis: int, limit: float, keep_above: bool) -> Array:
	var out := []
	for i in poly.size():
		var cur: Array = poly[i]
		var prev: Array = poly[i - 1]
		var cur_in: bool = cur[0][axis] >= limit if keep_above else cur[0][axis] <= limit
		var prev_in: bool = prev[0][axis] >= limit if keep_above else prev[0][axis] <= limit
		if cur_in != prev_in:
			var t: float = (limit - prev[0][axis]) / (cur[0][axis] - prev[0][axis])
			out.append([prev[0].lerp(cur[0], t), prev[1].lerp(cur[1], t), prev[2].lerp(cur[2], t)])
		if cur_in:
			out.append(cur)
	return out


## Renfoncement sombre derrière la porte : fond, côtés, plafond et sol, vus de l'intérieur.
func _recess() -> MeshInstance3D:
	var w := size.x / 2.0
	var h := size.y
	var d := -dark_depth
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(DARK)
	var quads := [
		[Vector3(-w, 0, d), Vector3(w, 0, d), Vector3(w, h, d), Vector3(-w, h, d)],
		[Vector3(-w, 0, 0), Vector3(-w, 0, d), Vector3(-w, h, d), Vector3(-w, h, 0)],
		[Vector3(w, 0, d), Vector3(w, 0, 0), Vector3(w, h, 0), Vector3(w, h, d)],
		[Vector3(-w, h, d), Vector3(w, h, d), Vector3(w, h, 0), Vector3(-w, h, 0)],
		[Vector3(-w, 0.2, 0), Vector3(w, 0.2, 0), Vector3(w, 0.2, d), Vector3(-w, 0.2, d)],
	]
	for q in quads:
		for k in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[k])
	var node := MeshInstance3D.new()
	node.name = "Recess"
	node.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = DARK
	node.material_override = mat
	node.position.z = -0.3
	return node
