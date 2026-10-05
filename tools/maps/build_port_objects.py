"""Construit les objets 3D du port : bateaux, bouées, bittes d'amarrage, caisses...

Usage, depuis le dossier du projet :
    python tools/maps/build_port_objects.py
puis importer les nouveaux fichiers (ouvrir le projet dans Godot, ou
    godot --headless --import --path .).

Chaque objet est écrit dans assets/mapobjects/port/<nom>/<nom>.obj avec son .mtl et ses
textures. Style : celui des objets de Noir et Blanc déjà présents (modèles simples,
petites textures en pixel art, ombrage peint dans les couleurs de sommets).
Origine de chaque modèle : centre de sa base, au niveau du sol (ou de l'eau pour ce qui
flotte). Les bateaux sont modélisés proue vers la droite (+X) ; la variante « _v » a la
proue vers le bas de la carte (+Z), pour les amarrer le long des pontons nord-sud.
"""

import math
import os

from port_mesh import Mesh, c5, hline, new_texture, rect_fill, rng_for, speckle, vline

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "mapobjects", "port")
HEADER = "Objet du port. Généré par tools/maps/build_port_objects.py : modifier ce script plutôt que ce fichier."


# --- Textures communes -----------------------------------------------------------------

def tex_flat(color, w=8, h=8):
    return new_texture(w, h, color)


def tex_iron():
    img = new_texture(8, 8, c5(7, 8, 10))
    vline(img, 1, 0, 8, c5(11, 12, 15))
    vline(img, 2, 0, 8, c5(9, 10, 12))
    hline(img, 0, 8, 0, c5(12, 13, 16))
    return img


def tex_boat_deck():
    """Pont en bois clair (teck), planches dans la longueur du bateau."""
    rng = rng_for("boat_deck")
    img = new_texture(32, 32, c5(24, 18, 11))
    for y in range(0, 32, 3):
        hline(img, 0, 32, y, c5(18, 13, 8))
    speckle(img, [c5(22, 16, 10), c5(25, 19, 12)], 0.08, rng)
    for y in range(1, 32, 6):
        img.putpixel(((y * 7) % 32, y), c5(18, 13, 8))
    return img


def tex_cabin(wall, window=c5(6, 10, 17), w=32, h=16, band=(5, 10)):
    """Mur de cabine avec une rangée de fenêtres."""
    img = new_texture(w, h, wall)
    hline(img, 0, w, 0, c5(31, 31, 31))
    hline(img, 0, w, h - 1, c5(20, 20, 21))
    y0, y1 = band
    for x0 in range(2, w, 8):
        rect_fill(img, x0, y0, x0 + 5, y1, window)
        hline(img, x0, x0 + 5, y0, c5(16, 17, 19))
        img.putpixel((x0 + 1, y0 + 1), c5(20, 25, 30))
        img.putpixel((x0 + 2, y0 + 1), c5(14, 19, 26))
    return img


def tex_hull(colors, w=32, h=32):
    """Flanc de coque, du haut (ligne 0) jusque sous la flottaison (dernière ligne) :
    `colors` = [(ligne de début, couleur), ...] dans l'ordre."""
    img = new_texture(w, h, colors[0][1])
    for i, (row, color) in enumerate(colors):
        end = colors[i + 1][0] if i + 1 < len(colors) else h
        rect_fill(img, 0, row, w, end, color)
    return img


def tex_sail():
    img = new_texture(32, 32, c5(30, 30, 28))
    for y in range(3, 32, 7):
        hline(img, 0, 32, y, c5(26, 26, 25))
    vline(img, 0, 0, 32, c5(25, 25, 24))
    return img


def tex_railing():
    """Bastingage : main courante, lisse du milieu et montants ; transparent ailleurs."""
    img = new_texture(32, 8, (0, 0, 0, 0))
    hline(img, 0, 32, 0, c5(31, 31, 31))
    hline(img, 0, 32, 1, c5(24, 24, 25))
    hline(img, 0, 32, 4, c5(28, 28, 29))
    for x in range(0, 32, 4):
        vline(img, x, 0, 8, c5(27, 27, 28))
    return img


def tex_crate():
    img = new_texture(16, 16, c5(23, 17, 10))
    for y in range(0, 16, 4):
        hline(img, 0, 16, y, c5(19, 13, 8))
    rect_fill(img, 0, 0, 16, 2, c5(17, 12, 7))
    rect_fill(img, 0, 14, 16, 16, c5(17, 12, 7))
    rect_fill(img, 0, 0, 2, 16, c5(17, 12, 7))
    rect_fill(img, 14, 0, 16, 16, c5(17, 12, 7))
    for i in range(2, 14):
        img.putpixel((i, i), c5(16, 11, 6))
        img.putpixel((i, min(15, i + 1)), c5(20, 14, 8))
    for x, y in ((1, 1), (14, 1), (1, 14), (14, 14)):
        img.putpixel((x, y), c5(9, 8, 7))
    return img


