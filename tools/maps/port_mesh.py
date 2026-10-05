"""Petite boîte à outils pour fabriquer des modèles 3D façon DS (fichiers .obj + .mtl +
textures .png) : boîtes, cylindres, coques de bateau, textures en pixel art.

Utilisée par tools/maps/build_port.py et tools/maps/build_port_objects.py.

Conventions du jeu : 16 unités = 1 case, X vers la droite, Y vers le haut, Z vers le bas
de la carte. Les textures font 1 pixel par unité (une texture de 32 pixels couvre deux
cases), comme celles d'Accumula Town. Les couleurs de sommets donnent l'ombrage peint
(pas d'éclairage dans le jeu) : dessus clair, faces tournées vers la caméra un peu plus
sombres, côtés encore plus.
"""

import math
import os
import random

from PIL import Image

# Ombrage peint, selon l'orientation de la face.
SHADE_TOP = 1.0
SHADE_FRONT = 0.88   # face tournée vers le bas de la carte (vers la caméra)
SHADE_SIDE = 0.76    # face tournée vers la droite ou la gauche
SHADE_BACK = 0.66    # face tournée vers le haut de la carte
SHADE_BOTTOM = 0.55


def c5(r, g, b, a=255):
    """Couleur sur 5 bits par canal (0 à 31), comme sur DS."""
    return (round(r * 255 / 31), round(g * 255 / 31), round(b * 255 / 31), a)


def shade_for(normal):
    """Ombrage d'une face d'après sa normale (x, y, z)."""
    nx, ny, nz = normal
    length = math.sqrt(nx * nx + ny * ny + nz * nz) or 1.0
    nx, ny, nz = nx / length, ny / length, nz / length
    if ny > 0.7:
        return SHADE_TOP
    if ny < -0.7:
        return SHADE_BOTTOM
    # Mélange selon la direction horizontale de la face.
    front = max(nz, 0.0)
    back = max(-nz, 0.0)
    side = abs(nx)
    total = front + back + side or 1.0
    s = (front * SHADE_FRONT + back * SHADE_BACK + side * SHADE_SIDE) / total
    # Les faces inclinées vers le haut sont un peu plus claires.
    return min(1.0, s + max(ny, 0.0) * (SHADE_TOP - s))


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


