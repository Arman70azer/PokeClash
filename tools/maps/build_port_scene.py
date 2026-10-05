"""Écrit maps/accumula/port.tscn : la zone du port, sa mer et chaque objet posé dessus.

Usage, depuis le dossier du projet :
    python tools/maps/build_port_scene.py

Modifier ce script plutôt que port.tscn, puis relancer : il réécrit toute la scène.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_PATH = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "maps", "accumula", "port.tscn")
T = 16
P = "res://assets/mapobjects/port/{0}/{0}.obj"
MESHES = {
    "crane": "res://assets/mapobjects/driftveil_city_crane/Driftveil City Crane.obj",
    "lighthouse": "res://assets/mapobjects/driftveil_city_lighthouse/Driftveil City Lighthouse.obj",
    "cold_storage": "res://assets/mapobjects/cold_storage_warehouses/cold_storage_warehouse_1/Cold Storage Warehouse 1.obj",
    "warehouse": "res://assets/mapobjects/nacrene_city_warehouses/nacrene_city_warehouse_1/Nacrene City Warehouse 1.obj",
    "cafe": "res://assets/mapobjects/cafe_warehouse/Cafe Warehouse.obj",
}
for n in ["bollard", "life_buoy", "nav_buoy_red", "nav_buoy_green", "crates", "crates_big", "barrels", "containers",
          "container_red", "container_blue", "lamppost", "rowboat", "rowboat_v", "fishing_boat", "fishing_boat_v",
          "sailboat", "sailboat_v", "ferry", "cargo_ship", "gangway"]:
    MESHES[n] = P.format(n)

def c(x, y):  # centre of a cell
    return (x * T + 8, y * T + 8)

objs = []  # (node name, mesh, (x, y, z), footprint or None, extra cells, bob height, bob period)
def add(name, mesh, pos, footprint=None, extra=(), bob=0.0, period=3.0, scale=1.0):
    objs.append((name, mesh, pos, footprint, list(extra), bob, period, scale))

# Buildings on the quay.
add("Crane", "crane", (500, 0, -200), extra=[(27, -16), (27, -15), (30, -16), (30, -15), (27, -11), (27, -10), (30, -11), (30, -10)])
# Entrances face the camera, centred on a cell, front wall on a cell boundary:
# the player stands right in front of the door one row below.
add("Cafe", "cafe", (376, 0, -210), footprint=(21, -15, 6, 2))  # door in front of (24, -13)
add("ColdStorage", "cold_storage", (428, 0, -56), footprint=(23, -7, 7, 7))  # shutter in front of (27, 0)
add("Warehouse", "warehouse", (409.5, 0, 164), footprint=(21, 6, 7, 6), scale=1.4,
    extra=[(x, y) for x in (28, 29) for y in range(7, 12)])  # door in front of (24, 12)
add("Lighthouse", "lighthouse", (744, 0, -121.4), footprint=(45, -9, 3, 3))  # door in front of (46, -6)
# Cargo.
add("Containers", "containers", (464, 0, -200), footprint=(28, -13, 2, 2))
add("ContainerBlue", "container_blue", (464, 0, -248), footprint=(28, -16, 2, 1))
add("ContainerRed", "container_red", (464, 0, 104), footprint=(28, 6, 2, 1))
x, z = c(29, 13); add("CratesBig", "crates_big", (x + 8, 0, z), footprint=(28, 13, 3, 1))
x, z = c(30, 15); add("Barrels", "barrels", (x, 0, z), footprint=(30, 15, 1, 1))
x, z = c(21, 12); add("Crates", "crates", (x, 0, z - 4), footprint=(21, 12, 1, 1))
x, z = c(22, 12); add("Barrels2", "barrels", (x, 0, z), footprint=(22, 12, 1, 1))
x, z = c(26, -12); add("Crates2", "crates", (x, 0, z), footprint=(26, -12, 1, 1))
# Mooring bollards along the quay and the pier.
for i, (cx, cy, side) in enumerate([(31, -3, "e"), (31, 0, "e"), (31, 7, "e"), (31, 10, "e"),
                                     (34, -10, "n"), (37, -10, "n"), (40, -10, "n"),
                                     (34, -5, "s"), (38, -5, "s"), (42, -5, "s")]):
    x, z = c(cx, cy)
    dx, dz = {"e": (4, 0), "n": (0, -4), "s": (0, 4)}[side]
    add(f"Bollard{i + 1}", "bollard", (x + dx, 0, z + dz), footprint=(cx, cy, 1, 1))
for i, (cx, cy) in enumerate([(31, -4), (47, -10), (31, 11), (47, -5)]):
    x, z = c(cx, cy)
    add(f"LifeBuoy{i + 1}", "life_buoy", (x, 0, z), footprint=(cx, cy, 1, 1))
for i, (cx, cy) in enumerate([(21, -11), (21, -3), (21, 5), (21, 14), (39, -10), (36, -5)]):
    x, z = c(cx, cy)
    add(f"Lamppost{i + 1}", "lamppost", (x, 0, z), footprint=(cx, cy, 1, 1))
# Ships and boats (floating, nothing blocked: they are on the water).
W = -20
add("Ferry", "ferry", (678, W, -206), bob=0.4, period=7.0)
add("Gangway", "gangway", (680, 0, -158), footprint=(42, -10, 1, 1))
add("CargoShip", "cargo_ship", (668, W, -24), bob=0.4, period=7.5)
add("FishingBoat1", "fishing_boat_v", (545, W, 128), bob=1.0, period=4.0)
add("Sailboat1", "sailboat_v", (640, W, 128), bob=1.2, period=3.6)
add("Sailboat2", "sailboat_v", (724, W, 128), bob=1.2, period=3.9)
add("FishingBoat2", "fishing_boat_v", (772, W, 126), bob=1.0, period=4.2)
add("Rowboat1", "rowboat", (566, W, 192), bob=1.0, period=2.8)
add("Rowboat2", "rowboat", (618, W, 192), bob=1.0, period=3.1)
add("Rowboat3", "rowboat", (700, W, 193), bob=1.0, period=3.0)
add("Rowboat4", "rowboat_v", (744, W, 236), bob=1.0, period=2.9)
add("BuoyRed", "nav_buoy_red", (900, W, -70), bob=1.5, period=2.6)
add("BuoyGreen", "nav_buoy_green", (900, W, 180), bob=1.5, period=2.4)

used = sorted({o[1] for o in objs})
ids = {m: f"{i + 10}_{m}" for i, m in enumerate(used)}
out = ['[gd_scene format=3]', '',
       '[ext_resource type="Script" path="res://world/map_zone.gd" id="1_zone"]',
       '[ext_resource type="ArrayMesh" path="res://assets/maps/port/port.obj" id="2_mesh"]',
       '[ext_resource type="Resource" path="res://assets/maps/port/port_grid.tres" id="3_grid"]',
       '[ext_resource type="Script" path="res://world/map_object_3d.gd" id="4_obj"]',
       '[ext_resource type="ArrayMesh" path="res://assets/maps/port/port_water.obj" id="5_water"]']
for m in used:
    out.append(f'[ext_resource type="ArrayMesh" path="{MESHES[m]}" id="{ids[m]}"]')
out += ['', '[node name="Port" type="MeshInstance3D"]', 'mesh = ExtResource("2_mesh")', 'script = ExtResource("1_zone")',
        'walk_grid = ExtResource("3_grid")', '',
        '[node name="Water" type="MeshInstance3D" parent="."]', 'mesh = ExtResource("5_water")', 'script = ExtResource("4_obj")',
        'scrolling_surfaces = {', '"sea": Vector2(0.03, 0.012)', '}', '',
        '[node name="Buildings" type="Node3D" parent="."]', '']
for name, mesh, (x, y, z), fp, extra, bob, period, scale in objs:
    out.append(f'[node name="{name}" type="MeshInstance3D" parent="Buildings"]')
    out.append(f'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x:g}, {y:g}, {z:g})')
    out.append(f'mesh = ExtResource("{ids[mesh]}")')
    out.append('script = ExtResource("4_obj")')
    if fp:
        out.append(f'footprint = Rect2i({fp[0]}, {fp[1]}, {fp[2]}, {fp[3]})')
    if extra:
        out.append('extra_cells = Array[Vector2i]([' + ", ".join(f"Vector2i({a}, {b})" for a, b in extra) + '])')
    if scale != 1.0:
        out.append(f'model_scale = {scale:g}')
    if bob:
        out.append(f'bob_height = {bob:g}')
        out.append(f'bob_period = {period:g}')
    out.append('')
open(OUT_PATH, "w", encoding="utf-8", newline="\n").write("\n".join(out))
print(len(objs), "objects")