def tex_barrel(color, band):
    img = new_texture(16, 16, color)
    for y in (2, 3, 12, 13):
        hline(img, 0, 16, y, band)
    vline(img, 3, 0, 16, tuple(min(255, v + 30) for v in color[:3]) + (255,))
    vline(img, 4, 0, 16, tuple(min(255, v + 15) for v in color[:3]) + (255,))
    hline(img, 0, 16, 0, c5(8, 8, 9))
    return img


def tex_container():
    """Tôle ondulée claire : la couleur du conteneur vient de la teinte des sommets."""
    img = new_texture(32, 16, c5(28, 28, 28))
    for x in range(0, 32, 2):
        vline(img, x, 1, 15, c5(23, 23, 23))
    hline(img, 0, 32, 0, c5(31, 31, 31))
    hline(img, 0, 32, 15, c5(18, 18, 18))
    for x in (0, 31):
        vline(img, x, 0, 16, c5(18, 18, 18))
    return img


def tex_buoy_body(color, band):
    """Corps de bouée, 8 x 32 : couleur, bande blanche réfléchissante, flotteur sombre."""
    img = new_texture(8, 32, color)
    rect_fill(img, 0, 9, 8, 13, band)
    rect_fill(img, 0, 24, 8, 32, tuple(max(0, v - 50) for v in color[:3]) + (255,))
    vline(img, 1, 0, 32, tuple(min(255, v + 35) for v in img.getpixel((1, 0))[:3]) + (255,))
    return img


def tex_lamp_glass():
    img = new_texture(8, 8, c5(31, 29, 17))
    rect_fill(img, 0, 0, 8, 1, c5(31, 31, 26))
    vline(img, 0, 0, 8, c5(28, 24, 10))
    vline(img, 7, 0, 8, c5(28, 24, 10))
    return img


def tex_rope():
    img = new_texture(8, 8, c5(26, 22, 14))
    for i in range(8):
        img.putpixel((i, i), c5(20, 16, 9))
    return img


# --- Formes ----------------------------------------------------------------------------

