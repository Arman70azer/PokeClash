class_name CameraRig
extends Camera3D
## Caméra du monde : inclinée et en perspective, elle suit sa cible relief compris, la
## cible restant au centre de l'écran. Ses réglages viennent d'un CameraProfile.

const DEFAULT_PROFILE := preload("res://data/config/camera/overworld.tres")

var profile: CameraProfile


func _init(p_profile: CameraProfile = null) -> void:
	apply_profile(p_profile if p_profile != null else DEFAULT_PROFILE)


func apply_profile(p_profile: CameraProfile) -> void:
	profile = p_profile
	fov = profile.fov
	near = profile.near
	far = profile.far
	rotation_degrees.x = -profile.pitch


## Place la caméra pour viser un point.
func focus(target: Vector3) -> void:
	var pitch := deg_to_rad(profile.pitch)
	position = target + Vector3(0.0, profile.target_lift, 0.0) + Vector3(0.0, sin(pitch), cos(pitch)) * profile.distance()


## Vrai si le décor (zones et objets 3D) cache entièrement un personnage dont les pieds
## sont en `feet` : un rayon part de la caméra vers chaque point opaque de son sprite
## (`points`, en pixels par rapport aux pieds), et tous doivent heurter le décor avant
## de l'atteindre. S'il en reste un seul de visible, on distingue encore le personnage :
## pas de halo. Les rayons ne touchent que MapMaterials.VISION_LAYER.
func is_hiding(feet: Vector3, points: Array[Vector2]) -> bool:
	if points.is_empty():
		return false
	var space := get_world_3d().direct_space_state
	var eye := global_position
	# Point d'ancrage du sprite (voir CharacterSprite) ; une ligne du sprite située s pixels
	# au-dessus de ses pieds a la profondeur d'un point debout à s / cos(inclinaison).
	var anchor := feet + Vector3(0.0, CharacterSprite.SPRITE_LIFT, CharacterSprite.FEET_OFFSET)
	var rise := 1.0 / cos(deg_to_rad(profile.pitch))
	for point in points:
		var target := anchor + Vector3(point.x, point.y * rise, 0.0)
		var query := PhysicsRayQueryParameters3D.create(eye, target, MapMaterials.VISION_LAYER)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or eye.distance_to(hit["position"]) > eye.distance_to(target) - 1.0:
			return false
	return true
