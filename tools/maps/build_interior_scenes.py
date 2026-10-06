"""Écrit les cartes des intérieurs (maps/<id>/<id>.tscn), ainsi que les portes et les
passages d'Accumula, du quartier bourgeois et du port (maps/accumula/accumula_doors.tscn
et accumula_warps.tscn, instanciées par accumula.tscn).

    python tools/maps/build_interior_scenes.py

Modifier ce script plutôt que les scènes, puis le relancer : il les réécrit toutes.

Chaque intérieur est un modèle de assets/maps (voir build_interiors.py) placé à son
propre endroit du monde par `cell_offset`, car l'hôte garde chargées ensemble les cartes
où se trouvent des joueurs. Un même modèle sert à plusieurs bâtiments identiques (les
quatre immeubles en brique, les deux entrepôts).
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UP, DOWN, LEFT, RIGHT = (0, -1), (0, 1), (-1, 0), (1, 0)
ACC_TEX = "res://assets/maps/accumula_town/Accumula Town_texture_00%s.png"

# Modèles d'intérieur, en cases du modèle (avant décalage) :
# - entry : case d'arrivée, sur le tapis de sortie ; exit : cases sous le tapis (on sort
#   en descendant dessus) ;
# - up / down : escalier ou ascenseur vers l'étage (cases qui déclenchent, direction,
#   case et orientation d'arrivée quand on revient par là) ;
# - bounds : cases utilisables, quand le modèle est posé sur une grande dalle.
ROOMS = {
    "nuvema_house_3_1f": dict(entry=(-13, -8), exit=[(-14, -7), (-13, -7), (-12, -7)],
                              up=dict(trigger=[(-18, -18)], dir=LEFT, arrive=(-17, -18), facing=RIGHT)),
    "nuvema_house_2_2f": dict(down=dict(trigger=[(-19, -18)], dir=LEFT, arrive=(-18, -18), facing=RIGHT)),
    "aspertia_building_8": dict(entry=(-13, -7), exit=[(-14, -6), (-13, -6), (-12, -6)],
                                up=dict(trigger=[(-12, -20), (-11, -20)], dir=UP, arrive=(-11, -19), facing=DOWN)),
    "aspertia_building_7": dict(down=dict(trigger=[(-9, -18)], dir=LEFT, arrive=(-8, -18), facing=RIGHT)),
    "black_city_house_1": dict(entry=(-13, -9), exit=[(-14, -8), (-13, -8), (-12, -8)]),
    "driftveil_hotel_room_1": dict(entry=(-12, -4), exit=[(-13, -3), (-12, -3), (-11, -3), (-10, -3)],
                                   bounds=(-19, -19, 17, 16),
                                   up=dict(trigger=[(-17, -19), (-16, -19)], dir=UP, arrive=(-17, -18), facing=DOWN)),
    # Chambre sans porte sur la rue : on y arrive et on en repart par l'ascenseur (vers le
    # hall de l'hôtel, ou le bas du phare).
    "driftveil_hotel_room_3": dict(entry=(-17, -18), exit=[(-17, -19), (-16, -19)], exit_dir=UP,
                                   down=dict(trigger=[(-17, -19), (-16, -19)], dir=UP, arrive=(-17, -18), facing=DOWN),
                                   bounds=(-19, -19, 16, 15)),
    "floccesy_house_5": dict(entry=(-13, -9), exit=[(-14, -8), (-13, -8), (-12, -8)]),
    "lentimas_house_6": dict(entry=(-13, -9), exit=[(-14, -8), (-13, -8), (-12, -8)]),
    "humilau_house_7": dict(entry=(-13, -9), exit=[(-14, -8), (-13, -8), (-12, -8)]),
    "cafe_warehouse_interior": dict(entry=(-10, -1), exit=[(-11, 0), (-10, 0), (-9, 0)]),
    "nacrene_warehouse_interior": dict(entry=(-13, -8), exit=[(-14, -7), (-13, -7), (-12, -7)]),
}

# Portes des bâtiments (sous Doors d'Accumula) : script, réglages.
ORANGE = dict(leaf_texture=ACC_TEX % "49", leaf_region=(0, 0, 27, 32))   # portes des immeubles
NUVEMA = dict(leaf_texture=ACC_TEX % "43", leaf_region=(1, 0, 22, 32))   # porte à carreaux
DOORS = {
    "MaisonDoor": dict(zone_path="../../Zone", surface_name="door_t1_02_lm1", dark_depth=16),
    "ImmeubleOuestDoor": dict(zone_path="../../Zone", surface_name="door_n_02", dark_depth=16),
    "ImmeubleEstDoor": dict(zone_path="../../Zone", surface_name="door_n_02_1", dark_depth=16),
    "ImmeubleBasDoor": dict(zone_path="../../Zone", surface_name="door_n_02_2", dark_depth=16),
    "LaboratoireDoor": dict(position=(-24, 3.5, 344), size=(18, 31.5), style="DOUBLE_SLIDE", inset=10.6,
                            leaf_texture="res://assets/mapobjects/juniper_pokemon_lab/h_mado_lm2.png", leaf_repeat=(1, 2)),
    "ImmeubleDoor": dict(position=(217, 3, 345), size=(18, 34), **ORANGE),
    "HotelDoor": dict(position=(-72, 4, 602), size=(18, 30), style="DOUBLE_SLIDE", inset=13.6,
                      leaf_texture="res://assets/mapobjects/driftveil_city_houses/driftveil_city_house_1/h_mado.png",
                      leaf_repeat=(1, 2)),
    "VillaDoor": dict(position=(296, 4, 604), size=(18, 30), **ORANGE),
    "MaisonQuartierDoor": dict(position=(8, 2, 597), size=(20, 32), **NUVEMA),
    "MaisonVoisineDoor": dict(position=(200, 2, 597), size=(20, 26), **NUVEMA),
    "CafeDoor": dict(position=(392, 1, -215), size=(24, 34), **NUVEMA),
    "FrigoDoor": dict(zone_path="../../Port/Buildings/ColdStorage", cut_box=((383, 3.95, -1), (18, 28.2, 2)), dark_depth=16),
    "PhareDoor": dict(position=(744, 14, -96.8), size=(14, 22), tilt=13.4, zone_path="../../Port/Buildings/Lighthouse",
                      dark_depth=14, leaf_texture="res://assets/mapobjects/cold_storage_warehouses/cold_storage_warehouse_1/wh1d.png",
                      leaf_region=(0, 17, 10, 15)),
}

# Cartes intérieures : identifiant -> (nom affiché, modèle, porte d'Accumula et case de la
# porte (None : on y vient par l'escalier), étage du dessus, habitant).
# Habitant : (nom, planche, case du modèle, répliques[, autres réglages du PNJ]).
MAPS = [
    ("accumula_maison", "Maison d'Accumula", "nuvema_house_3_1f", ("MaisonDoor", (10, -8)), "accumula_maison_etage",
     ("Grand-mère", "grand_mere", (-9, -15), ["Bienvenue ! Mon petit-fils dort à l'étage.",
                                               "De là-haut, on voit toute la place d'Accumula."])),
    ("accumula_maison_etage", "Maison d'Accumula, à l'étage", "nuvema_house_2_2f", None, None,
     ("Fillette", "fillette", (-13, -14), ["Chut ! C'est ma chambre, ici.", "Un jour, je partirai à l'aventure moi aussi !"])),
    ("accumula_immeuble_ouest", "Immeuble d'Accumula", "aspertia_building_8", ("ImmeubleOuestDoor", (-7, -10)),
     "accumula_immeuble_ouest_etage",
     ("Ouvrier", "ouvrier", (-10, -10), ["Je rentre du port. Les grues ne s'arrêtent jamais !"])),
    ("accumula_immeuble_ouest_etage", "Immeuble d'Accumula, à l'étage", "aspertia_building_7", None, None, None),
    ("accumula_immeuble_est", "Immeuble d'Accumula", "aspertia_building_8", ("ImmeubleEstDoor", (1, -10)),
     "accumula_immeuble_est_etage",
     ("Lycéenne", "lyceenne", (-10, -10), ["J'habite au-dessus du Centre Pokémon… enfin, presque !"])),
    ("accumula_immeuble_est_etage", "Immeuble d'Accumula, à l'étage", "aspertia_building_7", None, None, None),
    ("accumula_immeuble_bas", "Immeuble d'Accumula", "aspertia_building_8", ("ImmeubleBasDoor", (-13, 4)),
     "accumula_immeuble_bas_etage",
     ("Dame", "dame_chignon", (-10, -10), ["La place du bas est si calme le soir.", "On y entend les Pokémon chanter."])),
    ("accumula_immeuble_bas_etage", "Immeuble d'Accumula, à l'étage", "aspertia_building_7", None, None, None),
    ("quartier_immeuble", "Immeuble du quartier", "aspertia_building_8", ("ImmeubleDoor", (13, 21)), "quartier_immeuble_etage",
     ("Homme d'affaires", "homme_affaires", (-10, -10), ["Un immeuble en brique, comme ceux d'Accumula.",
                                                        "Le quartier, c'est la ville… en plus chic."])),
    ("quartier_immeuble_etage", "Immeuble du quartier, à l'étage", "aspertia_building_7", None, None, None),
    ("quartier_laboratoire", "Laboratoire Pokémon", "black_city_house_1", ("LaboratoireDoor", (-2, 21)), None,
     ("Assistant", "gentleman", (-9, -12), ["Bienvenue au laboratoire !",
                                            "Nous étudions les Pokémon que les dresseurs rapportent des expéditions."])),
    ("quartier_hotel", "Hôtel", "driftveil_hotel_room_1", ("HotelDoor", (-5, 37)), "quartier_hotel_suite",
     ("Réceptionniste", "elegante", (-12, -18), ["Bienvenue à l'hôtel !",
                                                "L'ascenseur, à gauche, monte jusqu'à la suite."],
      dict(wander_radius=0, looks_around="false", talk_reach=2))),
    ("quartier_hotel_suite", "Hôtel, la suite", "driftveil_hotel_room_3", None, None,
     ("Client", "rentier", (-10, -11), ["Quelle vue depuis la suite !", "Je ne veux plus jamais repartir."])),
    ("quartier_villa", "Villa", "humilau_house_7", ("VillaDoor", (18, 37)), None,
     ("Dame en blanc", "dame_blanche", (-12, -12), ["Cette villa me rappelle la mer de Janusia.",
                                                     "Le bassin, au milieu du salon, c'est mon idée !"])),
    ("quartier_maison", "Maison du quartier", "floccesy_house_5", ("MaisonQuartierDoor", (0, 37)), None,
     ("Grand-père", "grand_pere", (-10, -11), ["Rien ne vaut un bon feu de cheminée.",
                                               "Mes Pokémon dorment toujours devant."])),
    ("quartier_maison_voisine", "Maison voisine", "lentimas_house_6", ("MaisonVoisineDoor", (12, 37)), None,
     ("Gamin", "gamin", (-12, -12), ["Ma maison est toute en bois, comme dans les montagnes !"])),
    ("port_cafe", "Café du port", "cafe_warehouse_interior", ("CafeDoor", (24, -14)), None,
     ("Patron", "chef", (-12, -6), ["Bienvenue au café !", "Les marins prennent un café ici avant d'embarquer."])),
    ("port_entrepot", "Entrepôt du port", "nacrene_warehouse_interior", (None, (24, 11)), None,
     ("Docker", "ouvrier", (-10, -10), ["On a aménagé l'entrepôt en appartement.", "Les caisses, je les garde pour le style."])),
    ("port_entrepot_frigorifique", "Entrepôt frigorifique", "nacrene_warehouse_interior", ("FrigoDoor", (24, -1)), None,
     ("Marin", "marin", (-10, -10), ["Brr ! Le froid, en bas, c'est pour le poisson.", "Nous, on loge en haut, au chaud."])),
    ("port_phare", "Phare, salle du gardien", "driftveil_hotel_room_3", ("PhareDoor", (46, -7)), None,
     ("Gardien du phare", "marin", (-10, -11), ["L'ascenseur monte jusqu'à ma salle, sous la lanterne.",
                                                "D'ici, je guide tous les bateaux du port."])),
]

# Décalage de chaque intérieur, en cases : loin de la ville et du Centre Pokémon (x ≈ 230 à
# 250), sans chevauchement (un intérieur fait moins de 30 cases).
FIRST_OFFSET = 300
SPACING = 40


def offset(index):
    return (FIRST_OFFSET + SPACING * index, 0)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def v2(c):
    return "Vector2i(%d, %d)" % tuple(c)


def cells(cs):
    return "Array[Vector2i]([%s])" % ", ".join(v2(c) for c in cs)


def string_array(lines):
    return "PackedStringArray(%s)" % ", ".join('"%s"' % s.replace('"', '\\"') for s in lines)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def warp_node(name, trigger, direction, target_map, target_cell, facing, source_door=None, target_door=None):
    out = ['[node name="%s" type="Node" parent="."]' % name, 'script = ExtResource("warp")',
           "trigger_cells = " + cells(trigger), "direction = " + v2(direction),
           'target_map = &"%s"' % target_map, "target_cell = " + v2(target_cell), "target_facing = " + v2(facing)]
    if source_door:
        out.append('source_door = NodePath("../../Doors/%s")' % source_door)
    if target_door:
        out.append('target_door = &"%s"' % target_door)
    return "\n".join(out) + "\n"


def interior_scene(index, map_id, title, room_name, outside, upper, resident, lower):
    room = ROOMS[room_name]
    shift = offset(index)
    out = ['[gd_scene format=3]', '',
           '[ext_resource type="Script" path="res://world/game_map.gd" id="map"]',
           '[ext_resource type="Script" path="res://world/map_zone.gd" id="zone"]',
           '[ext_resource type="ArrayMesh" path="res://assets/maps/%s/%s.obj" id="mesh"]' % (room_name, room_name),
           '[ext_resource type="Resource" path="res://assets/maps/%s/%s_grid.tres" id="grid"]' % (room_name, room_name),
           '[ext_resource type="Script" path="res://world/warp.gd" id="warp"]']
    if resident:
        out.append('[ext_resource type="Script" path="res://characters/npc.gd" id="npc"]')
    node_name = "".join(part.capitalize() for part in map_id.split("_"))
    out += ['', '[node name="%s" type="Node3D"]' % node_name, 'script = ExtResource("map")', 'map_id = &"%s"' % map_id,
            'display_name = "%s"' % title, '',
            '[node name="Interior" type="MeshInstance3D" parent="."]', 'mesh = ExtResource("mesh")',
            'script = ExtResource("zone")', 'walk_grid = ExtResource("grid")', 'cell_offset = ' + v2(shift),
            'saturation = 1.15', 'contrast = 1.05', 'vertex_shading = 0.35', 'shadow_opacity = 0.3', '',
            '[node name="Warps" type="Node" parent="."]', '']
    body = "\n".join(out) + "\n"
    warps = []
    if outside:
        door, door_cell = outside
        front = add(door_cell, DOWN)
        exit_dir = room.get("exit_dir", DOWN)
        warps.append(warp_node("Leave", [add(c, shift) for c in room["exit"]], exit_dir, "accumula", front, DOWN,
                               target_door=door))
    if upper:
        up = room["up"]
        upper_index = index + 1
        upper_down = ROOMS[MAPS[upper_index][2]]["down"]
        warps.append(warp_node("GoUp", [add(c, shift) for c in up["trigger"]], up["dir"], upper,
                               add(upper_down["arrive"], offset(upper_index)), upper_down["facing"]))
    if lower:
        down = room["down"]
        lower_index = index - 1
        lower_up = ROOMS[MAPS[lower_index][2]]["up"]
        warps.append(warp_node("GoDown", [add(c, shift) for c in down["trigger"]], down["dir"], lower,
                               add(lower_up["arrive"], offset(lower_index)), lower_up["facing"]))
    body += "\n".join(w.replace('parent="."', 'parent="Warps"') for w in warps)
    body += '\n[node name="Objects" type="Node3D" parent="."]\n'
    if resident:
        name, sheet, cell, lines = resident[:4]
        extra = dict(wander_radius=1)
        extra.update(resident[4] if len(resident) > 4 else {})
        body += "\n".join(['', '[node name="Habitant" type="Node3D" parent="Objects"]', 'script = ExtResource("npc")',
                           "cell = " + v2(add(cell, shift)), 'display_name = "%s"' % name, 'sheet = "%s"' % sheet,
                           "lines = " + string_array(lines)] + ["%s = %s" % kv for kv in extra.items()]) + "\n"
    return body


def gd_value(key, value):
    if key in ("zone_path",):
        return 'NodePath("%s")' % value
    if key == "leaf_texture":
        return 'ExtResource("%s")' % value
    if key == "style":
        return {"SWING": 0, "SLIDE": 1, "DOUBLE_SLIDE": 2, "SHUTTER": 3}[value]
    if key == "position":
        return None
    if key in ("size", "leaf_repeat"):
        return "Vector2(%g, %g)" % value
    if key == "leaf_region":
        return "Rect2(%g, %g, %g, %g)" % value
    if key == "cut_box":
        return "AABB(%g, %g, %g, %g, %g, %g)" % (value[0] + value[1])
    if isinstance(value, str):
        return '"%s"' % value
    return "%g" % value


def doors_scene():
    textures = sorted({d["leaf_texture"] for d in DOORS.values() if "leaf_texture" in d})
    tex_ids = {t: "tex%d" % i for i, t in enumerate(textures)}
    out = ['[gd_scene format=3]', '',
           '[ext_resource type="Script" path="res://world/door.gd" id="door"]',
           '[ext_resource type="Script" path="res://world/panel_door.gd" id="panel"]']
    out += ['[ext_resource type="Texture2D" path="%s" id="%s"]' % (t, tex_ids[t]) for t in textures]
    out += ['', '[node name="Doors" type="Node3D"]', '',
            '[node name="PokemonCenterDoor" type="Node3D" parent="."]', 'script = ExtResource("door")',
            'zone_path = NodePath("../../Zone")', 'surface_name = "door_pc_1"', '']
    for name, spec in DOORS.items():
        out.append('[node name="%s" type="Node3D" parent="."]' % name)
        if "position" in spec:
            out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)" % spec["position"])
        out.append('script = ExtResource("panel")')
        for key, value in spec.items():
            if key == "leaf_texture":
                value = tex_ids[value]
            text = gd_value(key, value)
            if text is not None:
                out.append("%s = %s" % (key, text))
        out.append("")
    return "\n".join(out)


def warps_scene():
    out = ['[gd_scene format=3]', '', '[ext_resource type="Script" path="res://world/warp.gd" id="warp"]', '',
           '[node name="Warps" type="Node"]', '',
           warp_node("EnterPokemonCenter", [(12, 1)], UP, "accumula_pokemon_center", (239, 3), UP, "PokemonCenterDoor")]
    for index, (map_id, _, room_name, outside, _, _) in enumerate(MAPS):
        if not outside:
            continue
        door, door_cell = outside
        room = ROOMS[room_name]
        name = "Enter" + "".join(part.capitalize() for part in map_id.split("_"))
        out.append(warp_node(name, [door_cell], UP, map_id, add(room["entry"], offset(index)),
                             UP if room.get("exit_dir", DOWN) == DOWN else DOWN, door))
    return "\n".join(out)


def set_bounds(room_name, bounds):
    """Écrit les cases utilisables dans la grille du modèle (gardées si on la recalcule)."""
    path = os.path.join(ROOT, "assets", "maps", room_name, room_name + "_grid.tres")
    with open(path, encoding="utf-8") as f:
        lines = [line for line in f.read().splitlines() if not line.startswith("bounds = ")]
    lines.append("bounds = Rect2i(%d, %d, %d, %d)" % bounds)
    write(path, "\n".join(lines) + "\n")


def main():
    for room_name, room in ROOMS.items():
        if "bounds" in room:
            set_bounds(room_name, room["bounds"])
    lowers = {upper: MAPS[i][0] for i, (_, _, _, _, upper, _) in enumerate(MAPS) if upper}
    for index, (map_id, title, room_name, outside, upper, resident) in enumerate(MAPS):
        if upper:
            assert MAPS[index + 1][0] == upper, "l'étage suit sa carte du bas dans MAPS"
        text = interior_scene(index, map_id, title, room_name, outside, upper, resident, lowers.get(map_id))
        write(os.path.join(ROOT, "maps", map_id, map_id + ".tscn"), text)
    write(os.path.join(ROOT, "maps", "accumula", "accumula_doors.tscn"), doors_scene())
    write(os.path.join(ROOT, "maps", "accumula", "accumula_warps.tscn"), warps_scene())
    print(len(MAPS), "intérieurs,", len(DOORS) + 1, "portes")


if __name__ == "__main__":
    main()
