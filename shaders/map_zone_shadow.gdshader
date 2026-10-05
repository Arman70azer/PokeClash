shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Ombre portée semi-transparente peinte dans un modèle 3D de la carte.

#include "res://shaders/map_zone.gdshaderinc"

void fragment() {
	vec4 c = texture(albedo_tex, UV) * mix(vec4(1.0), COLOR, vertex_shading);
	if (faded(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = grade(c.rgb);
	ALPHA = c.a * opacity;
}
