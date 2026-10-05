"""Kit de la forêt des expéditions, tiré de Lostlorn Forest (Noir 2 / Blanc 2) et des objets
voisins : arbres, hautes herbes et souche en 3D, planche de tuiles du sol.

Dans la carte d'origine, les arbres ne sont pas des objets séparés : chaque couche (ombre
au sol, sapin en plans croisés, feuillages vus de dessus) est un grand rectangle dont la
texture se répète, un arbre tous les 32 unités (2 cases) ou 48 unités (3 cases, arbres
sombres). On découpe donc un arbre de chaque sorte : on garde les triangles de ses couches
dans son carré, rognés aux bords (UV et couleurs interpolées). L'arbre sombre est réduit à
2 cases, pour suivre la même grille que les autres (ses textures retombent alors à un
pixel par unité, comme le reste).

    python tools/maps/build_forest_kit.py

Écrit dans assets/maps/lostlorn_forest/ : forest_tree_light.obj, forest_tree_dark.obj,
forest_tall_grass.obj, forest_stump.obj (+ .mtl) et forest_ground.png ; convertit aussi
les troncs couchés et la souche creuse (assets/mapobjects/dead_tree_01, dead_tree_02,
stump_2). Chaque objet a son origine au milieu de son emprise, au niveau du sol.
"""
import os
import sys
import tempfile

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dae_to_obj  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "source_assets")
FOREST = os.path.join(ROOT, "assets", "maps", "lostlorn_forest")
TEX = "Lostlorn Forest_texture_%s.png"

# Pièces découpées : nom -> (couches, carré (x0, z0, x1, z1) dans la carte, échelle).
PIECES = {
    "forest_tree_light": (["ki02ax", "ki02bx", "ki02c", "ki02dx"], (-288, -64, -256, -32), 1.0),
    "forest_tree_dark": (["ki00a2", "ki00b2", "ki00c2", "ki00d2"], (320, -176, 368, -128), 2.0 / 3.0),
    "forest_tall_grass": (["kusa_ec1", "kusa_ec2"], (0, 386, 16, 402), 1.0),
    "forest_stump": (["stump_01_01", "stump_01_02", "h_kage"], (-150, -134, -90, -74), 1.0),
}
# Objets séparés : dossier de source_assets/mapobjects -> (fichier .dae, nom du .obj).
OBJECTS = {
    "dead_tree_01": ("dtree_01.dae", "dead_tree_01"),
    "dead_tree_02": ("dtree_02.dae", "dead_tree_02"),
    "stump_2": ("stump_02.dae", "stump_2"),
}


def read_obj(path):
    """Sommets (x, y, z, r, g, b), UV, et faces par matériau [(sommet, uv) x 3]."""
    verts, uvs, faces, current = [], [], {}, None
    with open(path, encoding="utf-8") as f:
        for line in f:
            p = line.split()
            if not p:
                continue
            if p[0] == "v":
                values = [float(t) for t in p[1:]]
                verts.append(tuple(values + [1.0, 1.0, 1.0][len(values) - 3:]) if len(values) < 6 else tuple(values[:6]))
            elif p[0] == "vt":
                uvs.append((float(p[1]), float(p[2])))
            elif p[0] == "usemtl":
                current = p[1]
            elif p[0] == "f":
                corners = []
                for c in p[1:]:
                    parts = c.split("/")
                    corners.append((int(parts[0]) - 1, int(parts[1]) - 1 if len(parts) > 1 and parts[1] else -1))
                faces.setdefault(current, []).append(corners)
    return verts, uvs, faces


def read_mtl(path):
    textures, current = {}, None
    with open(path, encoding="utf-8") as f:
        for line in f:
            p = line.split(maxsplit=1)
            if p and p[0] == "newmtl":
                current = p[1].strip()
            elif p and p[0] == "map_Kd":
                textures[current] = p[1].strip()
    return textures


def clip(poly, axis, limit, keep_above):
    """Rogne un polygone (points = (pos, uv, couleur)) par le plan pos[axis] = limit."""
    def inside(pt):
        return pt[0][axis] >= limit if keep_above else pt[0][axis] <= limit

    def cut(a, b):
        t = (limit - a[0][axis]) / (b[0][axis] - a[0][axis])
        lerp = lambda u, v: tuple(x + (y - x) * t for x, y in zip(u, v))  # noqa: E731
        return (lerp(a[0], b[0]), lerp(a[1], b[1]), lerp(a[2], b[2]))

    out = []
    for i, cur in enumerate(poly):
        prev = poly[i - 1]
        if inside(cur):
            if not inside(prev):
                out.append(cut(prev, cur))
            out.append(cur)
        elif inside(prev):
            out.append(cut(prev, cur))
    return out