def hull(mesh, length, beam, freeboard, draft, side="hull", deck="deck", bow=0.32, stern=0.86,
         sheer=0.3, stations=14, bulwark=0.0, inner="hull_inner", deck_inset=1.0):
    """Coque de bateau, proue vers +X, flottaison à y = 0.
    `bulwark` > 0 : pont abaissé de cette hauteur, avec la face intérieure du pavois
    (barque, voilier). Renvoie la hauteur du pont."""
    half = length / 2
    total = freeboard + draft

    def width(t):
        if t <= 1 - bow:
            return beam / 2 * (stern + (1 - stern) * min(1.0, t / 0.25))
        s = (t - (1 - bow)) / bow
        return beam / 2 * math.sqrt(max(0.0, 1 - s * s))

    def top(t):
        return freeboard + sheer * freeboard * max(0.0, (t - (1 - bow)) / bow) ** 2

    def v(y):
        return min(1.0, max(0.0, (freeboard - y) / total))

    rows = []
    for i in range(stations + 1):
        t = i / stations
        x = -half + length * t
        w = width(t)
        rows.append((x, w, top(t)))
    deck_y = freeboard - bulwark
    for sign in (1, -1):
        for (xa, wa, ta), (xb, wb, tb) in zip(rows, rows[1:]):
            levels_a = [(ta, wa), (0.0, wa * 0.96), (-draft, wa * 0.55)]
            levels_b = [(tb, wb), (0.0, wb * 0.96), (-draft, wb * 0.55)]
            for k in range(2):
                (ya0, wa0), (ya1, wa1) = levels_a[k], levels_a[k + 1]
                (yb0, wb0), (yb1, wb1) = levels_b[k], levels_b[k + 1]
                pts = [(xa, ya0, sign * wa0), (xb, yb0, sign * wb0), (xb, yb1, sign * wb1), (xa, ya1, sign * wa1)]
                uvs = [(sign * xa / 32, v(ya0)), (sign * xb / 32, v(yb0)), (sign * xb / 32, v(yb1)),
                       (sign * xa / 32, v(ya1))]
                if sign < 0:
                    pts = [pts[1], pts[0], pts[3], pts[2]]
                    uvs = [uvs[1], uvs[0], uvs[3], uvs[2]]
                mesh.poly(side, pts, uvs)
            if bulwark > 0:
                # Face intérieure du pavois, tournée vers le pont.
                ia, ib = max(0.0, wa - deck_inset), max(0.0, wb - deck_inset)
                pts = [(xb, tb, sign * ib), (xa, ta, sign * ia), (xa, deck_y, sign * ia), (xb, deck_y, sign * ib)]
                uvs = [(xb / 32, 0), (xa / 32, 0), (xa / 32, bulwark / 16), (xb / 32, bulwark / 16)]
                if sign < 0:
                    pts = [pts[1], pts[0], pts[3], pts[2]]
                    uvs = [uvs[1], uvs[0], uvs[3], uvs[2]]
                mesh.poly(inner, pts, uvs)
                # Lisse : le dessus du pavois.
                rim = [(xa, ta, sign * wa), (xb, tb, sign * wb), (xb, tb, sign * ib), (xa, ta, sign * ia)]
                mesh.poly(inner, rim, [(xa / 32, 0), (xb / 32, 0), (xb / 32, 0.05), (xa / 32, 0.05)], 1.0)
    # Tableau arrière.
    x, w, t = rows[0]
    levels = [(t, w), (0.0, w * 0.96), (-draft, w * 0.55)]
    for k in range(2):
        (y0, w0), (y1, w1) = levels[k], levels[k + 1]
        pts = [(x, y0, -w0), (x, y0, w0), (x, y1, w1), (x, y1, -w1)]
        mesh.poly(side, pts, [(-w0 / 32, v(y0)), (w0 / 32, v(y0)), (w1 / 32, v(y1)), (-w1 / 32, v(y1))])
    # Pont : contour intérieur, à la hauteur du pont.
    inset = deck_inset if bulwark > 0 else 0.0
    outline = [(x, max(0.0, w - inset)) for x, w, _ in rows]
    pts = [(x, deck_y if bulwark > 0 else t, w) for (x, w), (_, _, t) in zip(outline, rows)]
    pts += [(x, deck_y if bulwark > 0 else t, -w) for (x, w), (_, _, t) in reversed(list(zip(outline, rows)))]
    mesh.poly(deck, pts, [(p[0] / 32, -p[2] / 32) for p in pts], 1.0)
    return deck_y


def railing(mesh, points, y, height=5.0, material="railing"):
    """Bastingage le long d'une ligne brisée (x, z), à la hauteur y."""
    for (xa, za), (xb, zb) in zip(points, points[1:]):
        length = math.hypot(xb - xa, zb - za)
        u0 = 0
        mesh.poly(material, [(xa, y + height, za), (xb, y + height, zb), (xb, y, zb), (xa, y, za)],
                  [(u0, 0), (length / 32, 0), (length / 32, height / 8), (u0, height / 8)])


