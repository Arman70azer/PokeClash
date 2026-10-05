"""Construit la zone du port, à droite (à l'est) d'Accumula Town.

Usage, depuis le dossier du projet :
    python tools/maps/build_port.py

Écrit dans assets/maps/port/ :
- port.obj / port.mtl : le sol de la zone (route, quais, jetée, pontons) ;
- port_water.obj / .mtl : la mer, à part pour qu'elle ne compte pas dans la grille de
  déplacement (on ne marche pas sur l'eau) et pour pouvoir l'animer.
Ensuite, recalculer la grille :
    godot --headless --import --path .
    godot --headless --path . -s res://tools/maps/bake_map_grid.gd -- res://assets/maps/port/port.obj res://assets/maps/port/port_grid.tres

Le plan de la zone est décrit case par case dans `cell_kind`. Raccord avec Accumula : la
route pavée du bord est d'Accumula continue sur une case avec la même texture et le même
calage, puis une fine bordure de pierre (celle des trottoirs d'Accumula) et directement
le béton du quai. Tout le reste reprend les teintes d'Accumula.
"""

import os
import shutil

from port_mesh import (Mesh, c5, hline, new_texture, rect_fill, rng_for, speckle, vline, write_texture_import)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "maps", "port")
ACCUMULA = os.path.join(ROOT, "assets", "maps", "accumula_town")

TILE = 16
# Hauteurs du sol.
H_ROAD = -3.0     # route d'Accumula
H_QUAY = 0.0      # quai, jetée
H_WOOD = -4.0     # pontons en bois, une marche plus bas
H_WATER = -20.0   # surface de la mer
H_DEEP = -24.0    # bas des murs, sous l'eau

# Étendue de la zone, en cases.
X_MIN, X_MAX = 17, 47
Y_MIN, Y_MAX = -16, 15
QUAY_EDGE = 31            # dernière colonne du quai ; la mer commence après
SEA_X_MAX = 60            # la mer s'étend jusqu'ici (décor)

# Raccord avec Accumula : colonne de la bordure, juste après la route.
CURB_X = 18
# Largeur de la bordure de pierre qui sépare la route d'Accumula du quai, en unités.
CURB_WIDTH = 3
# Grande jetée en bitume pour les gros bateaux.
BIG_PIER_ROWS = range(-10, -4)
BIG_PIER_X = range(QUAY_EDGE + 1, 48)
# Pontons en bois pour les petits bateaux : un passage de trois cases de large et des
# appontements de deux cases.
WALKWAY_ROWS = (2, 3, 4)
WALKWAY_X = range(QUAY_EDGE + 1, 47)
FINGERS = ((36, 37), (42, 43))          # appontements vers le bas
FINGER_ROWS = range(5, 11)
SOUTH_PIER_ROWS = (13, 14, 15)
SOUTH_PIER_X = range(QUAY_EDGE + 1, 45)


def cell_kind(x, y):
    """Nature d'une case : None (mer ou vide), "road", "side" (bordure puis béton), "quay",
    "asph" (bitume), "wood" (ponton), "stairs" (descente vers un ponton)."""
    if not (Y_MIN <= y <= Y_MAX) or x < X_MIN:
        return None
    if x == 17:
        return "road"
    if x == CURB_X:
        return "side"
    if x <= QUAY_EDGE:
        return "quay"
    if y in BIG_PIER_ROWS and x in BIG_PIER_X:
        return "asph"
    for rows, xs in ((WALKWAY_ROWS, WALKWAY_X), (SOUTH_PIER_ROWS, SOUTH_PIER_X)):
        if y in rows and x in xs:
            return "stairs" if x == QUAY_EDGE + 1 else "wood"
    if y in FINGER_ROWS and any(x in f for f in FINGERS):
        return "wood"
    return None


def wood_along_x(x, y):
    """Vrai si le ponton de cette case court d'ouest en est (planches posées nord-sud)."""
    return not (y in FINGER_ROWS and any(x in f for f in FINGERS))


def height(kind):
    return {"road": H_ROAD, "side": H_QUAY, "quay": H_QUAY, "asph": H_QUAY, "wood": H_WOOD,
            "stairs": H_WOOD}[kind]


def is_sea(x, y):
    return cell_kind(x, y) is None and x > QUAY_EDGE and Y_MIN <= y <= Y_MAX and x <= SEA_X_MAX


