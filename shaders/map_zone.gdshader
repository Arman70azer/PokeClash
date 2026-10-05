shader_type spatial;
render_mode unshaded, cull_disabled;
// Surface opaque d'un modèle 3D de la carte (sol, murs, toits, arbres).

#include "res://shaders/map_zone.gdshaderinc"

void fragment() {
	vec4 c = texture(albedo_tex, UV) * mix(vec4(1.0), COLOR, vertex_shading);
	if (c.a < 0.5 || faded(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = grade(c.rgb);
}