def ring(mesh, cx, cy, cz, outer, inner, thickness, segments, materials):
    """Anneau vertical face à la caméra (bouée de sauvetage), segments colorés en alternance."""
    for i in range(segments):
        a0 = 2 * math.pi * i / segments
        a1 = 2 * math.pi * (i + 1) / segments
        mat = materials[(i * len(materials) * 2 // segments) % len(materials)]

        def p(a, r, z):
            return (cx + math.cos(a) * r, cy + math.sin(a) * r, cz + z)
        f, b = thickness / 2, -thickness / 2
        uv = [(0, 0), (1, 0), (1, 1), (0, 1)]
        mesh.poly(mat, [p(a1, outer, f), p(a0, outer, f), p(a0, inner, f), p(a1, inner, f)], uv)
        mesh.poly(mat, [p(a0, outer, b), p(a1, outer, b), p(a1, inner, b), p(a0, inner, b)], uv)
        mesh.poly(mat, [p(a0, outer, b), p(a0, outer, f), p(a1, outer, f), p(a1, outer, b)], uv)
        mesh.poly(mat, [p(a1, inner, b), p(a1, inner, f), p(a0, inner, f), p(a0, inner, b)], uv)


# --- Objets ----------------------------------------------------------------------------

def bollard():
    """Bitte d'amarrage en fonte, avec un tour d'amarre."""
    m = Mesh()
    m.cylinder("iron", 0, 0, 3.4, 0, 1.5, sides=8, cap=False, v_range=(0, 1))
    m.cylinder("iron", 0, 0, 2.6, 1.5, 6, sides=8, cap=False, v_range=(0, 1))
    m.cylinder("iron", 0, 0, 2.6, 6, 7.5, sides=8, radius_top=4.2, cap=False, v_range=(0, 1))
    m.cylinder("iron", 0, 0, 4.2, 7.5, 8.5, sides=8, v_range=(0, 1))
    m.cylinder("rope", 0, 0, 3.0, 3.0, 4.5, sides=8, cap=False, v_range=(0, 1))
    return m, {"iron": tex_iron(), "rope": tex_rope()}


def life_buoy():
    """Bouée de sauvetage accrochée à son poteau."""
    m = Mesh()
    m.box("post", -1.2, 0, -1.2, 1.2, 20, 1.2, texel=1 / 8)
    m.box("post", -3, 18, -2, 3, 21, 1.5, texel=1 / 8)
    ring(m, 0, 11, 2.4, 5.5, 3.0, 2.2, 16, ["buoy_red", "buoy_white"])
    return m, {"post": tex_cabin(c5(27, 27, 27), w=8, h=8, band=(3, 3)),
               "buoy_red": tex_flat(c5(29, 7, 5)), "buoy_white": tex_flat(c5(30, 30, 30))}


def nav_buoy(color_name):
    """Bouée de chenal flottante (rouge à bâbord, verte à tribord) avec son feu."""
    m = Mesh()
    body = "body"
    m.cylinder(body, 0, 0, 6.0, -4, 2, sides=10, v_range=(24 / 32, 1), cap=True)
    m.cylinder(body, 0, 0, 4.4, 2, 13, sides=10, radius_top=3.4, v_range=(0, 24 / 32))
    for dx, dz in ((-2.2, -2.2), (2.2, -2.2), (2.2, 2.2), (-2.2, 2.2)):
        m.box("metal", dx - 0.4, 13, dz - 0.4, dx + 0.4, 21, dz + 0.4, texel=1 / 8)
    m.box("metal", -2.6, 21, -2.6, 2.6, 22, 2.6, texel=1 / 8)
    m.box("lamp", -1.2, 22, -1.2, 1.2, 25, 1.2, texel=1 / 8)
    if color_name == "red":
        m.cylinder("topmark", 0, 0, 1.6, 25, 28, sides=8)
        color = c5(28, 6, 5)
    else:
        m.cylinder("topmark", 0, 0, 2.2, 25, 29, sides=8, radius_top=0.1, cap=False)
        color = c5(4, 20, 8)
    return m, {"body": tex_buoy_body(color, c5(30, 30, 30)), "metal": tex_iron(),
               "lamp": tex_lamp_glass(), "topmark": tex_flat(color)}


def crates():
    m = Mesh()
    m.box("crate", -7.5, 0, -7, 6, 13, 6, texel=1 / 16)
    m.box("crate", -4, 13, -5, 6, 22, 5, texel=1 / 16)
    return m, {"crate": tex_crate()}


def crates_big():
    m = Mesh()
    for x in (-15, -1):
        m.box("crate", x, 0, -7, x + 14, 13, 6, texel=1 / 16)
    m.box("crate", -9, 13, -6, 4, 25, 5, texel=1 / 16)
    m.box("crate", 6, 0, -2, 14, 8, 6, texel=1 / 16)
    return m, {"crate": tex_crate()}


def barrels():
    m = Mesh()
    for (x, z, mat) in ((-3.5, -2.5, "barrel_blue"), (3.5, -2.5, "barrel_red"), (0, 3.5, "barrel_blue")):
        m.cylinder(mat, x, z, 4.0, 0, 12, sides=10, v_range=(0, 1), top_material="barrel_top")
    return m, {"barrel_blue": tex_barrel(c5(6, 11, 22), c5(4, 7, 15)),
               "barrel_red": tex_barrel(c5(24, 7, 5), c5(15, 4, 3)),
               "barrel_top": tex_flat(c5(9, 10, 12))}


def container(tint):
    """Conteneur maritime de deux cases sur une ; la couleur vient de `tint`."""
    m = Mesh()
    m.box("container", -15.5, 0, -7.5, 15.5, 15, 7.5, texel=(1 / 32, 1 / 16), tint=tint)
    return m, {"container": tex_container()}


def containers_stack():
    m = Mesh()
    m.box("container", -15.5, 0, -7.5, 15.5, 15, 7.5, texel=(1 / 32, 1 / 16), tint=(0.95, 0.38, 0.30))
    m.box("container", -15.5, 0, 8.5, 15.5, 15, 23.5, texel=(1 / 32, 1 / 16), tint=(0.35, 0.55, 0.95))
    m.box("container", -15.5, 15, -7.5, 15.5, 30, 7.5, texel=(1 / 32, 1 / 16), tint=(0.45, 0.80, 0.45))
    return m, {"container": tex_container()}


def lamppost():
    m = Mesh()
    m.cylinder("iron", 0, 0, 2.6, 0, 3, sides=8, v_range=(0, 1))
    m.cylinder("iron", 0, 0, 1.1, 3, 38, sides=6, v_range=(0, 1), cap=False)
    m.box("iron", -2.6, 38, -2.6, 2.6, 39, 2.6, texel=1 / 8)
    m.box("lamp", -2.2, 39, -2.2, 2.2, 45, 2.2, texel=1 / 8)
    m.box("iron", -3, 45, -3, 3, 46.5, 3, texel=1 / 8)
    m.cylinder("iron", 0, 0, 2.2, 46.5, 49, sides=6, radius_top=0.3, cap=False, v_range=(0, 1))
    return m, {"iron": tex_iron(), "lamp": tex_lamp_glass()}


def rowboat():
    """Petite barque en bois peinte en bleu, avec deux bancs et ses rames."""
    m = Mesh()
    deck = hull(m, 30, 12, 4.5, 2.0, side="hull", deck="floor", bow=0.4, stern=0.7, sheer=0.5,
                bulwark=3.0, inner="inner", deck_inset=1.2)
    for x in (-6, 4):
        m.box("inner", x - 1.5, deck, -4.6, x + 1.5, deck + 2.0, 4.6, texel=1 / 16)
    for sign in (1, -1):
        m.box("oar", -10, 4.6, sign * 5.6 - 0.4, 6, 5.2, sign * 5.6 + 0.4, texel=1 / 16)
        m.box("oar", 6, 4.4, sign * 5.6 - 1.2, 10, 5.0, sign * 5.6 + 1.2, texel=1 / 16)
    hull_tex = tex_hull([(0, c5(29, 29, 27)), (3, c5(7, 13, 22)), (21, c5(5, 9, 16)), (28, c5(12, 9, 6))])
    for y in (8, 13, 18):
        hline(hull_tex, 0, 32, y, c5(5, 10, 18))
    return m, {"hull": hull_tex, "floor": tex_boat_deck(), "inner": tex_flat(c5(22, 16, 10)),
               "oar": tex_flat(c5(25, 20, 12))}


def fishing_boat():
    """Chalutier : coque blanche à liseré bleu, timonerie, mât et treuil à filets."""
    m = Mesh()
    deck = hull(m, 58, 20, 8, 5, side="hull", deck="deck", bow=0.34, stern=0.82, sheer=0.45,
                bulwark=2.5, inner="inner", deck_inset=1.2)
    # Timonerie vers l'arrière, toit bleu.
    m.box("cabin", -14, deck, -6, 2, deck + 12, 6, texel=(1 / 32, 1 / 16), materials={"top": "roof"})
    m.box("roof", -15, deck + 12, -7, 3, deck + 13.5, 7, texel=1 / 16)
    # Mât, vergue et feu.
    m.cylinder("mast", 10, 0, 0.9, deck, deck + 34, sides=6, cap=False, v_range=(0, 1))
    m.box("mast", 9.4, deck + 26, -7, 10.6, deck + 27, 7, texel=1 / 8)
    m.box("lamp", 9, deck + 34, -1, 11, deck + 36, 1, texel=1 / 8)
    # Treuil à filets à l'arrière, et une bouée sur la timonerie.
    m.cylinder("net", -20, 0, 3.5, deck, deck + 6, sides=8, v_range=(0, 1), top_material="iron")
    ring(m, -6, deck + 7, 6.6, 3.0, 1.6, 1.2, 12, ["buoy_red", "buoy_white"])
    hull_tex = tex_hull([(0, c5(30, 30, 29)), (2, c5(28, 28, 27)), (11, c5(5, 11, 22)), (14, c5(28, 28, 27)),
                         (17, c5(21, 6, 5))])
    hline(hull_tex, 0, 32, 1, c5(31, 31, 31))
    return m, {"hull": hull_tex, "deck": tex_boat_deck(), "inner": tex_flat(c5(26, 26, 25)),
               "cabin": tex_cabin(c5(29, 29, 28)), "roof": tex_flat(c5(6, 12, 23)),
               "mast": tex_flat(c5(28, 28, 28)), "lamp": tex_lamp_glass(), "iron": tex_iron(),
               "net": tex_flat(c5(9, 16, 10)), "buoy_red": tex_flat(c5(29, 8, 5)),
               "buoy_white": tex_flat(c5(30, 30, 30))}


def sailboat():
    """Voilier de plaisance : coque blanche, pont en teck, grand-voile et foc."""
    m = Mesh()
    deck = hull(m, 60, 17, 6, 4, side="hull", deck="deck", bow=0.4, stern=0.9, sheer=0.35,
                bulwark=1.2, inner="inner", deck_inset=0.8)
    m.box("cabin", -12, deck, -5, 8, deck + 5, 5, texel=(1 / 32, 1 / 16), materials={"top": "cabin_top"})
    mast_x = 4
    m.cylinder("mast", mast_x, 0, 0.8, deck, deck + 64, sides=6, cap=False, v_range=(0, 1))
    # Grand-voile (entre mât et bôme) et foc (entre mât et étrave). Les voiles sont
    # bordées de biais, comme sous le vent : vues de face, elles ne disparaîtraient pas
    # quand le bateau est amarré dans l'axe de la caméra.
    def trim(points, angle):
        a = math.radians(angle)
        return [(mast_x + (x - mast_x) * math.cos(a), y, z + (x - mast_x) * math.sin(a)) for x, y, z in points]
    m.poly("sail", trim([(mast_x, deck + 62, 0.3), (mast_x - 0.5, deck + 11, 0.3), (-19, deck + 11, 0.3)], 32),
           [(0.9, 0), (0.9, 1.6), (0, 1.6)])
    m.poly("sail", trim([(mast_x + 0.6, deck + 52, -0.3), (28, deck + 3, -0.3), (mast_x + 1, deck + 5, -0.3)], -22),
           [(0.1, 0), (1.0, 1.5), (0.1, 1.5)])
    # La bôme suit la grand-voile.
    (bx0, _, bz0), (bx1, _, bz1) = trim([(-20, 0, 0), (mast_x, 0, 0)], 32)
    for y0, y1 in ((deck + 9, deck + 10.2),):
        m.poly("mast", [(bx0, y1, bz0 - 0.6), (bx1, y1, bz1 - 0.6), (bx1, y1, bz1 + 0.6), (bx0, y1, bz0 + 0.6)],
               [(0, 0), (1, 0), (1, 1), (0, 1)], 1.0)
        m.poly("mast", [(bx0, y1, bz0 + 0.6), (bx1, y1, bz1 + 0.6), (bx1, y0, bz1 + 0.6), (bx0, y0, bz0 + 0.6)],
               [(0, 0), (1, 0), (1, 1), (0, 1)])
    hull_tex = tex_hull([(0, c5(30, 30, 30)), (13, c5(3, 6, 15)), (17, c5(30, 30, 30)), (19, c5(4, 7, 16))])
    hline(hull_tex, 0, 32, 1, c5(26, 26, 27))
    return m, {"hull": hull_tex, "deck": tex_boat_deck(), "inner": tex_flat(c5(28, 28, 28)),
               "cabin": tex_cabin(c5(29, 29, 29), band=(4, 8)), "cabin_top": tex_flat(c5(27, 27, 26)),
               "mast": tex_flat(c5(26, 26, 28)), "sail": tex_sail()}


def ferry():
    """Grand ferry (20 cases de long) : coque blanche à bande marine, trois ponts de
    cabines vitrées, passerelle de commandement, deux cheminées rouges et canots de
    sauvetage orange."""
    m = Mesh()
    length, beam, freeboard = 320, 80, 30
    deck = hull(m, length, beam, freeboard, 10, side="hull", deck="deck", bow=0.26, stern=0.93, sheer=0.22,
                stations=24)
    # Ponts de cabines, en retrait les uns des autres.
    m.box("windows", -136, deck, -32, 92, deck + 15, 32, texel=(1 / 32, 1 / 16), materials={"top": "deck"})
    m.box("windows", -112, deck + 15, -27, 70, deck + 29, 27, texel=(1 / 32, 1 / 16), materials={"top": "deck"})
    m.box("windows", -84, deck + 29, -21, 44, deck + 41, 21, texel=(1 / 32, 1 / 16), materials={"top": "deck"})
    # Passerelle de commandement, plus large que le navire, avec ses ailerons.
    m.box("bridge", 44, deck + 29, -40, 64, deck + 41, 40, texel=(1 / 32, 1 / 16), materials={"top": "deck"})
    m.box("white", 43, deck + 41, -41, 65, deck + 43, 41, texel=1 / 8)
    m.cylinder("mast", 52, 0, 1.2, deck + 43, deck + 66, sides=6, cap=False, v_range=(0, 1))
    m.box("mast", 51.4, deck + 58, -10, 52.6, deck + 59, 10, texel=1 / 8)
    m.box("lamp", 51, deck + 66, -1, 53, deck + 68, 1, texel=1 / 8)
    # Deux cheminées.
    for x in (-74, -46):
        m.box("funnel", x, deck + 41, -8, x + 18, deck + 62, 8, texel=(1 / 16, 1 / 32),
              materials={"top": "funnel_top"})
    # Canots de sauvetage, des deux côtés, au bord du premier pont.
    for x in (-128, -98, -68, -38, -8, 22, 52):
        for sign in (1, -1):
            z0 = sign * 28
            m.box("lifeboat", x, deck + 17, min(z0, z0 + sign * 7), x + 22, deck + 24, max(z0, z0 + sign * 7),
                  texel=1 / 8, materials={"top": "lifeboat_top"})
    # Porte d'embarquement sur le flanc côté quai (vers +Z), où arrive la passerelle.
    m.box("door", -6, 6, beam / 2 - 1.2, 10, deck - 1, beam / 2 + 0.4, texel=1 / 16)
    # Bastingages.
    edge = beam / 2 - 2
    railing(m, [(-155, edge), (110, edge)], deck)
    railing(m, [(110, -edge), (-155, -edge)], deck)
    for y, half_x0, half_x1, w in ((deck + 15, -136, 92, 32), (deck + 29, -112, 70, 27), (deck + 41, -84, 44, 21)):
        railing(m, [(half_x0, w), (half_x1, w)], y)
        railing(m, [(half_x1, -w), (half_x0, -w)], y)
    hull_tex = tex_hull([(0, c5(31, 31, 31)), (2, c5(29, 29, 29)), (17, c5(4, 7, 16)), (23, c5(29, 29, 29)),
                         (24, c5(26, 6, 5)), (25, c5(29, 29, 29)), (26, c5(19, 5, 5))], w=64)
    for x in range(4, 64, 8):
        rect_fill(hull_tex, x, 8, x + 2, 10, c5(6, 10, 17))
    funnel = new_texture(16, 32, c5(26, 6, 5))
    rect_fill(funnel, 0, 0, 16, 3, c5(4, 4, 5))
    rect_fill(funnel, 0, 8, 16, 13, c5(30, 30, 30))
    rect_fill(funnel, 5, 9, 11, 12, c5(5, 9, 20))
    bridge = tex_cabin(c5(30, 30, 30), window=c5(5, 9, 16), band=(3, 10))
    door = new_texture(16, 16, c5(24, 24, 25))
    rect_fill(door, 1, 1, 15, 16, c5(14, 15, 18))
    hline(door, 0, 16, 0, c5(31, 31, 31))
    return m, {"hull": hull_tex, "deck": tex_flat(c5(20, 23, 22), 16, 16), "windows": tex_cabin(c5(30, 30, 30)),
               "bridge": bridge, "white": tex_flat(c5(30, 30, 30)), "mast": tex_flat(c5(27, 27, 28)),
               "funnel": funnel, "funnel_top": tex_flat(c5(4, 4, 5)), "lifeboat": tex_flat(c5(30, 16, 4)),
               "lifeboat_top": tex_flat(c5(30, 26, 18)), "railing": tex_railing(), "lamp": tex_lamp_glass(),
               "door": door}


def cargo_ship():
    """Porte-conteneurs (19 cases de long) : coque bleu marine, conteneurs de couleurs
    empilés sur le pont, château blanc à l'arrière avec sa passerelle et sa cheminée."""
    m = Mesh()
    length, beam, freeboard = 300, 68, 22
    deck = hull(m, length, beam, freeboard, 10, side="hull", deck="deck", bow=0.22, stern=0.95, sheer=0.35,
                stations=24, bulwark=3.0, inner="inner", deck_inset=1.5)
    # Gaillard d'avant.
    m.box("inner", 108, deck, -16, 126, deck + 6, 16, texel=1 / 16)
    # Château à l'arrière : cinq niveaux de cabines, passerelle large, cheminée.
    m.box("windows", -142, deck, -24, -106, deck + 44, 24, texel=(1 / 32, 1 / 16), materials={"top": "white"})
    m.box("bridge", -112, deck + 44, -34, -100, deck + 54, 34, texel=(1 / 32, 1 / 16), materials={"top": "white"})
    m.box("funnel", -150, deck + 30, -9, -134, deck + 60, 9, texel=(1 / 16, 1 / 32), materials={"top": "funnel_top"})
    m.cylinder("mast", -120, 0, 1.0, deck + 54, deck + 70, sides=6, cap=False, v_range=(0, 1))
    # Conteneurs : rangées de deux cases de long, empilées sur deux ou trois niveaux.
    tints = [(0.95, 0.38, 0.30), (0.35, 0.55, 0.95), (0.45, 0.80, 0.45), (0.98, 0.75, 0.30),
             (0.85, 0.85, 0.85), (0.70, 0.45, 0.85)]
    k = 0
    for bay, x in enumerate(range(-96, 100, 34)):
        levels = 3 if bay % 3 != 1 else 2
        for row, z in enumerate(range(-28, 28, 14)):
            for level in range(levels - (row == 0 or row == 3)):
                y = deck + level * 14
                m.box("container", x, y, z + 0.5, x + 32, y + 14, z + 13.5, texel=(1 / 32, 1 / 16),
                      tint=tints[(k * 7 + level * 3 + row) % len(tints)])
                k += 1
    hull_tex = tex_hull([(0, c5(28, 28, 28)), (2, c5(5, 8, 17)), (20, c5(30, 30, 30)), (21, c5(5, 8, 17)),
                         (22, c5(20, 5, 5))], w=32)
    for x in range(0, 32, 16):
        vline(hull_tex, x, 2, 20, c5(4, 6, 14))
    funnel = new_texture(16, 32, c5(29, 29, 29))
    rect_fill(funnel, 0, 0, 16, 3, c5(4, 4, 5))
    rect_fill(funnel, 0, 7, 16, 12, c5(4, 11, 22))
    return m, {"hull": hull_tex, "deck": tex_flat(c5(16, 7, 6), 16, 16), "inner": tex_flat(c5(6, 9, 18)),
               "windows": tex_cabin(c5(30, 30, 30)), "bridge": tex_cabin(c5(30, 30, 30), band=(3, 10)),
               "white": tex_flat(c5(30, 30, 30)), "funnel": funnel, "funnel_top": tex_flat(c5(4, 4, 5)),
               "mast": tex_flat(c5(27, 27, 28)), "container": tex_container()}


def gangway():
    """Passerelle d'embarquement : rampe métallique avec garde-corps, du quai (z = 0)
    jusqu'à la porte du ferry (vers -Z, 10 unités plus haut)."""
    m = Mesh()
    run, rise, half = 16.0, 10.0, 4.0
    m.poly("ramp", [(-half, 0.3, 0), (half, 0.3, 0), (half, rise, -run), (-half, rise, -run)],
           [(0, 0), (1, 0), (1, 2), (0, 2)], 1.0)
    for x in (-half, half):
        m.poly("railing", [(x, 0.3 + 5, 0), (x, rise + 5, -run), (x, rise, -run), (x, 0.3, 0)],
               [(0, 0), (run / 32, 0), (run / 32, 5 / 8), (0, 5 / 8)])
    ramp = new_texture(8, 8, c5(18, 19, 21))
    for y in range(0, 8, 2):
        hline(ramp, 0, 8, y, c5(23, 24, 26))
    return m, {"ramp": ramp, "railing": tex_railing()}


def scaled(build, factor):
    """Version agrandie d'un objet (bateaux) : géométrie multipliée, textures inchangées."""
    def make():
        mesh, textures = build()
        return mesh.transformed(lambda x, y, z: (x * factor, y * factor, z * factor)), textures
    return make


OBJECTS = {
    "bollard": bollard,
    "life_buoy": life_buoy,
    "nav_buoy_red": lambda: nav_buoy("red"),
    "nav_buoy_green": lambda: nav_buoy("green"),
    "crates": crates,
    "crates_big": crates_big,
    "barrels": barrels,
    "containers": containers_stack,
    "container_red": lambda: container((0.95, 0.38, 0.30)),
    "container_blue": lambda: container((0.35, 0.55, 0.95)),
    "lamppost": lamppost,
    "rowboat": scaled(rowboat, 1.35),
    "fishing_boat": scaled(fishing_boat, 1.5),
    "sailboat": scaled(sailboat, 1.45),
    "ferry": ferry,
    "cargo_ship": cargo_ship,
    "gangway": gangway,
}
# Bateaux tournés pour s'amarrer le long des pontons nord-sud (proue vers +Z).
ROTATED = ("rowboat", "fishing_boat", "sailboat")


def main():
    for name, build in OBJECTS.items():
        mesh, textures = build()
        mesh.write(os.path.join(OUT, name), name, textures, HEADER)
        if name in ROTATED:
            mesh.rotated_y(1).write(os.path.join(OUT, name + "_v"), name + "_v", textures, HEADER)
    print(len(OBJECTS) + len(ROTATED), "objets écrits dans", OUT)


if __name__ == "__main__":
    main()
