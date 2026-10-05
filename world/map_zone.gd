class_name MapZone
extends MeshInstance3D
## Zone entière de la carte : un seul grand modèle 3D (assets/maps) qui contient le
## sol, le relief, les bâtiments et le décor.
## Échelle : 16 unités = 1 case ; X vers la droite, Z vers le bas de la carte, Y vers le haut.
## Le modèle n'a pas de collisions : elles viennent de la grille `grid`, calculée à
## partir du modèle par tools/maps/bake_map_grid.gd.
##
## Fondu de niveau : quand le joueur local descend sous `fade_level` à l'intérieur de
## `fade_cells` (une place en contrebas et son escalier, par exemple), la géométrie
## comprise dans `fade_box` (le muret qui masquerait la vue) s'efface progressivement,
## et réapparaît quand il remonte.

## Hauteur du sol et passages possibles, case par case.
@export var walk_grid: MapGrid

@export_group("Couleurs")
## Retouche des couleurs du modèle, pour l'accorder au reste de la carte (1 = inchangé).
@export var saturation := 1.0
@export var contrast := 1.0
@export var brightness := 1.0
## Part de l'ombrage peint dans les couleurs de sommets (1 = tel quel, 0 = ignoré).
@export_range(0.0, 1.0) var vertex_shading := 1.0
## Opacité des ombres portées peintes (« kage ») ; -1 = celle du modèle. Certains modèles
## ont des ombres opaques : 0,3 les accorde à celles des villes.
@export var shadow_opacity := -1.0

@export_group("Fondu de niveau")
## Cases où le fondu peut se déclencher. Vide : pas de fondu.
@export var fade_cells := Rect2i()
## Boîte, en unités du monde, de la géométrie à effacer.
@export var fade_box := AABB()
## Hauteur du niveau supérieur : le fondu commence quand le joueur descend dessous.
@export var fade_level := 0.0
## Descente nécessaire pour que le fondu soit complet, en unités.
@export var fade_depth := 40.0

var _fade := 0.0


func _ready() -> void:
	MapMaterials.apply(self)
	add_to_group("fade_receivers")
	for i in get_surface_override_material_count():
		var mat := get_surface_override_material(i) as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("saturation", saturation)
			mat.set_shader_parameter("contrast", contrast)
			mat.set_shader_parameter("brightness", brightness)
			mat.set_shader_parameter("vertex_shading", vertex_shading)
			if shadow_opacity >= 0.0 and mat.shader == MapMaterials.SHADOW_SHADER:
				mat.set_shader_parameter("opacity", shadow_opacity)
	MapMaterials.add_vision_collider(self)


## Grille de déplacement de la zone.
func grid() -> MapGrid:
	return walk_grid


## Met à jour le fondu d'après la position du joueur local (has_player faux : aucun joueur).
func update_fade(player_cell: Vector2i, player_height: float, has_player: bool, delta: float) -> void:
	if fade_cells.size == Vector2i.ZERO:
		return
	var target := 0.0
	if has_player and fade_cells.has_point(player_cell):
		# Commence un peu sous le niveau supérieur, pour ne pas s'effacer au moindre pas.
		target = clampf((fade_level - player_height - 6.0) / fade_depth, 0.0, 1.0)
	var smoothed := move_toward(_fade, target, delta * 4.0)
	if is_equal_approx(smoothed, _fade):
		return
	_fade = smoothed
	# Tout ce qui se trouve dans la boîte s'efface, y compris les zones et objets voisins.
	for node in get_tree().get_nodes_in_group("fade_receivers"):
		MapMaterials.set_fade(node, fade_box, _fade)
