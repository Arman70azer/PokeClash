"""Convertit un modèle Collada (.dae) en .obj + .mtl lisibles par Godot.

Les cartes extraites au format .dae rattachent chaque morceau à un « contrôleur »
(squelette), une structure que l'importeur Collada de Godot ne lit qu'en partie :
le terrain disparaît. Ce script recompose le modèle dans sa pose de repos et l'écrit
en .obj, avec les couleurs de sommets (ombrage peint) et un matériau par texture.

Usage :
    python tools/maps/dae_to_obj.py "source_assets/maps/accumula_town/Accumula Town.dae" accumula_town assets/maps/accumula_town

Le .obj et le .mtl sont écrits dans le dossier donné en dernier (par défaut : à côté du
.dae), qui doit contenir les textures. Les .dae restent dans source_assets/, ignoré par
Godot : son importeur Collada lit mal ces cartes et affiche des erreurs à chaque ouverture.
"""
import os
import re
import sys
import urllib.parse
import xml.etree.ElementTree as ET


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def mat_apply(m, v):
    x, y, z = v
    return tuple(m[i][0] * x + m[i][1] * y + m[i][2] * z + m[i][3] for i in range(3))


def mat_from_text(text):
    f = [float(t) for t in text.split()]
    return [f[0:4], f[4:8], f[8:12], f[12:16]]


IDENTITY = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]


