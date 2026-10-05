"""Déplace et agrandit un modèle .obj (positions seulement), pour placer un intérieur loin
de la ville et l'adapter à la taille des personnages.

Usage :
    python tools/maps/place_model.py <modèle.obj> <décalage x> <décalage z> <échelle>
Exemple (Centre Pokémon) :
    python tools/maps/place_model.py assets/maps/pokemon_center/pokemon_center.obj 4000 0 1.3
L'échelle s'applique autour de l'origine du modèle, avant le décalage.
"""
import sys


def main(path, dx, dz, scale):
    lines = open(path, encoding="utf-8").read().splitlines()
    out = []
    for line in lines:
        if line.startswith("v "):
            parts = line.split()
            x, y, z = (float(v) * scale for v in parts[1:4])
            parts[1:4] = ["%.4f" % (x + dx), "%.4f" % y, "%.4f" % (z + dz)]
            line = " ".join(parts)
        out.append(line)
    out.insert(1, "# Placé par tools/maps/place_model.py : échelle %g, décalage (%g, %g)." % (scale, dx, dz))
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
    print("placé", path)


if __name__ == "__main__":
    main(sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4]))
