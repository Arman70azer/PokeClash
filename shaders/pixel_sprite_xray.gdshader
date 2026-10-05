shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;
// Personnage dessiné par-dessus le décor quand celui-ci le cache entièrement (halo de
// vision) : même placement que pixel_sprite.gdshader, sans test de profondeur.

#include "res://shaders/pixel_sprite.gdshaderinc"

// 0 = invisible, 1 = entièrement affiché.
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(sheet, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = amount;
}
