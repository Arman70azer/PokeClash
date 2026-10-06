"""Intérieurs des bâtiments d'Accumula, du quartier bourgeois et du port, tirés des cartes
intérieures de Pokémon Noir 2 / Blanc 2 (archives de source_assets/archives).

Pour chaque intérieur : le .dae est lu dans son archive, converti en .obj (voir
dae_to_obj.py) et agrandi 1,3 fois comme le Centre Pokémon, pour que les personnages
aient la même taille dans tous les intérieurs. Le modèle reste autour de son origine :
chaque carte le place dans le monde avec `cell_offset` (voir MapZone), ce qui permet de
réutiliser un même intérieur pour deux bâtiments identiques.

    python tools/maps/build_interiors.py

Puis, une fois le projet importé dans Godot, calculer la grille de chaque intérieur :
    godot --headless -s res://tools/maps/bake_map_grid.gd -- res://assets/maps/<nom>/<nom>.obj res://assets/maps/<nom>/<nom>_grid.tres
"""
import os
import shutil
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dae_to_obj  # noqa: E402
import place_model  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARCHIVES = os.path.join(ROOT, "source_assets", "archives")
ARCHIVE = "DS _ DSi - Pokemon Black 2 _ White 2 - Interior Maps - %s.zip"
SCALE = 1.3

# Dossier de assets/maps -> nom de l'intérieur dans les archives.
INTERIORS = {
    "nuvema_house_3_1f": "Nuvema Town House 3 1F",
    "nuvema_house_2_2f": "Nuvema Town House 2 2F",
    "aspertia_building_7": "Aspertia City Building 7",
    "aspertia_building_8": "Aspertia City Building 8",
    "driftveil_hotel_room_1": "Driftveil City Hotel Room 1",
    "driftveil_hotel_room_3": "Driftveil City Hotel Room 3",
    "floccesy_house_5": "Floccesy Town House 5",
    "lentimas_house_6": "Lentimas Town House 6",
    "cafe_warehouse_interior": "Cafe Warehouse",
    "nacrene_warehouse_interior": "Nacrene City Warehouse 1",
}
# Intérieurs fournis en .dae (source_assets/maps/<dossier>/), textures déjà dans
# assets/maps/<dossier>/ : dossier -> fichier .dae.
SOURCES = {
    "season_research_lab": "Season Research Lab.dae",
    "striaton_building_2": "Striaton City Building 2.dae",
}


def build(folder, name):
    out = os.path.join(ROOT, "assets", "maps", folder)
    os.makedirs(out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(os.path.join(ARCHIVES, ARCHIVE % name)) as archive:
            archive.extractall(tmp)
        dae = None
        for base, _, files in os.walk(tmp):
            for f in files:
                if f.endswith(".png"):
                    shutil.copy(os.path.join(base, f), os.path.join(out, f))
                elif f.endswith(".dae"):
                    dae = os.path.join(base, f)
        dae_to_obj.main(dae, folder, out)
    place_model.main(os.path.join(out, folder + ".obj"), 0.0, 0.0, SCALE)


# Étage intermédiaire des immeubles en brique : l'étage d'Aspertia 7 (escalier qui
# descend), où l'escalier qui monte d'Aspertia 8 prend la place de la télévision, contre
# le mur du haut de la grande pièce ; la table basse et ses coussins descendent un peu sur
# le tapis pour laisser le passage. Positions en unités du modèle agrandi : escalier
# d'Aspertia 8 (boîte x0, z0, x1, z1) et décalage qui l'amène là.
MID_FLOOR = "aspertia_building_7_mid"
STAIRS_BOX = (-188, -321, -145, -282)
STAIRS_SHIFT = (-75.0, -2.6, 84.7)  # murs du haut : z -323,7 -> -239 ; sols : y -2,6 -> -5,2
TV_BOX = (-270, -235, -205, -200)   # télévision et son ombre, retirées (x0, z0, x1, z1)
TABLE_BOX = (-272, -212, -205, -120)  # table basse, coussins et ombres, descendus
TABLE_SHIFT = 26.0


def build_mid_floor():
    import build_forest_kit as kit
    out = os.path.join(ROOT, "assets", "maps", MID_FLOOR)
    os.makedirs(out, exist_ok=True)
    tris, textures = {}, {}
    for folder, keep in (("aspertia_building_7", _not_tv), ("aspertia_building_8", _stairs)):
        src = os.path.join(ROOT, "assets", "maps", folder)
        verts, uvs, faces = kit.read_obj(os.path.join(src, folder + ".obj"))
        mats = kit.read_mtl(os.path.join(src, folder + ".mtl"))
        shift = STAIRS_SHIFT if folder == "aspertia_building_8" else (0.0, 0.0, 0.0)
        # Les deux modèles ont des matériaux de même nom : ceux d'Aspertia 8 sont renommés.
        prefix = "b08_" if folder == "aspertia_building_8" else ""
        for material, face_list in faces.items():
            kept = 0
            for face in face_list:
                points = [verts[v] for v, _ in face]
                if not keep(material, points):
                    continue
                if folder == "aspertia_building_7" and _in_box(TABLE_BOX, points) and _furniture(material):
                    shift = (0.0, 0.0, TABLE_SHIFT)
                elif folder == "aspertia_building_7":
                    shift = (0.0, 0.0, 0.0)
                corners = [(tuple(p[k] + shift[k] for k in range(3)), uvs[t] if t >= 0 else (0.0, 0.0), p[3:6])
                           for p, (_, t) in zip(points, face)]
                for k in range(1, len(corners) - 1):
                    tris.setdefault(prefix + material, []).append((corners[0], corners[k], corners[k + 1]))
                kept += 1
            if kept:
                textures[prefix + material] = mats[material]
                shutil.copy(os.path.join(src, mats[material]), os.path.join(out, mats[material]))
    kit.write_obj(os.path.join(out, MID_FLOOR + ".obj"), tris, textures,
                  "Aspertia 7 et l'escalier d'Aspertia 8, assemblés par tools/maps/build_interiors.py")


def _in_box(box, points):
    x0, z0, x1, z1 = box
    return all(x0 <= p[0] <= x1 and z0 <= p[2] <= z1 for p in points)


def _furniture(material):
    return material.startswith(("idr_table", "chushion", "h_kage", "in02_kage"))


def _not_tv(material, points):
    return not ((material == "tv" or material.startswith(("idr_tv", "in02_kage"))) and _in_box(TV_BOX, points))


def _stairs(material, points):
    return material == "lambert2" and _in_box(STAIRS_BOX, points)


def build_source(folder, dae):
    out = os.path.join(ROOT, "assets", "maps", folder)
    dae_to_obj.main(os.path.join(ROOT, "source_assets", "maps", folder, dae), folder, out)
    place_model.main(os.path.join(out, folder + ".obj"), 0.0, 0.0, SCALE)


def main():
    only = sys.argv[1:]
    for folder, name in INTERIORS.items():
        if not only or folder in only:
            build(folder, name)
    for folder, dae in SOURCES.items():
        if not only or folder in only:
            build_source(folder, dae)
    if not only or MID_FLOOR in only:
        build_mid_floor()


if __name__ == "__main__":
    main()