class Mesh:
    """Maillage en cours de construction : des polygones rangés par matériau."""

    def __init__(self):
        self.faces = {}  # matériau -> [[(position, uv, couleur), ...], ...]

    def poly(self, material, points, uvs, shade=None, tint=(1.0, 1.0, 1.0)):
        """Ajoute un polygone convexe. Les points tournent dans le sens des aiguilles
        d'une montre vus de l'extérieur : l'ombrage est alors déduit de l'orientation de
        la face, au moment d'écrire le fichier (il reste juste si l'on tourne le modèle).
        `shade` force l'ombrage (1.0 pour un sol, par exemple)."""
        self.faces.setdefault(material, []).append(
            {"points": list(points), "uvs": list(uvs), "shade": shade, "tint": tint})

    def quad(self, material, a, b, c, d, uv_a, uv_b, uv_c, uv_d, shade=None, tint=(1.0, 1.0, 1.0)):
        self.poly(material, [a, b, c, d], [uv_a, uv_b, uv_c, uv_d], shade, tint)

    def box(self, material, x0, y0, z0, x1, y1, z1, materials=None, texel=1.0 / 32, tint=(1.0, 1.0, 1.0),
            skip=()):
        """Boîte alignée sur les axes. `materials` peut donner un matériau par face :
        {"top", "bottom", "front", "back", "left", "right"}. UV : 1 pixel par unité
        (texel = 1 / taille de la texture). `skip` : faces à ne pas créer."""
        m = materials or {}
        # texel : un nombre, ou (horizontal, vertical) pour les faces latérales.
        t, tv = texel if isinstance(texel, tuple) else (texel, texel)
        faces = {
            "top": ([(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
                    [(x0 * t, -z0 * t), (x1 * t, -z0 * t), (x1 * t, -z1 * t), (x0 * t, -z1 * t)]),
            "bottom": ([(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)],
                       [(x0 * t, z1 * t), (x1 * t, z1 * t), (x1 * t, z0 * t), (x0 * t, z0 * t)]),
            "front": ([(x0, y1, z1), (x1, y1, z1), (x1, y0, z1), (x0, y0, z1)],
                      [(x0 * t, 0), (x1 * t, 0), (x1 * t, (y1 - y0) * tv), (x0 * t, (y1 - y0) * tv)]),
            "back": ([(x1, y1, z0), (x0, y1, z0), (x0, y0, z0), (x1, y0, z0)],
                     [(-x1 * t, 0), (-x0 * t, 0), (-x0 * t, (y1 - y0) * tv), (-x1 * t, (y1 - y0) * tv)]),
            "left": ([(x0, y1, z0), (x0, y1, z1), (x0, y0, z1), (x0, y0, z0)],
                     [(z0 * t, 0), (z1 * t, 0), (z1 * t, (y1 - y0) * tv), (z0 * t, (y1 - y0) * tv)]),
            "right": ([(x1, y1, z1), (x1, y1, z0), (x1, y0, z0), (x1, y0, z1)],
                      [(-z1 * t, 0), (-z0 * t, 0), (-z0 * t, (y1 - y0) * tv), (-z1 * t, (y1 - y0) * tv)]),
        }
        for name, (pts, uvs) in faces.items():
            if name in skip:
                continue
            self.poly(m.get(name, material), pts, uvs, None, tint)

    def cylinder(self, material, cx, cz, radius, y0, y1, sides=8, top_material=None, u_scale=None,
                 v_range=None, cap=True, tint=(1.0, 1.0, 1.0), radius_top=None):
        """Cylindre (ou tronc de cône si radius_top) vertical. La texture fait le tour une
        fois (u de 0 à 1) ; v va du haut (0) au bas (v_range ou hauteur / 32)."""
        rt = radius if radius_top is None else radius_top
        v_top, v_bottom = v_range if v_range else (0.0, (y1 - y0) / 32)
        for i in range(sides):
            a0 = 2 * math.pi * i / sides
            a1 = 2 * math.pi * (i + 1) / sides
            u0 = i / sides if u_scale is None else i * u_scale
            u1 = (i + 1) / sides if u_scale is None else (i + 1) * u_scale
            p = [(cx + math.cos(a0) * rt, y1, cz + math.sin(a0) * rt),
                 (cx + math.cos(a1) * rt, y1, cz + math.sin(a1) * rt),
                 (cx + math.cos(a1) * radius, y0, cz + math.sin(a1) * radius),
                 (cx + math.cos(a0) * radius, y0, cz + math.sin(a0) * radius)]
            uv = [(u0, v_top), (u1, v_top), (u1, v_bottom), (u0, v_bottom)]
            self.poly(material, p[::-1], uv[::-1], None, tint)
        if cap:
            pts = [(cx + math.cos(2 * math.pi * i / sides) * rt, y1, cz + math.sin(2 * math.pi * i / sides) * rt)
                   for i in range(sides)]
            uvs = [(0.5 + math.cos(2 * math.pi * i / sides) * 0.5, 0.5 + math.sin(2 * math.pi * i / sides) * 0.5)
                   for i in range(sides)]
            self.poly(top_material or material, pts, uvs, SHADE_TOP, tint)

    def merge(self, other, offset=(0, 0, 0)):
        ox, oy, oz = offset
        for material, polys in other.faces.items():
            for poly in polys:
                moved = dict(poly)
                moved["points"] = [(p[0] + ox, p[1] + oy, p[2] + oz) for p in poly["points"]]
                self.faces.setdefault(material, []).append(moved)

    def transformed(self, fn):
        """Copie du maillage dont chaque position passe par fn(x, y, z) -> (x, y, z)."""
        out = Mesh()
        for material, polys in self.faces.items():
            out.faces[material] = []
            for poly in polys:
                moved = dict(poly)
                moved["points"] = [fn(*p) for p in poly["points"]]
                out.faces[material].append(moved)
        return out

    def rotated_y(self, quarter_turns):
        """Copie tournée d'un quart de tour par unité, autour de l'axe vertical : 1 = la
        proue d'un bateau modélisé vers la droite (+X) pointe vers le bas de la carte (+Z)."""
        def turn(x, y, z):
            for _ in range(quarter_turns % 4):
                x, z = -z, x
            return (x, y, z)
        return self.transformed(turn)

    @staticmethod
    def _shade(poly):
        if poly["shade"] is not None:
            return poly["shade"]
        p = poly["points"]
        n = _cross(_sub(p[1], p[0]), _sub(p[2], p[0]))
        return shade_for((-n[0], -n[1], -n[2]))

    def write(self, folder, name, textures, header=""):
        """Écrit name.obj, name.mtl et les textures {matériau: image PIL} dans folder.
        Chaque matériau utilise la texture « <matériau>.png » ; un matériau peut aussi
        pointer vers une texture existante : textures[mat] = "chemin/relatif.png"."""
        os.makedirs(folder, exist_ok=True)
        lines = []
        if header:
            lines += ["# " + h for h in header.splitlines()]
        lines.append(f"mtllib {name}.mtl")
        vt_lines = []
        f_lines = []
        v_lines = []
        count = 0
        for material in sorted(self.faces):
            f_lines.append(f"usemtl {material}")
            for poly in self.faces[material]:
                ids = []
                shade = self._shade(poly)
                tint = poly["tint"]
                c = (min(1.0, shade * tint[0]), min(1.0, shade * tint[1]), min(1.0, shade * tint[2]))
                for p, uv in zip(poly["points"], poly["uvs"]):
                    count += 1
                    v_lines.append("v %.4f %.4f %.4f %.4f %.4f %.4f" % (p[0], p[1], p[2], c[0], c[1], c[2]))
                    vt_lines.append("vt %.5f %.5f" % (uv[0], 1.0 - uv[1]))
                    ids.append(count)
                # Triangles en éventail : l'importeur de Godot les préfère aux polygones.
                for i in range(1, len(ids) - 1):
                    f_lines.append("f %d/%d %d/%d %d/%d" % (ids[0], ids[0], ids[i], ids[i], ids[i + 1], ids[i + 1]))
        with open(os.path.join(folder, name + ".obj"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(lines + v_lines + vt_lines + f_lines) + "\n")
        mtl = []
        for material in sorted(self.faces):
            tex = textures[material]
            file = tex if isinstance(tex, str) else material + ".png"
            if not isinstance(tex, str):
                tex.save(os.path.join(folder, file))
                write_texture_import(os.path.join(folder, file))
            mtl += [f"newmtl {material}", "Ka 1 1 1", "Kd 1 1 1", "d 1", f"map_Kd {file}", ""]
        with open(os.path.join(folder, name + ".mtl"), "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(mtl))
        write_obj_import(os.path.join(folder, name + ".obj"))


def write_texture_import(path):
    """Réglages d'import d'une texture : sans compression ni mipmaps, pour garder les
    pixels nets. Godot complète le fichier au premier import."""
    if os.path.exists(path + ".import"):
        return
    with open(path + ".import", "w", encoding="utf-8", newline="\n") as f:
        f.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
                "[params]\n\ncompress/mode=0\nmipmaps/generate=false\ndetect_3d/compress_to=0\n")


def write_obj_import(path):
    """Réglages d'import d'un modèle : pas de niveaux de détail (ils déformeraient les
    petits objets vus de loin)."""
    if os.path.exists(path + ".import"):
        return
    with open(path + ".import", "w", encoding="utf-8", newline="\n") as f:
        f.write('[remap]\n\nimporter="wavefront_obj"\nimporter_version=1\ntype="Mesh"\n\n'
                "[params]\n\ngenerate_tangents=false\ngenerate_lods=false\ngenerate_shadow_mesh=false\n")


# --- Textures en pixel art -------------------------------------------------------------

def new_texture(w, h, color):
    return Image.new("RGBA", (w, h), color)


def speckle(img, colors, amount, rng, rect=None):
    """Parsème la texture de pixels pris dans `colors` (proportion `amount`)."""
    x0, y0, x1, y1 = rect or (0, 0, img.width, img.height)
    for y in range(y0, y1):
        for x in range(x0, x1):
            if rng.random() < amount:
                img.putpixel((x, y), rng.choice(colors))


def hline(img, x0, x1, y, color):
    for x in range(x0, x1):
        img.putpixel((x % img.width, y % img.height), color)


def vline(img, x, y0, y1, color):
    for y in range(y0, y1):
        img.putpixel((x % img.width, y % img.height), color)


def rect_fill(img, x0, y0, x1, y1, color):
    for y in range(y0, y1):
        for x in range(x0, x1):
            img.putpixel((x % img.width, y % img.height), color)


def rng_for(name):
    return random.Random(name)
