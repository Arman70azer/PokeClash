class_name CharacterSprite
extends Node3D
## Sprite d'un personnage (joueur ou PNJ) avec son ombre au sol et son halo de vision.
## Les planches viennent de data/characters (voir CharacterSheet et SheetLoader).
## L'origine du nœud est le centre de la case où se tient le personnage.
## Le sprite est affiché pixel pour pixel par le shader pixel_sprite.

const SHADER := preload("res://shaders/pixel_sprite.gdshader")
const SHADOW_SHADER := preload("res://shaders/pixel_sprite_shadow.gdshader")
const XRAY_SHADER := preload("res://shaders/pixel_sprite_xray.gdshader")
const HALO_SHADER := preload("res://shaders/vision_halo.gdshader")
## Taille du halo de vision, en pixels, et hauteur de son centre au-dessus des pieds.
const HALO_SIZE := 52
const HALO_HEIGHT := 14.0
const IDLE_FRAME := 1

## Taille de l'ombre à l'écran, en pixels : un ovale aplati sous les pieds.
## Largeur impaire pour qu'elle dépasse autant des deux côtés du personnage.
const SHADOW_SIZE := Vector2i(17, 7)
## Hauteur du centre de l'ombre au-dessus du bas du sprite, en pixels. Les pieds de la
## pose de repos s'arrêtent à SheetLoader.FEET_MARGIN : à cette valeur, ils tombent au milieu de l'ovale.
const SHADOW_HEIGHT := 3.5
## Hauteur du sprite au-dessus du sol, en unités (4 unités ≈ 3 pixels à l'écran).
const SPRITE_LIFT := 4.0
## Décalage des pieds vers le bas de la case, en unités.
const FEET_OFFSET := 4.0

static var _shadow_texture: Texture2D

var _sheet_id := "ethan"
var _quad: QuadMesh
var _shadow_quad: QuadMesh
var _material: ShaderMaterial
var _xray_material: ShaderMaterial
var _halo_material: ShaderMaterial
var _halo_nodes: Array[MeshInstance3D] = []
var _halo := 0.0
var _pose_rect := Rect2()
var _pose_shift := 0


## À appeler une fois, avant ou après l'ajout à la scène.
func setup(sheet_id: String, tint: Color = Color.WHITE) -> void:
	_sheet_id = sheet_id if SheetLoader.exists(sheet_id) else SheetLoader.FALLBACK
	_quad = QuadMesh.new()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("sheet", SheetLoader.texture(_sheet_id))
	_material.set_shader_parameter("tint", tint)
	# Légèrement vers la caméra, pour ne pas se confondre avec le sol sous les pieds.
	_material.set_shader_parameter("depth_shift", 2.0)
	_quad.material = _material
	var sprite := MeshInstance3D.new()
	sprite.mesh = _quad
	# Le shader déplace les sommets : marge pour ne pas être masqué à tort hors champ.
	sprite.extra_cull_margin = 64.0
	sprite.position = Vector3(0.0, SPRITE_LIFT, FEET_OFFSET)
	add_child(sprite)
	add_child(_make_shadow())
	_make_halo(tint)
	set_pose(Vector2i.DOWN, IDLE_FRAME)


## Halo de vision : quand le décor cache entièrement le personnage, un disque lumineux
## et le personnage lui-même sont dessinés par-dessus le décor. `hidden` : caché ou
## non à cette image ; le halo apparaît et disparaît en fondu.
func update_vision_halo(hidden: bool, delta: float) -> void:
	var target := 1.0 if hidden else 0.0
	var smoothed := move_toward(_halo, target, delta * 6.0)
	if is_equal_approx(smoothed, _halo):
		return
	_halo = smoothed
	_xray_material.set_shader_parameter("amount", _halo)
	_halo_material.set_shader_parameter("amount", _halo)
	for node in _halo_nodes:
		node.visible = _halo > 0.0


## Pixels opaques de l'image affichée, un sur trois en largeur et en hauteur, en
## pixels par rapport aux pieds : (décalage horizontal, hauteur au-dessus des pieds).
## Sert à savoir si le personnage est entièrement caché (World.is_hidden_from_camera).
func vision_points() -> Array[Vector2]:
	return SheetLoader.vision_points(_sheet_id, _pose_rect, _pose_shift)