def extract(verts, uvs, faces, layers, box, scale, floor=0.0):
    """Triangles des couches dans le carré, recentrés et mis à l'échelle ; `floor` : hauteur
    du sol dans la carte (ramenée à 0)."""
    x0, z0, x1, z1 = box
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    out = {}
    for layer in layers:
        for face in faces.get(layer, []):
            poly = [((verts[v][0], verts[v][1], verts[v][2]), uvs[t] if t >= 0 else (0.0, 0.0), verts[v][3:6])
                    for v, t in face]
            xs = [pt[0][0] for pt in poly]
            zs = [pt[0][2] for pt in poly]
            # Plan vertical posé sur le bord droit ou bas : il appartient au carré voisin.
            if (max(xs) - min(xs) < 1e-6 and abs(xs[0] - x1) < 1e-6) or (max(zs) - min(zs) < 1e-6 and abs(zs[0] - z1) < 1e-6):
                continue
            for axis, limit, above in ((0, x0, True), (0, x1, False), (2, z0, True), (2, z1, False)):
                poly = clip(poly, axis, limit, above)
                if len(poly) < 3:
                    break
            if len(poly) < 3:
                continue
            placed = [(((p[0] - cx) * scale, (p[1] - floor) * scale, (p[2] - cz) * scale), uv, col) for p, uv, col in poly]
            for k in range(1, len(placed) - 1):
                out.setdefault(layer, []).append((placed[0], placed[k], placed[k + 1]))
    return out


def write_obj(path, by_material, textures, comment):
    base = os.path.splitext(os.path.basename(path))[0]
    lines = ["# " + comment, "mtllib %s.mtl" % base]
    mtl = []
    index = 1
    for material, tris in by_material.items():
        mtl += ["newmtl %s" % material, "Kd 1 1 1", "d 1", "map_Kd %s" % textures[material], ""]
        lines.append("usemtl %s" % material)
        for tri in tris:
            for pos, uv, col in tri:
                lines.append("v %.4f %.4f %.4f %.4f %.4f %.4f" % (pos + tuple(col)))
                lines.append("vt %.5f %.5f" % uv)
            lines.append("f %d/%d %d/%d %d/%d" % (index, index, index + 1, index + 1, index + 2, index + 2))
            index += 3
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    with open(path[:-4] + ".mtl", "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(mtl))


def ground_sheet():
    """Planche du sol, en cases de 16 : l'herbe (4 x 4 cases qui se répètent), puis des
    détails à fond transparent (fleurs, touffes, terre)."""
    def tex(n):
        return Image.open(os.path.join(FOREST, TEX % n)).convert("RGBA")
    sheet = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    sheet.paste(tex("0001"), (0, 0))           # herbe : cases (0, 0) à (3, 3)
    sheet.paste(tex("00010"), (64, 0))         # fleurs : (4, 0)
    sheet.paste(tex("0005"), (64, 16))         # petites pousses : (4, 1)
    sheet.paste(tex("0009"), (64, 32))         # brins d'herbe : (4, 2) et (4, 3)
    sheet.paste(tex("0003"), (80, 0))          # terre : (5, 0) à (6, 1)
    sheet.paste(tex("0004"), (96, 32))         # terre éparse : (6, 2) à (7, 3)
    sheet.save(os.path.join(FOREST, "forest_ground.png"))


def main():
    with tempfile.TemporaryDirectory() as tmp:
        dae_to_obj.main(os.path.join(SOURCE, "maps", "lostlorn_forest", "Lostlorn Forest.dae"), "lostlorn", tmp)
        verts, uvs, faces = read_obj(os.path.join(tmp, "lostlorn.obj"))
        textures = read_mtl(os.path.join(tmp, "lostlorn.mtl"))
    for name, (layers, box, scale) in PIECES.items():
        pieces = extract(verts, uvs, faces, layers, box, scale)
        write_obj(os.path.join(FOREST, name + ".obj"), pieces, textures,
                  "Découpé dans Lostlorn Forest par tools/maps/build_forest_kit.py")
        print(name, sum(len(t) for t in pieces.values()), "triangles")
    for folder, (dae, name) in OBJECTS.items():
        dae_to_obj.main(os.path.join(SOURCE, "mapobjects", folder, dae), name,
                        os.path.join(ROOT, "assets", "mapobjects", folder))
    ground_sheet()


if __name__ == "__main__":
    main()
