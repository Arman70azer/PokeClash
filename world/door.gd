class_name Door
extends Node3D
## Porte automatique d'un bâtiment de la carte (Centre Pokémon...). Sa façade est
## arrondie, comme dans les jeux : la porte est un morceau de cercle. Pour l'ouvrir, on
## cache la porte du modèle et on la remplace par ses deux moitiés, qui glissent chacune
## de leur côté en suivant la courbe de la façade, jusqu'à disparaître dans les murs.

## Zone (MapZone) qui contient la porte, et nom de la surface de la porte dans son modèle.
@export var zone_path: NodePath
@export var surface_name := ""
## Angle (degrés) dont chaque battant tourne autour du centre de la façade en s'ouvrant.
@export var open_angle := 80.0

const OPEN_TIME := 0.35
## Les battants passent juste derrière la façade, pour ne pas la traverser.
const INSET := 0.95

var _zone: MeshInstance3D
var _surface := -1
## Les deux battants : pivots placés au centre du cercle de la façade.
var _pivots: Array[Node3D] = []


func _ready() -> void:
	_zone = get_node_or_null(zone_path) as MeshInstance3D
	if _zone == null or _zone.mesh == null:
		push_error("Door : zone introuvable (%s)" % zone_path)
		return
	for i in _zone.mesh.get_surface_count():
		if (_zone.mesh as ArrayMesh).surface_get_name(i) == surface_name:
			_surface = i
	if _surface == -1:
		push_error("Door : surface « %s » absente du modèle" % surface_name)
		return
	_build_leaves.call_deferred()


## Ouvre la porte : les battants glissent le long de la façade.
func open() -> void:
	if _pivots.is_empty():
		return
	_show_original(false)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in 2:
		_pivots[i].visible = true
		_pivots[i].rotation.y = 0.0
		tween.tween_property(_pivots[i], "rotation:y", _open_rotation(i), OPEN_TIME)
	await tween.finished


## Referme la porte puis rend sa surface au modèle.
func close() -> void:
	if _pivots.is_empty():
		return
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in 2:
		tween.tween_property(_pivots[i], "rotation:y", 0.0, OPEN_TIME)
	await tween.finished
	for pivot in _pivots:
		pivot.visible = false
	_show_original(true)


## La porte ouverte d'un coup (un joueur sort du bâtiment), à refermer avec close().
func set_open() -> void:
	if _pivots.is_empty():
		return
	_show_original(false)
	for i in 2:
		_pivots[i].visible = true
		_pivots[i].rotation.y = _open_rotation(i)


## Le battant gauche (0) tourne vers la gauche, le droit (1) vers la droite.
func _open_rotation(i: int) -> float:
	return deg_to_rad(-open_angle if i == 0 else open_angle)


## Découpe la porte du modèle en deux battants (gauche, droite), chacun accroché à un
## pivot au centre du cercle de la façade.
func _build_leaves() -> void:
	var arrays := _zone.mesh.surface_get_arrays(_surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors = arrays[Mesh.ARRAY_COLOR]
	var indices = arrays[Mesh.ARRAY_INDEX]
	if not indices is PackedInt32Array or (indices as PackedInt32Array).is_empty():
		indices = PackedInt32Array(range(vertices.size()))
	var center := _circle_center(vertices)
	var halves := [[], []]
	for t in range(0, indices.size(), 3):
		var centroid := (vertices[indices[t]] + vertices[indices[t + 1]] + vertices[indices[t + 2]]) / 3.0
		halves[0 if centroid.x < center.x else 1].append(t)
	var source := _zone.get_surface_override_material(_surface) as ShaderMaterial
	for side in 2:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for t in halves[side]:
			for k in 3:
				var index: int = indices[t + k]
				if colors is PackedColorArray and not (colors as PackedColorArray).is_empty():
					st.set_color(colors[index])
				st.set_uv(uvs[index])
				var p := vertices[index] - center
				st.add_vertex(Vector3(p.x * INSET, p.y, p.z * INSET))
		var leaf := MeshInstance3D.new()
		leaf.mesh = st.commit()
		if source != null:
			var mat := source.duplicate() as ShaderMaterial
			mat.set_shader_parameter("fade_amount", 0.0)
			leaf.material_override = mat
		var pivot := Node3D.new()
		pivot.position = _zone.global_transform * center
		pivot.visible = false
		pivot.add_child(leaf)
		add_child(pivot)
		_pivots.append(pivot)


## Centre du cercle de la façade (dans le repère du modèle), au niveau du sol de la
## porte : trouvé à partir du point le plus en avant et du point le plus sur le côté.
func _circle_center(vertices: PackedVector3Array) -> Vector3:
	var front := vertices[0]
	var side := vertices[0]
	var low := vertices[0].y
	for v in vertices:
		if v.z > front.z:
			front = v
		if v.x < side.x:
			side = v
		low = minf(low, v.y)
	# Centre (front.x, cz) à égale distance de `front` et de `side`.
	var dx := side.x - front.x
	var cz := (front.z * front.z - side.z * side.z - dx * dx) / (2.0 * (front.z - side.z))
	return Vector3(front.x, low, cz)


## Cache ou montre la porte dans le modèle (effacement complet par le shader de la carte).
func _show_original(shown: bool) -> void:
	var mat := _zone.get_surface_override_material(_surface) as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("fade_min", Vector3(-1e9, -1e9, -1e9) if not shown else Vector3(1e9, 1e9, 1e9))
	mat.set_shader_parameter("fade_max", Vector3(1e9, 1e9, 1e9) if not shown else Vector3(-1e9, -1e9, -1e9))
	mat.set_shader_parameter("fade_amount", 1.0 if not shown else 0.0)
