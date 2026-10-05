shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Ombre semi-transparente d'un personnage, placée à l'écran exactement comme lui
// (même ancrage, même grille de pixels) pour rester collée à ses pieds partout.

#include "res://shaders/pixel_sprite.gdshaderinc"

void fragment() {
	vec4 c = texture(sheet, UV);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
}