func _make_halo(tint: Color) -> void:
	# Le personnage, par-dessus le décor : même quadrilatère que le sprite normal.
	_xray_material = ShaderMaterial.new()
	_xray_material.shader = XRAY_SHADER
	_xray_material.set_shader_parameter("sheet", SheetLoader.texture(_sheet_id))
	_xray_material.set_shader_parameter("tint", tint)
	_xray_material.render_priority = 2
	var xray := MeshInstance3D.new()
	xray.mesh = _quad
	xray.material_override = _xray_material
	xray.extra_cull_margin = 64.0
	xray.position = Vector3(0.0, SPRITE_LIFT, FEET_OFFSET)
	# Le disque lumineux, derrière lui.
	var quad := QuadMesh.new()
	quad.size = Vector2(HALO_SIZE, HALO_SIZE)
	quad.center_offset = Vector3(0.0, HALO_HEIGHT, 0.0)
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = HALO_SHADER
	_halo_material.set_shader_parameter("size_px", float(HALO_SIZE))
	_halo_material.render_priority = 1
	quad.material = _halo_material
	var halo := MeshInstance3D.new()
	halo.mesh = quad
	halo.extra_cull_margin = 64.0
	halo.position = Vector3(0.0, SPRITE_LIFT, FEET_OFFSET)
	for node in [halo, xray]:
		node.visible = false
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_halo_nodes.append(node)


## Affiche l'image voulue : direction regardée et numéro d'image (0, 1 = repos, 2).
func set_pose(facing: Vector2i, frame: int) -> void:
	if _material == null:
		return
	var rect: Rect2 = SheetLoader.frames(_sheet_id)[facing][frame]
	# Rectangle en pixels, pieds à l'origine ; le shader le place à l'écran.
	_quad.size = rect.size
	# Descendu ou remonté pour que les pieds de la pose de repos soient au niveau standard.
	var shift := SheetLoader.feet_shift(_sheet_id, facing)
	_pose_rect = rect
	_pose_shift = shift
	if _shadow_quad != null:
		# L'ombre se centre sous les pieds de la direction regardée.
		_shadow_quad.center_offset = Vector3(SheetLoader.feet_center(_sheet_id, facing), SHADOW_HEIGHT, 0.0)
	_quad.center_offset = Vector3(0.0, rect.size.y / 2.0 - shift, 0.0)
	var sheet_size := Vector2(SheetLoader.texture(_sheet_id).get_size())
	var region := Vector4(rect.position.x / sheet_size.x, rect.position.y / sheet_size.y,
		rect.size.x / sheet_size.x, rect.size.y / sheet_size.y)
	_material.set_shader_parameter("region", region)
	if _xray_material != null:
		_xray_material.set_shader_parameter("region", region)


## Ombre ovale sous les pieds : sans elle, le personnage paraît s'enfoncer dans le sol.
## Elle est dessinée à l'écran avec le même ancrage que le sprite (et non posée au sol
## en perspective), sinon elle s'écarte des pieds selon la position à l'écran et le
## personnage semble flotter.
func _make_shadow() -> MeshInstance3D:
	if _shadow_texture == null:
		var img := Image.create(SHADOW_SIZE.x, SHADOW_SIZE.y, false, Image.FORMAT_RGBA8)
		var half := Vector2(SHADOW_SIZE) / 2.0
		for y in SHADOW_SIZE.y:
			for x in SHADOW_SIZE.x:
				var d := (Vector2(x + 0.5, y + 0.5) - half) / half
				if d.length_squared() <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.35))
		_shadow_texture = ImageTexture.create_from_image(img)
	var quad := QuadMesh.new()
	quad.size = Vector2(SHADOW_SIZE)
	# En pixels par rapport au bas du sprite ; set_pose la centre sous les pieds.
	quad.center_offset = Vector3(0.5, SHADOW_HEIGHT, 0.0)
	_shadow_quad = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADOW_SHADER
	mat.set_shader_parameter("sheet", _shadow_texture)
	mat.set_shader_parameter("depth_shift", 1.5)
	mat.set_shader_parameter("upright_depth", false)
	quad.material = mat
	var shadow := MeshInstance3D.new()
	shadow.mesh = quad
	shadow.extra_cull_margin = 64.0
	shadow.position = Vector3(0.0, SPRITE_LIFT, FEET_OFFSET)
	return shadow
