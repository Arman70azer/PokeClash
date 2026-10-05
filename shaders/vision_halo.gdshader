shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never;
// Halo de vision : lueur douce dessinée par-dessus le décor autour d'un
// personnage entièrement caché, pour qu'on le retrouve à travers les bâtiments. Placé
// à l'écran comme les sprites (pixel_sprite.gdshaderinc), en gros pixels nets.

#include "res://shaders/pixel_sprite.gdshaderinc"

// 0 = invisible, 1 = entièrement affiché.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// Taille du halo, en pixels de l'écran du jeu.
uniform float size_px = 52.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.97, 0.82, 1.0);
// Opacité au centre du halo ; elle décroît en douceur jusqu'au bord.
uniform float center_alpha = 0.65;

void fragment() {
	// Distance au centre, calculée au centre de chaque pixel pour rester net.
	vec2 q = (floor(UV * size_px) + 0.5) / size_px - 0.5;
	float r = length(q) * 2.0;
	if (r > 1.0) {
		discard;
	}
	// Lueur fondue : forte au centre, nulle au bord, sans cercle marqué.
	float glow = 1.0 - smoothstep(0.0, 1.0, r);
	ALBEDO = glow_color.rgb;
	ALPHA = center_alpha * glow * glow * amount;
}