# --- Textures -----------------------------------------------------------------------------

def tex_concrete():
    """Dalles de béton du quai : même famille de gris que les trottoirs d'Accumula,
    un ton plus froid, joints tous les 16 pixels (une case)."""
    rng = rng_for("concrete")
    img = new_texture(32, 32, c5(25, 25, 24))
    speckle(img, [c5(24, 24, 23), c5(26, 26, 25), c5(24, 24, 22)], 0.10, rng)
    for k in (0, 16):
        hline(img, 0, 32, k, c5(22, 22, 21))
        vline(img, k, 0, 32, c5(22, 22, 21))
        hline(img, 1, 32, k + 1, c5(27, 27, 26))
        vline(img, k + 1, 1, 32, c5(26, 26, 25))
    # Quelques taches et une petite fissure, comme sur les pavés d'Accumula.
    for x, y in ((6, 7), (7, 7), (6, 8), (22, 25), (23, 25), (23, 26), (27, 9)):
        img.putpixel((x, y), c5(23, 23, 22))
    for x, y in ((19, 4), (20, 5), (20, 6), (21, 7), (8, 21), (9, 22), (9, 23)):
        img.putpixel((x, y), c5(22, 22, 21))
    return img


def tex_asphalt():
    rng = rng_for("asphalt")
    img = new_texture(32, 32, c5(13, 13, 15))
    speckle(img, [c5(11, 11, 13), c5(15, 15, 17), c5(12, 12, 14), c5(17, 17, 18)], 0.22, rng)
    return img


def tex_paint(color):
    return new_texture(8, 8, color)


