shader_type spatial;
render_mode unshaded, cull_disabled;
// Sprite toujours face à l'écran dans la scène 3D. Par défaut il est affiché pixel pour
// pixel : un pixel de la planche = un pixel de l'écran du jeu, sans déformation. Le sprite est ancré sur l'origine
// du nœud (les pieds), calée sur la grille de pixels, et prend la profondeur de ce point :
// il passe devant ce qui est derrière ses pieds et derrière ce qui est devant.
// Le maillage est un rectangle en pixels : x de -largeur/2 à +largeur/2, y de 0 à hauteur.

#include "res://shaders/pixel_sprite.gdshaderinc"

void fragment() {
	vec4 c = texture(sheet, UV);
	if (c.a < 0.5 || sprite_fade_discard(FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = c.rgb * tint.rgb;
}
