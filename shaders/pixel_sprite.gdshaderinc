// Partie commune aux sprites toujours face à l'écran (voir pixel_sprite.gdshader).

uniform sampler2D sheet : source_color, filter_nearest;
// Zone de la planche à afficher, en coordonnées UV : (x, y, largeur, hauteur).
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 tint : source_color = vec4(1.0);
// Faux : le sprite garde sa taille en pixels partout à l'écran (personnages).
// Vrai : il rétrécit avec la distance, comme le sol qui le porte (arbres, décors).
uniform bool perspective_scale = false;

// Deux sprites sur la même ligne de la carte ont la même profondeur ; ce léger décalage
// selon leur position horizontale fixe une fois pour toutes lequel passe devant l'autre.
const float TIE_BREAK = 0.002;
// Décalage de profondeur, en unités vers la caméra (négatif = juste derrière).
// Sert à glisser l'ombre d'un personnage sous lui sans changer sa place à l'écran.
uniform float depth_shift = 0.0;
// Vrai : chaque ligne du sprite prend la profondeur d'un personnage debout (la tête
// est plus proche de la caméra que les pieds), pour se glisser correctement devant
// et derrière le décor en relief. Faux : tout le sprite prend la profondeur de son
// point d'ancrage (ombre au sol).
uniform bool upright_depth = true;
// Fondu de niveau (voir map_zone.gdshaderinc) : le sprite entier s'efface en trame de
// pixels si son pied est dans la boîte fade_min..fade_max.
uniform vec3 fade_min = vec3(1.0e9);
uniform vec3 fade_max = vec3(-1.0e9);
uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;
varying float sprite_faded;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	bool inside = all(greaterThanEqual(origin, fade_min)) && all(lessThanEqual(origin, fade_max));
	sprite_faded = inside ? fade_amount : 0.0;
	vec4 anchor = PROJECTION_MATRIX * VIEW_MATRIX * vec4(origin, 1.0);
	// Hauteur, dans le monde, d'un objet debout qui occuperait VERTEX.y pixels à l'écran.
	float stand = upright_depth ? VERTEX.y / max(INV_VIEW_MATRIX[1].y, 0.2) : 0.0;
	vec4 sorted = PROJECTION_MATRIX * VIEW_MATRIX * vec4(origin.x, origin.y + stand, origin.z + origin.x * TIE_BREAK + depth_shift, 1.0);
	float scale = 1.0;
	if (perspective_scale) {
		// Distance à laquelle une unité du monde vaut exactement un pixel.
		float focus_distance = abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
		scale = focus_distance / anchor.w;
	}
	vec2 ndc = anchor.xy / anchor.w;
	vec2 px = floor((ndc * 0.5 + 0.5) * VIEWPORT_SIZE + 0.5);
	// Selon le moteur de rendu, l'axe vertical de l'écran pointe vers le haut ou vers le bas.
	vec2 offset = vec2(VERTEX.x, VERTEX.y * sign(PROJECTION_MATRIX[1][1])) * scale;
	ndc = (px + offset) / VIEWPORT_SIZE * 2.0 - 1.0;
	POSITION = vec4(ndc * anchor.w, sorted.z / sorted.w * anchor.w, anchor.w);
	UV = region.xy + UV * region.zw;
}

// Vrai si le pixel doit être effacé par le fondu de niveau.
bool sprite_fade_discard(vec2 frag) {
	if (sprite_faded <= 0.0) {
		return false;
	}
	const float bayer[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(mod(frag, 4.0));
	return (bayer[p.y * 4 + p.x] + 0.5) / 16.0 < sprite_faded;
}
