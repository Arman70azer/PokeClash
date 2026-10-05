class_name PcTerminal
extends Interactable
## Un PC du monde : l'utiliser allume son écran, puis ouvre le PC de stockage (PcScreen)
## après un court message ; l'écran s'éteint quand on quitte le PC.
## Le terminal fait partie du décor (modèle de la carte) : ce nœud ne bloque pas sa case,
## il désigne seulement la case du PC, que le joueur regarde pour l'utiliser.
##
## Écran : dans le modèle, la surface `screen_surface` affiche une image d'une petite bande
## d'animation (éteint, en train de s'allumer, allumé), comme dans Noir et Blanc. On passe
## d'une image à l'autre en décalant sa texture (uniforme uv_offset des matériaux de carte).

## Zone (MapZone) qui contient le modèle du PC, et nom de la surface de l'écran.
@export var zone_path: NodePath
@export var screen_surface := ""
## Décalage horizontal de la texture pour chaque image de la bande : éteint, à moitié,
## allumé.
@export var screen_frames := PackedFloat32Array([0.0, 0.3125, 0.625])

const FRAME_TIME := 0.09

var _screen: ShaderMaterial
var _sequence: Tween


func _init() -> void:
	blocks_movement = false


func _ready() -> void:
	super._ready()
	var zone := get_node_or_null(zone_path) as MeshInstance3D
	if zone == null or zone.mesh == null or screen_surface.is_empty():
		return
	for i in zone.mesh.get_surface_count():
		if zone.mesh is ArrayMesh and (zone.mesh as ArrayMesh).surface_get_name(i) == screen_surface:
			_screen = zone.get_surface_override_material(i) as ShaderMaterial
	if _screen == null:
		push_warning("PcTerminal : surface « %s » introuvable" % screen_surface)


func dialogue_lines(_player: Player) -> PackedStringArray:
	if not lines.is_empty():
		return lines
	var player_name := Game.profiles.local_name if Game.profiles != null else ""
	return PackedStringArray(["%s allume le PC." % player_name])


## L'écran s'allume pendant le message.
func on_interact_started(_player: Player, _from: Vector2i) -> void:
	_play([1, 2, 1, 2])


func on_interact_finished(_player: Player) -> void:
	if Game.pc == null:
		_play([1, 0])
		return
	if not Game.pc.closed.is_connected(_on_pc_closed):
		Game.pc.closed.connect(_on_pc_closed, CONNECT_ONE_SHOT)
	Game.pc.open()


## Le PC se ferme : l'écran s'éteint, une fois l'écran du PC refermé.
func _on_pc_closed() -> void:
	_play([2, 1, 0], 0.5)


## Montre les images de la bande l'une après l'autre, après `delay` secondes.
func _play(frames: Array, delay := 0.0) -> void:
	if _screen == null:
		return
	if _sequence != null:
		_sequence.kill()
	_sequence = create_tween()
	if delay > 0.0:
		_sequence.tween_interval(delay)
	for frame: int in frames:
		_sequence.tween_callback(_show_frame.bind(frame))
		_sequence.tween_interval(FRAME_TIME)


func _show_frame(frame: int) -> void:
	_screen.set_shader_parameter("uv_offset", Vector2(screen_frames[clampi(frame, 0, screen_frames.size() - 1)], 0.0))
