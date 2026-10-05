"""Écrit les 7 zones d'expédition (data/expeditions/<id>.tres) : tuiles et décors du
tileset assets/tilesets/tileset_wide.png, type, dresseurs. Modifier ce script plutôt
que les fichiers, puis le relancer :
    python tools/data/build_expedition_biomes.py

Tuiles : (colonne, rangée) de cases de 16 × 16. Décors : zone en pixels du tileset
(mesurée sur l'image) et emprise en cases.
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


def prop(name, weight=1.0, walls=True, scatter=True):
    return (name, weight, walls, scatter)


BIOMES = [
    {
        "id": "foret", "name": "Forêt", "type": BUG,
        "description": "Une forêt touffue où grouillent les Pokémon Insecte.",
        "ground": (1, 211), "variants": [(1, 664), (0, 664)], "path": (1, 241), "encounter": (3, 669),
        "decor": [(0, 669), (1, 669), (3, 670), (1, 672)], "decor_density": 0.05,
        "props": [prop("tree_green", 3), prop("tree_dark", 3), prop("tree_round", 2), prop("tree_deep", 2),
                  prop("pine_green", 2), prop("pine_light", 2), prop("tree_olive", 1),
                  prop("small_tree", 1), prop("bush_round", 1), prop("grass_clump", 1, walls=False)],
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
        "ground": (4, 440), "variants": [(0, 277)], "path": (0, 283), "encounter": (7, 278),
        "decor": [], "decor_density": 0.0,
        "props": [prop("mound_sand", 3), prop("mound_tan", 2), prop("boulder_big", 2), prop("rock_olive", 1),
                  prop("rock_stack_olive", 1), prop("stump_dead", 1), prop("palm", 1), prop("boulder_light", 1)],
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
        "props": [prop("cypress2", 3), prop("cypress", 2), prop("shrub_dark_tall", 2), prop("tree_teal", 2),
                  prop("stump_dead", 2), prop("pillar", 1), prop("pillar_broken", 2), prop("pillar_broken2", 2),
                  prop("monument", 2), prop("menhir", 1), prop("statue", 1, walls=False)],
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
             '[ext_resource type="Script" path="res://expedition/expedition_prop.gd" id="prop"]', ""]
    for i, (name, weight, walls, scatter) in enumerate(biome["props"]):
        region, footprint = PROPS[name]
        lines += ['[sub_resource type="Resource" id="p%d"]' % i, 'script = ExtResource("prop")',
                  "region = Rect2i(%d, %d, %d, %d)" % region, "footprint = Vector2i(%d, %d)" % footprint,
                  "weight = %g" % weight]
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
              "ground_variants = Array[Vector2i]([%s])" % ", ".join(v(t) for t in biome["variants"]),
              "variant_density = %g" % biome.get("variant_density", 0.08),
              "path = %s" % v(biome.get("path")), "encounter = %s" % v(biome["encounter"]),
              "liquid = %s" % v(biome.get("liquid")), "pools = %g" % biome.get("pools", 0.0),
              "liquid_border = %g" % biome.get("liquid_border", 0.0),
              "decor = Array[Vector2i]([%s])" % ", ".join(v(t) for t in biome["decor"]),
              "decor_density = %g" % biome["decor_density"],
              'props = Array[ExtResource("prop")]([%s])' % ", ".join('SubResource("p%d")' % i for i in range(len(biome["props"]))),
              "trainers = Array[Dictionary]([%s])" % trainers]
    with open(os.path.join(OUT, biome["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for b in BIOMES:
        write(b)
    print("%d zones écrites dans data/expeditions" % len(BIOMES))