def tex_quay_wall():
    """Mur du quai, du haut (v = 0) jusque sous l'eau : blocs de pierre grise comme les
    murs d'Accumula, puis la bande d'algues au niveau de l'eau."""
    rng = rng_for("quay_wall")
    img = new_texture(32, 32, c5(22, 22, 23))
    speckle(img, [c5(21, 21, 22), c5(23, 23, 24), c5(21, 20, 20)], 0.12, rng)
    for row in range(0, 32, 8):
        hline(img, 0, 32, row, c5(18, 18, 19))
        hline(img, 0, 32, row + 1, c5(24, 24, 25))
        offset = 0 if (row // 8) % 2 == 0 else 8
        for x in range(offset, 32, 16):
            vline(img, x, row, row + 8, c5(18, 18, 19))
    # Traînées d'humidité.
    for x in (5, 13, 26):
        vline(img, x, 10, 16, c5(20, 20, 21))
    # Algues et pierre mouillée sous la ligne d'eau (20 unités sous le haut du mur).
    for x in range(32):
        top = 16 + rng.choice((0, 1, 1, 2))
        vline(img, x, top, 20, rng.choice((c5(11, 15, 11), c5(12, 17, 12), c5(10, 14, 10))))
        vline(img, x, 20, 32, c5(8, 11, 11))
    return img


def tex_wood_deck():
    """Planches du ponton, posées en travers du passage (texture : planches verticales).
    Volontairement sobre : larges planches de deux tons et un simple joint sombre."""
    img = new_texture(32, 32, c5(22, 15, 9))
    for i, x0 in enumerate(range(0, 32, 8)):
        rect_fill(img, x0, 0, x0 + 8, 32, c5(22, 15, 9) if i % 2 == 0 else c5(21, 14, 9))
        vline(img, x0, 0, 32, c5(16, 11, 7))
    return img


def tex_wood_beam():
    img = new_texture(32, 4, c5(17, 12, 7))
    hline(img, 0, 32, 0, c5(20, 14, 9))
    return img


def tex_wood_post():
    """Pieu du ponton, 8 x 32 : bois foncé, mouillé et couvert d'algues en bas."""
    img = new_texture(8, 32, c5(15, 10, 6))
    vline(img, 0, 0, 32, c5(18, 12, 8))
    vline(img, 6, 0, 32, c5(12, 8, 5))
    vline(img, 7, 0, 32, c5(11, 7, 5))
    hline(img, 0, 8, 0, c5(20, 14, 9))
    for y in range(17, 21):
        hline(img, 0, 8, y, c5(11, 15, 10))
    rect_fill(img, 0, 21, 8, 32, c5(8, 10, 9))
    return img


def tex_sea():
    """Mer façon Noir et Blanc : bleu franc, petites crêtes de vagues claires."""
    rng = rng_for("sea")
    img = new_texture(32, 32, c5(9, 18, 28))
    speckle(img, [c5(8, 17, 27), c5(10, 19, 29)], 0.08, rng)
    crests = [(2, 3, 5), (18, 6, 4), (9, 11, 6), (25, 15, 5), (4, 19, 4), (15, 22, 5), (27, 27, 4), (8, 28, 3)]
    for x, y, n in crests:
        hline(img, x, x + n, y, c5(16, 24, 31))
        hline(img, x + 1, x + n + 1, y + 1, c5(7, 15, 25))
        img.putpixel(((x + n // 2) % 32, y), c5(28, 30, 31))
    return img


def tex_foam():
    """Écume le long des murs (transparente entre les vaguelettes)."""
    rng = rng_for("foam")
    img = new_texture(32, 4, (0, 0, 0, 0))
    for x in range(32):
        if rng.random() < 0.75:
            img.putpixel((x, 0), c5(28, 30, 31))
        if rng.random() < 0.45:
            img.putpixel((x, 1), c5(20, 26, 31))
        if rng.random() < 0.15:
            img.putpixel((x, 2), c5(20, 26, 31))
    return img


# --- Géométrie --------------------------------------------------------------------------

# Les dessus débordent très légèrement sur leurs voisins : sans ce recouvrement, un
# rayon de tools/maps/bake_map_grid.gd qui tombe pile sur la jointure de deux dessus peut
# passer entre les deux et faire croire à un trou.
OVERLAP = 0.05


def top_quad(mesh, material, x0, z0, x1, z1, y, rotate=False):
    """Dessus horizontal, texture calée sur le monde (u = x / 32, v = -z / 32), comme
    les sols d'Accumula : les textures se raccordent sans couture d'une zone à l'autre."""
    e = OVERLAP
    pts = [(x0 - e, y, z0 - e), (x1 + e, y, z0 - e), (x1 + e, y, z1 + e), (x0 - e, y, z1 + e)]
    if rotate:
        uvs = [(-z / 32, x / 32) for x, _, z in pts]
    else:
        uvs = [(x / 32, -z / 32) for x, _, z in pts]
    mesh.poly(material, pts, uvs, 1.0)


def strip_quad(mesh, material, x0, z0, x1, z1, y, v_span):
    """Bande horizontale orientée nord-sud (bordure, marche) : la texture court le long
    de la bande (u = -z / 32) et couvre v_span de sa hauteur en travers."""
    e = OVERLAP
    pts = [(x0 - e, y, z0 - e), (x1 + e, y, z0 - e), (x1 + e, y, z1 + e), (x0 - e, y, z1 + e)]
    uvs = [(-z / 32, (x - x0) / (x1 - x0) * v_span) for x, _, z in pts]
    mesh.poly(material, pts, uvs, 1.0)


def wall(mesh, material, a, b, y_top, y_bottom, v_scale=1 / 32):
    """Face verticale de a = (x, z) à b = (x, z), de y_top à y_bottom."""
    (ax, az), (bx, bz) = a, b
    length = abs(bx - ax) + abs(bz - az)
    u0 = (ax + az) / 32
    u1 = u0 + length / 32
    mesh.quad(material, (ax, y_top, az), (bx, y_top, bz), (bx, y_bottom, bz), (ax, y_bottom, az),
              (u0, 0), (u1, 0), (u1, (y_top - y_bottom) * v_scale), (u0, (y_top - y_bottom) * v_scale))


DIRS = {(1, 0): "east", (-1, 0): "west", (0, 1): "south", (0, -1): "north"}


def edge(x, y, d):
    """Segment de bord de la case (x, y) du côté d : ((x, z), (x, z)) dans le monde."""
    x0, z0, x1, z1 = x * TILE, y * TILE, (x + 1) * TILE, (y + 1) * TILE
    return {(1, 0): ((x1, z1), (x1, z0)), (-1, 0): ((x0, z0), (x0, z1)),
            (0, 1): ((x0, z1), (x1, z1)), (0, -1): ((x1, z0), (x0, z0))}[d]


def build_ground():
    mesh = Mesh()
    for y in range(Y_MIN, Y_MAX + 1):
        for x in range(X_MIN, X_MAX + 1):
            kind = cell_kind(x, y)
            if kind is None:
                continue
            h = height(kind)
            x0, z0, x1, z1 = x * TILE, y * TILE, (x + 1) * TILE, (y + 1) * TILE
            if kind == "road":
                top_quad(mesh, "road", x0, z0, x1, z1, h)
            elif kind == "side":
                # Raccord avec Accumula : fine bordure de pierre (celle des trottoirs
                # d'Accumula), la marche qui monte de la route, puis directement le béton.
                strip_quad(mesh, "curb", x0, z0, x0 + CURB_WIDTH, z1, h, CURB_WIDTH / 8)
                top_quad(mesh, "concrete", x0 + CURB_WIDTH, z0, x1, z1, h)
                wall(mesh, "curb", (x0, z0), (x0, z1), h, H_ROAD, 1 / 8)
            elif kind in ("quay", "asph"):
                if kind == "asph" and x == QUAY_EDGE + 1:
                    # Pied de la jetée : fine bande de pierre claire entre le béton du quai
                    # et le bitume.
                    strip_quad(mesh, "curb", x0, z0, x0 + 4, z1, h, 0.5)
                    top_quad(mesh, "asphalt", x0 + 4, z0, x1, z1, h)
                else:
                    top_quad(mesh, "concrete" if kind == "quay" else "asphalt", x0, z0, x1, z1, h)
            elif kind == "wood":
                # Planches en travers du passage : tournées sur les appontements nord-sud.
                top_quad(mesh, "wood_deck", x0, z0, x1, z1, h, rotate=not wood_along_x(x, y))
            elif kind == "stairs":
                # Trois marches de pierre qui descendent du quai jusqu'au ponton.
                steps = 3
                for i in range(steps):
                    sx0 = x0 + i * TILE / steps
                    sx1 = x0 + (i + 1) * TILE / steps
                    sy = H_QUAY - (i + 1) * (H_QUAY - H_WOOD) / steps
                    strip_quad(mesh, "stairs", sx0, z0, sx1, z1, sy, 0.5)
                    prev = H_QUAY - i * (H_QUAY - H_WOOD) / steps
                    wall(mesh, "curb", (sx0, z0), (sx0, z1), prev, sy, 1 / 8)
                    # Flancs de l'escalier au-dessus de l'eau : le mur du quai, marche par marche.
                    for d in ((0, -1), (0, 1)):
                        if is_sea(x, y + d[1]):
                            z = z0 if d[1] < 0 else z1
                            a, b = ((sx1, z), (sx0, z)) if d[1] < 0 else ((sx0, z), (sx1, z))
                            wall(mesh, "quay_wall", a, b, sy, H_DEEP)
            # Bords de la case.
            for d in DIRS:
                n = cell_kind(x + d[0], y + d[1])
                a, b = edge(x, y, d)
                if n is None and is_sea(x + d[0], y + d[1]):
                    if kind in ("quay", "asph", "side"):
                        _quay_edge(mesh, x, y, d, h)
                    elif kind == "wood":
                        _pier_edge(mesh, x, y, d, h)
    return mesh


def _quay_edge(mesh, x, y, d, h):
    """Bord du quai au-dessus de l'eau : margelle de pierre claire (celle des bordures
    d'Accumula), légèrement en relief, et mur de pierre jusque sous l'eau."""
    a, b = edge(x, y, d)
    lip = 1.0
    width = 6.0
    (ax, az), (bx, bz) = a, b
    # Décalage vers l'intérieur de la case.
    ix, iz = -d[0] * width, -d[1] * width
    inner_a = (ax + ix, az + iz)
    inner_b = (bx + ix, bz + iz)
    length = abs(bx - ax) + abs(bz - az)
    u0 = (ax + az) / 32
    mesh.quad("curb", (inner_a[0], h + lip, inner_a[1]), (inner_b[0], h + lip, inner_b[1]),
              (bx, h + lip, bz), (ax, h + lip, az),
              (u0, 0.25), (u0 + length / 32, 0.25), (u0 + length / 32, 1), (u0, 1), 1.0)
    # Contremarche de la margelle côté quai, puis le mur côté mer.
    wall(mesh, "curb", inner_b, inner_a, h + lip, h, 1 / 8)
    wall(mesh, "quay_wall", a, b, h + lip, H_DEEP)


def _pier_edge(mesh, x, y, d, h):
    """Bord d'un ponton en bois : poutre de rive, et pieux plantés dans l'eau aux coins."""
    a, b = edge(x, y, d)
    wall(mesh, "wood_beam", a, b, h, h - 3.0, 1 / 3)
    (ax, az), (bx, bz) = a, b
    ux, uz = (bx - ax) / TILE, (bz - az) / TILE
    # Un pieu une case sur deux seulement, arasé au niveau du ponton : plus sobre.
    if (x + y) % 2:
        return
    for (px, pz), sign in (((ax, az), 1),):
        cx = px - d[0] * 1.5 + ux * 1.5 * sign
        cz = pz - d[1] * 1.5 + uz * 1.5 * sign
        mesh.box("wood_post", cx - 1.5, H_DEEP, cz - 1.5, cx + 1.5, h + 0.5, cz + 1.5,
                 texel=(1 / 8, 1 / 32))


def _foam(mesh, a, b, fa, fb):
    length = abs(b[0] - a[0]) + abs(b[1] - a[1])
    u0 = (a[0] + a[1]) / 32
    y = H_WATER + 0.3
    mesh.quad("foam", (a[0], y, a[1]), (b[0], y, b[1]), (fb[0], y, fb[1]), (fa[0], y, fa[1]),
              (u0, 0), (u0 + length / 32, 0), (u0 + length / 32, 0.75), (u0, 0.75), 1.0)


def build_water():
    mesh = Mesh()
    x0, x1 = (QUAY_EDGE + 1) * TILE - 2, (SEA_X_MAX + 1) * TILE
    z0, z1 = Y_MIN * TILE, (Y_MAX + 1) * TILE
    top_quad(mesh, "sea", x0, z0, x1, z1, H_WATER)
    # Écume le long des quais, dans le même modèle que l'eau.
    foam = Mesh()
    for y in range(Y_MIN, Y_MAX + 1):
        for x in range(X_MIN, X_MAX + 1):
            kind = cell_kind(x, y)
            if kind is None:
                continue
            for d in DIRS:
                if cell_kind(x + d[0], y + d[1]) is None and is_sea(x + d[0], y + d[1]):
                    a, b = edge(x, y, d)
                    w = 2.5 if kind in ("quay", "asph", "side") else 2.0
                    _foam(foam, a, b, (a[0] + d[0] * w, a[1] + d[1] * w), (b[0] + d[0] * w, b[1] + d[1] * w))
    mesh.merge(foam)
    return mesh


def main():
    os.makedirs(OUT, exist_ok=True)
    # Textures d'Accumula réutilisées telles quelles, pour un raccord sans changement de style.
    borrowed = {"road": "Accumula Town_texture_0024.png",
                "curb": "Accumula Town_texture_0026.png", "stairs": "Accumula Town_texture_0006.png"}
    textures = {}
    for material, file in borrowed.items():
        target = f"accumula_{material}.png"
        shutil.copyfile(os.path.join(ACCUMULA, file), os.path.join(OUT, target))
        write_texture_import(os.path.join(OUT, target))
        textures[material] = target
    textures.update({
        "concrete": tex_concrete(), "asphalt": tex_asphalt(), "quay_wall": tex_quay_wall(),
        "wood_deck": tex_wood_deck(), "wood_beam": tex_wood_beam(), "wood_post": tex_wood_post(),
        "paint_yellow": tex_paint(c5(30, 25, 8)),
        "sea": tex_sea(), "foam": tex_foam(),
    })
    ground = build_ground()
    _paint_markings(ground)
    header = "Port, à droite d'Accumula Town. Généré par tools/maps/build_port.py : modifier ce script plutôt que ce fichier."
    ground.write(OUT, "port", textures, header)
    build_water().write(OUT, "port_water", textures, header)
    print("port écrit dans", OUT)


def _paint_markings(mesh):
    """Marquages au sol de la jetée."""
    y = H_QUAY + 0.05
    # Lignes de sécurité jaunes le long des bords de la jetée, où accostent les gros bateaux.
    pier = list(BIG_PIER_ROWS)
    x0, x1 = (QUAY_EDGE + 1) * TILE + 8, (BIG_PIER_X[-1] - 3) * TILE
    for z in (pier[0] * TILE + 8, (pier[-1] + 1) * TILE - 9.5):
        mesh.quad("paint_yellow", (x0, y, z), (x1, y, z), (x1, y, z + 1.5), (x0, y, z + 1.5),
                  (0, 0), (1, 0), (1, 1), (0, 1), 1.0)


if __name__ == "__main__":
    main()