def main(dae_path, out_name, out_dir=None):
    root = ET.parse(dae_path).getroot()
    ns = {"c": re.match(r"\{(.*)\}", root.tag).group(1)}
    folder = os.path.dirname(dae_path)

    def find(parent, path):
        return parent.find(path, ns)

    def findall(parent, path):
        return parent.findall(path, ns)

    # Texture de chaque matériau : matériau -> effet -> surface -> image -> fichier.
    images = {}
    for img in findall(root, ".//c:library_images/c:image"):
        images[img.get("id")] = urllib.parse.unquote(find(img, "c:init_from").text.strip())
    effect_tex = {}
    for eff in findall(root, ".//c:library_effects/c:effect"):
        init = find(eff, ".//c:surface/c:init_from")
        if init is not None and init.text.strip() in images:
            effect_tex[eff.get("id")] = images[init.text.strip()]
    material_tex = {}
    for mat in findall(root, ".//c:library_materials/c:material"):
        url = find(mat, "c:instance_effect").get("url")[1:]
        material_tex[mat.get("id")] = effect_tex.get(url)

    # Géométries : positions, UV, couleurs et faces.
    geometries = {}
    for geo in findall(root, ".//c:library_geometries/c:geometry"):
        mesh = find(geo, "c:mesh")
        sources = {}
        for src in findall(mesh, "c:source"):
            arr = find(src, "c:float_array")
            acc = find(src, "c:technique_common/c:accessor")
            if arr is None or acc is None:
                continue
            stride = int(acc.get("stride"))
            vals = [float(t) for t in arr.text.split()]
            sources[src.get("id")] = [tuple(vals[i:i + stride]) for i in range(0, len(vals), stride)]
        vertices_id = find(mesh, "c:vertices").get("id")
        position_src = find(mesh, "c:vertices/c:input[@semantic='POSITION']").get("source")[1:]
        # Certains objets déclarent aussi leurs UV et couleurs dans <vertices> : elles
        # suivent alors l'indice du sommet.
        vertex_inputs = {i.get("semantic"): i.get("source")[1:] for i in findall(mesh, "c:vertices/c:input")
                         if i.get("semantic") != "POSITION"}
        prims = []
        for prim in findall(mesh, "c:polylist") + findall(mesh, "c:triangles"):
            inputs = {}
            max_offset = 0
            for inp in findall(prim, "c:input"):
                src = inp.get("source")[1:]
                if src == vertices_id:
                    src = position_src
                    for semantic, extra in vertex_inputs.items():
                        inputs.setdefault(semantic, (extra, int(inp.get("offset"))))
                inputs[inp.get("semantic")] = (src, int(inp.get("offset")))
                max_offset = max(max_offset, int(inp.get("offset")))
            step = max_offset + 1
            p = [int(t) for t in find(prim, "c:p").text.split()]
            vcount_el = find(prim, "c:vcount")
            count = int(prim.get("count"))
            vcounts = [int(t) for t in vcount_el.text.split()] if vcount_el is not None else [3] * count
            faces = []
            cursor = 0
            for n in vcounts:
                corners = [p[cursor + k * step:cursor + (k + 1) * step] for k in range(n)]
                cursor += n * step
                for k in range(1, n - 1):  # découpe en éventail les faces à plus de 3 côtés
                    faces.append((corners[0], corners[k], corners[k + 1]))
            prims.append({"material": prim.get("material"), "inputs": inputs, "faces": faces})
        geometries[geo.get("id")] = {"sources": sources, "prims": prims}

    # Hiérarchie des nœuds : matrice monde de chaque nœud.
    # Plusieurs objets réutilisent les mêmes noms d'os ("polySurface1"...) : un os se
    # cherche donc dans le squelette de l'objet concerné, jamais dans tout le modèle.
    node_matrix = {}   # élément XML -> matrice monde
    node_by_id = {}    # id -> élément XML
    instances = []

    def walk(node, parent_matrix):
        local = IDENTITY
        m = find(node, "c:matrix")
        if m is not None:
            local = mat_from_text(m.text)
        matrix = mat_mul(parent_matrix, local)
        node_matrix[node] = matrix
        if node.get("id"):
            node_by_id[node.get("id")] = node
        for inst in findall(node, "c:instance_controller") + findall(node, "c:instance_geometry"):
            binds = {}
            for im in findall(inst, ".//c:instance_material"):
                binds[im.get("symbol")] = im.get("target")[1:]
            skeleton = find(inst, "c:skeleton")
            skeleton_id = skeleton.text.strip()[1:] if skeleton is not None else None
            instances.append((inst.tag.split("}")[1], inst.get("url")[1:], node, skeleton_id, binds))
        for child in findall(node, "c:node"):
            walk(child, matrix)

    for scene in findall(root, ".//c:library_visual_scenes/c:visual_scene"):
        for node in findall(scene, "c:node"):
            walk(node, IDENTITY)

    def find_joint(start, name):
        """Cherche l'os `name` dans le sous-arbre de `start` (lui compris)."""
        if start is None:
            return None
        for node in start.iter():
            if node.tag.endswith("}node") and name in (node.get("sid"), node.get("id"), node.get("name")):
                return node
        return None

    controllers = {}
    for ctrl in findall(root, ".//c:library_controllers/c:controller"):
        skin = find(ctrl, "c:skin")
        bsm = find(skin, "c:bind_shape_matrix")
        srcs = {}
        for src in findall(skin, "c:source"):
            names = find(src, "c:Name_array")
            if names is None:
                names = find(src, "c:IDREF_array")
            floats = find(src, "c:float_array")
            if names is not None:
                srcs[src.get("id")] = names.text.split()
            elif floats is not None:
                srcs[src.get("id")] = [float(t) for t in floats.text.split()]
        joints_in = find(skin, "c:joints")
        joint_names = srcs[find(joints_in, "c:input[@semantic='JOINT']").get("source")[1:]]
        ibm_flat = srcs[find(joints_in, "c:input[@semantic='INV_BIND_MATRIX']").get("source")[1:]]
        ibms = [[ibm_flat[i * 16 + r * 4:i * 16 + r * 4 + 4] for r in range(4)] for i in range(len(joint_names))]
        vw = find(skin, "c:vertex_weights")
        vw_inputs = {i.get("semantic"): (i.get("source")[1:], int(i.get("offset"))) for i in findall(vw, "c:input")}
        weights = srcs[vw_inputs["WEIGHT"][0]]
        vcount = [int(t) for t in find(vw, "c:vcount").text.split()]
        v = [int(t) for t in find(vw, "c:v").text.split()]
        step = len(vw_inputs)
        influences = []
        cursor = 0
        for n in vcount:
            inf = []
            for k in range(n):
                j = v[cursor + k * step + vw_inputs["JOINT"][1]]
                w = weights[v[cursor + k * step + vw_inputs["WEIGHT"][1]]]
                inf.append((j, w))
            cursor += n * step
            influences.append(inf)
        controllers[ctrl.get("id")] = {
            "geometry": skin.get("source")[1:],
            "bind_shape": mat_from_text(bsm.text) if bsm is not None else IDENTITY,
            "joints": joint_names, "ibms": ibms, "influences": influences,
        }

    # Écriture : un bloc de sommets par morceau, les faces regroupées par matériau.
    v_lines, vt_lines = [], []
    faces_by_material = {}
    v_base, vt_base = 1, 1
    skipped = 0
    missing_joints = 0
    for kind, url, inst_node, skeleton_id, binds in instances:
        if kind == "instance_controller":
            ctrl = controllers[url]
            geo = geometries[ctrl["geometry"]]
            # Matrice monde de chaque os, pris dans le squelette de cet objet.
            joint_world = []
            for name in ctrl["joints"]:
                # D'abord dans l'objet lui-même : les identifiants de squelette sont
                # eux aussi dupliqués d'un objet à l'autre dans ces fichiers.
                joint = find_joint(inst_node, name)
                if joint is None:
                    joint = find_joint(node_by_id.get(skeleton_id), name)
                joint_world.append(node_matrix.get(joint) if joint is not None else None)
                if joint is None:
                    missing_joints += 1
        else:
            ctrl = None
            geo = geometries[url]
        for prim in geo["prims"]:
            pos_src, pos_off = prim["inputs"]["VERTEX"]
            positions = geo["sources"][pos_src]
            uv = prim["inputs"].get("TEXCOORD")
            col = prim["inputs"].get("COLOR")
            uvs = geo["sources"][uv[0]] if uv else None
            colors = geo["sources"][col[0]] if col else None

            placed = []
            for i, p in enumerate(positions):
                if ctrl is None:
                    placed.append(mat_apply(node_matrix[inst_node], p))
                    continue
                base = mat_apply(ctrl["bind_shape"], p)
                acc = [0.0, 0.0, 0.0]
                total = 0.0
                for j, w in ctrl["influences"][i]:
                    if joint_world[j] is None:
                        continue
                    q = mat_apply(mat_mul(joint_world[j], ctrl["ibms"][j]), base)
                    acc = [acc[k] + q[k] * w for k in range(3)]
                    total += w
                placed.append(tuple(a / total for a in acc) if total > 0 else base)
                if total == 0:
                    skipped += 1

            material = binds.get(prim["material"], prim["material"])
            out_faces = faces_by_material.setdefault(material, [])
            for face in prim["faces"]:
                refs = []
                for corner in face:
                    p = placed[corner[pos_off]]
                    c = colors[corner[col[1]]][:3] if colors else None
                    if c is not None:
                        v_lines.append("v %.4f %.4f %.4f %.4f %.4f %.4f" % (p[0], p[1], p[2], c[0], c[1], c[2]))
                    else:
                        v_lines.append("v %.4f %.4f %.4f" % p)
                    if uvs:
                        t = uvs[corner[uv[1]]]
                        vt_lines.append("vt %.5f %.5f" % (t[0], t[1]))
                        refs.append("%d/%d" % (v_base, vt_base))
                        vt_base += 1
                    else:
                        refs.append("%d" % v_base)
                    v_base += 1
                out_faces.append("f " + " ".join(refs))

    out_dir = out_dir or folder
    obj_path = os.path.join(out_dir, out_name + ".obj")
    mtl_path = os.path.join(out_dir, out_name + ".mtl")
    with open(obj_path, "w", encoding="utf-8", newline="\n") as f:
        f.write("# Converti depuis %s par tools/maps/dae_to_obj.py\n" % os.path.basename(dae_path))
        f.write("mtllib %s.mtl\n" % out_name)
        f.write("\n".join(v_lines) + "\n")
        f.write("\n".join(vt_lines) + "\n")
        for material, faces in faces_by_material.items():
            f.write("usemtl %s\n" % material)
            f.write("\n".join(faces) + "\n")
    with open(mtl_path, "w", encoding="utf-8", newline="\n") as f:
        for material in faces_by_material:
            f.write("newmtl %s\nKd 1 1 1\nd 1\n" % material)
            tex = material_tex.get(material)
            if tex:
                f.write("map_Kd %s\n" % tex)
            f.write("\n")

    xs = [float(l.split()[1]) for l in v_lines]
    ys = [float(l.split()[2]) for l in v_lines]
    zs = [float(l.split()[3]) for l in v_lines]
    print("joints not found:", missing_joints)
    print("instances:", len(instances), "| triangles:", sum(len(f) for f in faces_by_material.values()),
          "| materials:", len(faces_by_material), "| vertices without joint:", skipped)
    print("bounds x %.1f..%.1f  y %.1f..%.1f  z %.1f..%.1f" % (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    missing = [m for m in faces_by_material if not material_tex.get(m)]
    print("materials without texture:", missing)
    print("wrote", obj_path, "and", mtl_path)


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        print(__doc__)
        sys.exit(1)
    main(*sys.argv[1:])
