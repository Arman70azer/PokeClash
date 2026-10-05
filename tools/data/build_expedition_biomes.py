"""Écrit les 7 zones d'expédition (data/expeditions/<id>.tres) : tuiles et décors du
tileset assets/tilesets/tileset_wide.png, type, dresseurs. Modifier ce script plutôt
que les fichiers, puis le relancer :
    python tools/data/build_expedition_biomes.py

Tuiles : (colonne, rangée) de cases de 16 × 16. Décors : zone en pixels du tileset
(mesurée sur l'image) et emprise en cases. Les tombes (GRAVES), absentes du tileset, sont
dessinées par tools/maps/build_graves.py dans leur propre image.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "data", "expeditions")

# Types (ordre de PokemonType.Type).
WATER, FIRE, GRASS, BUG, GROUND, ROCK, GHOST = 2, 1, 4, 11, 8, 12, 13

# Décors : zone (x, y, largeur, hauteur) en pixels, emprise (cases).
PROPS = {
    "tree_green": ((10, 16, 44, 48), (2, 2)),
    "tree_dark": ((74, 16, 44, 48), (2, 2)),
    "tree_round": ((12, 65, 40, 47), (2, 2)),
    "tree_bushy": ((72, 65, 48, 47), (2, 2)),
    "palm": ((9, 112, 46, 48), (2, 2)),
    "tree_snow": ((75, 113, 41, 47), (2, 2)),
    "tree_deep": ((14, 160, 37, 48), (2, 2)),
    "tree_olive": ((75, 160, 41, 48), (2, 2)),
    "tree_teal": ((14, 209, 36, 47), (2, 2)),
    "tree_yellow": ((80, 209, 32, 47), (2, 2)),
    "pine_snow": ((14, 259, 36, 45), (2, 2)),
    "tree_wide": ((72, 272, 47, 48), (2, 2)),
    "tree_red": ((8, 320, 47, 48), (2, 2)),
    "tree_mixed": ((8, 384, 47, 48), (2, 2)),
    "pine_green": ((70, 400, 52, 48), (2, 2)),
    "palm_dark": ((13, 448, 38, 48), (2, 2)),
    "pine_light": ((75, 464, 41, 48), (2, 2)),
    "tree_speckle": ((12, 512, 41, 48), (2, 2)),
    "rock_grey": ((1, 897, 31, 31), (2, 2)),
    "rock_small": ((32, 897, 16, 15), (1, 1)),
    "rock_brown": ((96, 945, 32, 31), (2, 2)),
    "rock_tiny": ((112, 977, 16, 15), (1, 1)),
    "bush_water": ((97, 996, 30, 28), (2, 2)),
    "mound_brown": ((1, 7136, 47, 48), (3, 2)),
    "boulder_grey": ((64, 7185, 15, 15), (1, 1)),
    "rock_olive": ((112, 7200, 16, 16), (1, 1)),
    "boulder_brown": ((112, 7217, 16, 15), (1, 1)),
    "boulder_speckle": ((113, 7233, 14, 14), (1, 1)),
    "cypress_dark": ((0, 7297, 16, 15), (1, 1)),
    "cypress_dark2": ((16, 7303, 16, 25), (1, 1)),
    "rock_stack_olive": ((97, 7296, 31, 32), (2, 1)),
    "mound_grey": ((1, 8768, 47, 48), (3, 2)),
    "mound_tan": ((1, 9184, 47, 48), (3, 2)),
    "mound_sand": ((1, 9280, 47, 48), (3, 2)),
    "mound_red": ((1, 9328, 47, 48), (3, 2)),
    "mound_snow": ((1, 9424, 47, 48), (3, 2)),
    "boulder_big": ((97, 9553, 31, 31), (2, 2)),
    "boulder_light": ((97, 9586, 14, 14), (1, 1)),
    "shrub_dark": ((80, 9633, 16, 15), (1, 1)),
    "shrub_dark_tall": ((96, 9639, 16, 25), (1, 1)),
    "stump_dead": ((80, 2899, 24, 45), (1, 1)),
    "pillar": ((130, 2816, 30, 64), (2, 1)),
    "pillar_broken": ((194, 2832, 30, 48), (2, 1)),
    "pillar_broken2": ((226, 2832, 30, 48), (2, 1)),
    "monument": ((80, 2850, 22, 30), (1, 1)),
    "statue": ((32, 2836, 30, 76), (2, 1)),
    "menhir": ((32, 2944, 24, 32), (2, 1)),
    "cypress": ((0, 9905, 16, 15), (1, 1)),
    "cypress2": ((16, 9911, 16, 25), (1, 1)),
    "small_tree": ((80, 10708, 17, 24), (1, 1)),
    "fern": ((64, 10641, 16, 13), (1, 1)),
    "grass_clump": ((112, 10743, 16, 25), (1, 1)),
    "bush_round": ((97, 9523, 30, 13), (2, 1)),
}

# Tombes : zone dans GRAVES_SHEET (voir LAYOUT dans tools/maps/build_graves.py), emprise.
GRAVES_SHEET = "res://assets/tilesets/graves.png"
GRAVES = {
    "grave_round": ((0, 4, 16, 20), (1, 1)),
    "grave_cross": ((16, 0, 16, 24), (1, 1)),
    "grave_double": ((32, 4, 28, 20), (2, 1)),
    "grave_broken": ((60, 8, 16, 16), (1, 1)),
}


# Décors en 3D : modèle (origine au milieu de l'emprise), emprise. Kit de la forêt écrit par
# tools/maps/build_forest_kit.py.
FOREST = "res://assets/maps/lostlorn_forest/"
MODELS = {
    "forest_tree_light": (FOREST + "forest_tree_light.obj", (2, 2)),
    "forest_tree_dark": (FOREST + "forest_tree_dark.obj", (2, 2)),
    "forest_stump": (FOREST + "forest_stump.obj", (3, 3)),
    "hollow_stump": ("res://assets/mapobjects/stump_2/stump_2.obj", (3, 3)),
    "fallen_log": ("res://assets/mapobjects/dead_tree_01/dead_tree_01.obj", (6, 2)),
    "leaning_log": ("res://assets/mapobjects/dead_tree_02/dead_tree_02.obj", (6, 2)),
}


# Falaises : hauteur, texture du dessus, bandes de la paroi de bas en haut (texture,
# hauteur). Celles du désert viennent de Desert Resort (Noir 2 / Blanc 2).
DESERT = "res://assets/maps/desert_resort/"
DESERT_TEX = DESERT + "Desert Resort Area 2_texture_%s.png"
CLIFFS = {
    # Corniche basse (gake) : bord des passages.
    "desert_low": (16, DESERT_TEX % "0009", [(DESERT_TEX % "0003", 12), (DESERT_TEX % "0066", 4)]),
    # Grand plateau (ga_s) : au-delà.
    "desert_high": (48, DESERT_TEX % "0002", [(DESERT_TEX % "0005", 16), (DESERT_TEX % "0006", 28),
                                              (DESERT_TEX % "0007", 4)]),
}


def prop(name, weight=1.0, walls=True, scatter=True):
    return (name, weight, walls, scatter)


BIOMES = [
    {
        "id": "foret", "name": "Forêt", "type": BUG,
        "description": "Une forêt touffue où grouillent les Pokémon Insecte.", "step_effect": "grass",
        # Sol et herbes de Lostlorn Forest (planche forest_ground.png, voir build_forest_kit.py).
        "sheet": FOREST + "forest_ground.png", "ground": (0, 0), "pattern": (4, 4), "variants": [],
        "path": None, "encounter": (0, 0), "encounter_mesh": FOREST + "forest_tall_grass.obj",
        "decor": [(4, 0), (4, 1), (4, 2), (4, 3)], "decor_density": 0.08,
        "props": [prop("forest_tree_light", 3), prop("forest_tree_dark", 2),
                  prop("forest_stump", 1, walls=False), prop("hollow_stump", 1, walls=False),
                  prop("fallen_log", 1, walls=False), prop("leaning_log", 1, walls=False)],
        "trainers": [("Chasseur d'insectes", "chasseur_insectes", (0, 9)), ("Scout", "gamin", (4, 3)),
                     ("Pique-niqueuse", "fillette", (1, 9))],
    },
    {
        "id": "jungle", "name": "Jungle", "type": GRASS,
        "description": "Une jungle humide, royaume des Pokémon Plante.",
        "ground": (4, 214), "variants": [], "path": (7, 277), "encounter": (3, 664),
        "liquid": (1, 440), "pools": 0.06,
        "decor": [(3, 670), (3, 672), (4, 672)], "decor_density": 0.06,
        "props": [prop("palm", 3), prop("palm_dark", 3), prop("tree_bushy", 2), prop("tree_speckle", 2),
                  prop("tree_teal", 1), prop("fern", 1), prop("grass_clump", 2), prop("bush_round", 1)],
        "trainers": [("Jardinière", "fleuriste", (1, 7)), ("Ranger", "ouvrier", (4, 3)),
                     ("Ninja", "ecolier", (2, 7))],
    },
    {
        "id": "aquatique", "name": "Lagune", "type": WATER,
        "description": "Une lagune semée d'îlots, idéale pour les Pokémon Eau.",
        "ground": (4, 211), "variants": [(0, 277)], "variant_density": 0.05, "path": None, "encounter": (3, 669),
        "liquid": (1, 440), "pools": 0.12, "liquid_border": 0.75,
        "decor": [], "decor_density": 0.0,
        "props": [prop("palm", 4), prop("rock_grey", 2), prop("rock_brown", 1), prop("bush_water", 1),
                  prop("rock_small", 1), prop("rock_tiny", 1)],
        "trainers": [("Pêcheur", "marin", (1, 2)), ("Nageur", "gamin", (3, 9)), ("Marin", "marin", (4, 2))],
    },
    {
        "id": "volcan", "name": "Volcan", "type": FIRE,
        "description": "Les flancs d'un volcan, où vivent les Pokémon Feu.",
        "ground": (2, 279), "variants": [(3, 280)], "path": (1, 226), "encounter": (7, 278),
        "liquid": (12, 223), "pools": 0.07, "liquid_border": 0.35,
        "decor": [], "decor_density": 0.0,
        "props": [prop("mound_red", 3), prop("mound_brown", 2), prop("rock_brown", 2), prop("boulder_brown", 2),
                  prop("stump_dead", 1), prop("tree_red", 1), prop("rock_tiny", 1)],
        "trainers": [("Cracheur de feu", "chef", (5, 8)), ("Motard", "ouvrier", (5, 9)),
                     ("Karatéka", "ouvrier", (1, 5))],
    },
    {
        "id": "desert", "name": "Désert", "type": GROUND,
        "description": "Des dunes brûlantes, terrain des Pokémon Sol.",
        # Sable et falaises de Desert Resort (planche desert_ground.png, voir build_desert_kit.py).
        "sheet": DESERT + "desert_ground.png", "ground": (0, 0), "variants": [(1, 0)], "variant_density": 0.1,
        "path": None, "encounter": (2, 0), "step_effect": "sand",
        "cliffs": ["desert_low", "desert_high"],
        "decor": [], "decor_density": 0.0,
        "props": [prop("boulder_big", 2, walls=False), prop("rock_olive", 1, walls=False),
                  prop("rock_stack_olive", 1, walls=False), prop("stump_dead", 1, walls=False),
                  prop("boulder_light", 1, walls=False)],
        "trainers": [("Ruinomane", "collectionneur", (1, 6)), ("Montagnard", "ouvrier", (1, 0)),
                     ("Fermier", "rentier", (6, 0))],
    },
    {
        "id": "montagne", "name": "Montagne", "type": ROCK,
        "description": "Des pentes rocailleuses peuplées de Pokémon Roche.",
        "ground": (4, 437), "variants": [], "path": (2, 277), "encounter": (1, 575),
        "decor": [], "decor_density": 0.0,
        "props": [prop("mound_grey", 3), prop("mound_snow", 1), prop("boulder_big", 2),
                  prop("boulder_grey", 2), prop("boulder_speckle", 1), prop("pine_snow", 2), prop("tree_snow", 1),
                  prop("cypress_dark2", 1)],
        "trainers": [("Montagnard", "ouvrier", (1, 0)), ("Skieuse", "lyceenne", (4, 11)),
                     ("Karatéka", "gamin", (1, 5))],
    },
    {
        "id": "cimetiere", "name": "Cimetière", "type": GHOST,
        "description": "Un vieux cimetière en ruine, hanté par les Pokémon Spectre.",
        "ground": (1, 217), "variants": [(7, 277)], "path": (4, 277), "encounter": (2, 664),
        "decor": [], "decor_density": 0.0,
        "props": [prop("grave_round", 4), prop("grave_cross", 3), prop("grave_double", 2), prop("grave_broken", 2),
                  prop("cypress2", 3), prop("cypress", 2), prop("shrub_dark_tall", 1), prop("tree_teal", 1),
                  prop("stump_dead", 1), prop("pillar", 1), prop("pillar_broken", 1), prop("pillar_broken2", 1),
                  prop("monument", 1), prop("menhir", 1), prop("statue", 1, walls=False)],
        "trainers": [("Médium", "grand_mere", (6, 7)), ("Sage", "grand_pere", (6, 3)),
                     ("Mystimaniac", "collectionneur", (4, 4))],
    },
]

FRONT_SHEET = "res://assets/Trainers - Trainers (Front).png"


def v(t):
    return "Vector2i(%d, %d)" % t if t else "Vector2i(-1, -1)"


def write(biome):
    lines = ['[gd_resource type="Resource" script_class="ExpeditionBiome" format=3]', "",
             '[ext_resource type="Script" path="res://expedition/expedition_biome.gd" id="biome"]',
             '[ext_resource type="Script" path="res://expedition/expedition_prop.gd" id="prop"]']
    if any(name in GRAVES for name, _, _, _ in biome["props"]):
        lines.append('[ext_resource type="Texture2D" path="%s" id="graves"]' % GRAVES_SHEET)
    for name, _, _, _ in biome["props"]:
        if name in MODELS:
            lines.append('[ext_resource type="ArrayMesh" path="%s" id="m_%s"]' % (MODELS[name][0], name))
    if biome.get("sheet"):
        lines.append('[ext_resource type="Texture2D" path="%s" id="sheet"]' % biome["sheet"])
    if biome.get("encounter_mesh"):
        lines.append('[ext_resource type="ArrayMesh" path="%s" id="encounter_mesh"]' % biome["encounter_mesh"])
    cliff_textures = []
    for name in biome.get("cliffs", []):
        height, top, bands = CLIFFS[name]
        for path in [top] + [b[0] for b in bands]:
            if path not in cliff_textures:
                cliff_textures.append(path)
    if cliff_textures:
        lines.append('[ext_resource type="Script" path="res://expedition/cliff_style.gd" id="cliff"]')
    for i, path in enumerate(cliff_textures):
        lines.append('[ext_resource type="Texture2D" path="%s" id="c%d"]' % (path, i))
    lines.append("")
    for name in biome.get("cliffs", []):
        height, top, bands = CLIFFS[name]
        lines += ['[sub_resource type="Resource" id="%s"]' % name, 'script = ExtResource("cliff")',
                  "height = %g" % height, 'top = ExtResource("c%d")' % cliff_textures.index(top),
                  'bands = Array[Texture2D]([%s])' % ", ".join('ExtResource("c%d")' % cliff_textures.index(b[0]) for b in bands),
                  "band_heights = PackedFloat32Array(%s)" % ", ".join("%g" % b[1] for b in bands), ""]
    for i, (name, weight, walls, scatter) in enumerate(biome["props"]):
        if name in MODELS:
            region, footprint = (0, 0, 0, 0), MODELS[name][1]
        else:
            region, footprint = GRAVES[name] if name in GRAVES else PROPS[name]
        lines += ['[sub_resource type="Resource" id="p%d"]' % i, 'script = ExtResource("prop")',
                  "region = Rect2i(%d, %d, %d, %d)" % region, "footprint = Vector2i(%d, %d)" % footprint,
                  "weight = %g" % weight]
        if name in GRAVES:
            lines.append('sheet = ExtResource("graves")')
        if name in MODELS:
            lines.append('mesh = ExtResource("m_%s")' % name)
        if not walls:
            lines.append("walls = false")
        if not scatter:
            lines.append("scatter = false")
        lines.append("")
    trainers = ", ".join('{"front": Vector2i(%d, %d), "sheet": "%s", "title": "%s"}' % (f[0], f[1], s, t.replace('"', '\\"'))
                         for t, s, f in biome["trainers"])
    lines += ["[resource]", 'script = ExtResource("biome")', 'id = &"%s"' % biome["id"], 'name = "%s"' % biome["name"],
              "type = %d" % biome["type"], 'description = "%s"' % biome["description"],
              "ground = %s" % v(biome["ground"]),
              "ground_pattern = %s" % v(biome.get("pattern", (1, 1))),
              "ground_variants = Array[Vector2i]([%s])" % ", ".join(v(t) for t in biome["variants"]),
              "variant_density = %g" % biome.get("variant_density", 0.08),
              "path = %s" % v(biome.get("path")), "encounter = %s" % v(biome["encounter"]),
              "liquid = %s" % v(biome.get("liquid")), "pools = %g" % biome.get("pools", 0.0),
              "liquid_border = %g" % biome.get("liquid_border", 0.0),
              "decor = Array[Vector2i]([%s])" % ", ".join(v(t) for t in biome["decor"]),
              "decor_density = %g" % biome["decor_density"],
              'props = Array[ExtResource("prop")]([%s])' % ", ".join('SubResource("p%d")' % i for i in range(len(biome["props"]))),
              "trainers = Array[Dictionary]([%s])" % trainers]
    if biome.get("sheet"):
        lines.append('sheet = ExtResource("sheet")')
    if biome.get("encounter_mesh"):
        lines.append('encounter_mesh = ExtResource("encounter_mesh")')
    if biome.get("step_effect"):
        lines.append('step_effect = &"%s"' % biome["step_effect"])
    if biome.get("cliffs"):
        lines.append('cliffs = Array[ExtResource("cliff")]([%s])' % ", ".join('SubResource("%s")' % n for n in biome["cliffs"]))
    with open(os.path.join(OUT, biome["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for b in BIOMES:
        write(b)
    print("%d zones écrites dans data/expeditions" % len(BIOMES))
