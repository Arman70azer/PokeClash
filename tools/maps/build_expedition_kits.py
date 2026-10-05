"""Kits des zones d'expédition autres que la forêt (voir build_forest_kit.py) : planches de
tuiles du sol (cases de 16 × 16) et décors 3D, tirés des cartes de Noir 2 / Blanc 2 et
HeartGold / SoulSilver rangées dans assets/maps et source_assets/maps.

    python tools/maps/build_expedition_kits.py

- Désert (Desert Resort) : assets/maps/desert_resort/desert_ground.png.
- Montagne (Victory Road, neige des Sinjoh Ruins) : assets/maps/victory_road/
  mountain_ground.png ; grands glaçons convertis (assets/mapobjects/big_icicle_*).
- Lagune (Humilau City) : assets/maps/humilau_city/lagoon_ground.png ; palmier et rocher
  découpés dans la carte (lagoon_palm.obj, lagoon_rock.obj).
Les falaises utilisent directement les textures des cartes (voir build_expedition_biomes.py).
"""
import os
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_forest_kit as kit  # noqa: E402
import dae_to_obj  # noqa: E402

ROOT = kit.ROOT
MAPS = os.path.join(ROOT, "assets", "maps")


def texture(folder, prefix, number):
    return Image.open(os.path.join(MAPS, folder, "%s_texture_%s.png" % (prefix, number))).convert("RGBA")


def sheet(path, size, blocks):
    """Écrit une planche : `blocks` = [((colonne, rangée), image)], chaque image collée à sa
    case (une image de 32 × 32 couvre 2 × 2 cases)."""
    out = Image.new("RGBA", (size[0] * 16, size[1] * 16), (0, 0, 0, 0))
    for (x, y), image in blocks:
        out.alpha_composite(image, (x * 16, y * 16))
    out.save(path)
    print("écrit", os.path.relpath(path, ROOT))


def desert():
    def t(n):
        return texture("desert_resort", "Desert Resort Area 2", n).crop((0, 0, 16, 16))
    # Sable, sable ridé, sable orange des rencontres.
    sheet(os.path.join(MAPS, "desert_resort", "desert_ground.png"), (3, 1),
          [((0, 0), t("0011")), ((1, 0), t("00010")), ((2, 0), t("0045"))])


def mountain():
    def t(n):
        return texture("victory_road", "Victory Road", n)
    cobble = t("0016")                       # pavés rouges, 32 × 32
    tuft = t("0003")                         # touffe de plantes, 16 × 16
    rough = cobble.copy()
    for x in (0, 16):
        for y in (0, 16):
            rough.alpha_composite(tuft, (x, y))
    # Sol (2 × 2 cases), chemin de sable (2 × 2), rencontres : pavés et touffes (2 × 2).
    sheet(os.path.join(MAPS, "victory_road", "mountain_ground.png"), (6, 2),
          [((0, 0), cobble), ((2, 0), t("0013")), ((4, 0), rough)])
    for i in (1, 2, 3):
        folder = "big_icicle_%d" % i
        dae_to_obj.main(os.path.join(ROOT, "source_assets", "mapobjects", folder, "bigicicle_0%d.dae" % i), folder,
                        os.path.join(ROOT, "assets", "mapobjects", folder))


# Décors découpés dans Humilau City : couches, carré (x0, z0, x1, z1), hauteur du sol.
LAGOON_PIECES = {
    "lagoon_palm": (["ki04ax", "ki04bx", "ki04c", "ki04dx"], (24, 664, 72, 712), -78.0),
    "lagoon_rock": (["rock01_lm1"], (-184, 656, -136, 696), -78.0),
}


def lagoon():
    def t(n):
        return texture("humilau_city", "Humilau City", n)
    # Sable (1 case), ponton (2 × 2), mer (2 × 2), eau claire du lagon (2 × 2).
    sheet(os.path.join(MAPS, "humilau_city", "lagoon_ground.png"), (8, 2),
          [((0, 0), t("0070")), ((2, 0), t("0018")), ((4, 0), t("0001")), ((6, 0), t("0014"))])
    with tempfile.TemporaryDirectory() as tmp:
        dae_to_obj.main(os.path.join(ROOT, "source_assets", "maps", "humilau_city", "Humilau City.dae"), "humilau", tmp)
        verts, uvs, faces = kit.read_obj(os.path.join(tmp, "humilau.obj"))
        textures = kit.read_mtl(os.path.join(tmp, "humilau.mtl"))
    for name, (layers, box, floor) in LAGOON_PIECES.items():
        pieces = kit.extract(verts, uvs, faces, layers, box, 1.0, floor)
        kit.write_obj(os.path.join(MAPS, "humilau_city", name + ".obj"), pieces, textures,
                      "Découpé dans Humilau City par tools/maps/build_expedition_kits.py")
        print(name, sum(len(p) for p in pieces.values()), "triangles")


if __name__ == "__main__":
    desert()
    mountain()
    lagoon()
