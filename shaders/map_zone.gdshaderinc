// Partie commune aux matériaux des modèles 3D de la carte (zones et objets).
// Rendu façon DS : pas d'éclairage, texture nette, multipliée par les couleurs de
// sommets du modèle (ombrage peint).
//
// Fondu de niveau : la géométrie comprise dans la boîte fade_min..fade_max (repère du
// monde) disparaît selon fade_amount (0 = visible, 1 = effacée), par une trame de
// pixels, pour dégager la vue quand un personnage descend sous un niveau.

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
// Opacité du matériau d'origine (réglage « d » du .mtl), utilisée par les ombres
// dont la texture est opaque.
uniform float opacity = 1.0;
uniform vec3 fade_min = vec3(1.0e9);
uniform vec3 fade_max = vec3(-1.0e9);
uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;
// Boîtes (repère du monde) où la géométrie est cachée net : une porte peinte sur une
// façade et ce qui se trouve juste derrière, remplacés par le battant animé et un
// renfoncement sombre (voir PanelDoor). Une boîte par porte du modèle.
const int MAX_HIDDEN = 8;
uniform int hide_count = 0;
uniform vec3 hide_min[MAX_HIDDEN];
uniform vec3 hide_max[MAX_HIDDEN];
// Défilement de la texture, en répétitions par seconde (eau qui coule d'une fontaine).
uniform vec2 uv_scroll = vec2(0.0);
// Décalage fixe de la texture : choisit une image d'une bande d'animation (écran du PC).
uniform vec2 uv_offset = vec2(0.0);
// Retouche des couleurs d'une zone (voir MapZone) : saturation, contraste, luminosité.
uniform float saturation = 1.0;
uniform float contrast = 1.0;
uniform float brightness = 1.0;
// Part de l'ombrage peint dans les couleurs de sommets (1 = tel quel, 0 = ignoré) : les
// intérieurs l'ont très marqué, les villes pas du tout.
uniform float vertex_shading = 1.0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV += uv_scroll * TIME + uv_offset;
}

vec3 grade(vec3 c) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	return clamp(c * brightness, 0.0, 1.0);
}

// Vrai si le pixel doit être effacé : caché par une porte, ou par le fondu de niveau.
bool faded(vec2 frag) {
	for (int i = 0; i < hide_count; i++) {
		if (all(greaterThanEqual(world_pos, hide_min[i])) && all(lessThanEqual(world_pos, hide_max[i]))) {
			return true;
		}
	}
	if (fade_amount <= 0.0 || any(lessThan(world_pos, fade_min)) || any(greaterThan(world_pos, fade_max))) {
		return false;
	}
	// Trame de Bayer 4x4 : chaque pixel s'efface à son tour quand fade_amount augmente.
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(mod(frag, 4.0));
	return (bayer[p.y * 4 + p.x] + 0.5) / 16.0 < fade_amount;
}
