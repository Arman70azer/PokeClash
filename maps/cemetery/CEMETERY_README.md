# Cimetière - Implémentation

## Description

Le cimetière est une nouvelle zone de la carte que vous pouvez visiter. C'est un endroit tranquille avec des tombes, des cyprès et des ruines.

## À faire pour compléter le cimetière

1. **Créer le modèle 3D** :
   - Créer un modèle 3D de la zone du cimetière contenant :
     - Un sol/terrain
     - Des tombes (colonnes en ruine)
     - Des cyprès (arbres)
     - Des souches (arbres morts)
   - Le modèle doit être au format `.obj` avec textures
   - Placer le modèle dans `assets/maps/cemetery/`

2. **Générer la grille de marche** :
   ```
   godot --headless -s res://tools/maps/bake_map_grid.gd -- res://assets/maps/cemetery/cemetery.obj res://assets/maps/cemetery/cemetery_grid.tres
   ```

3. **Créer la scène `.tscn`** :
   - Créer `maps/cemetery/cemetery.tscn` avec :
     - Un nœud `Node3D` avec le script `game_map.gd`
     - `map_id = &"cemetery"`
     - `display_name = "Cimetière"`
     - Une zone `MeshInstance3D` avec le modèle `.obj`
     - Une grille de marche `.tres`
     - Des passages vers/depuis d'autres cartes (warps)
     - Des objets 3D décor (tombes, cyprès, etc.)

4. **Connecter le cimetière au monde** :
   - Ajouter un passage (warp) depuis Accumula Town vers le cimetière
   - Ajouter un passage de retour depuis le cimetière vers Accumula Town

## Structure recommandée

```
maps/cemetery/
├── cemetery.tscn              # Scène principale du cimetière
├── CEMETERY_README.md         # Ce fichier
assets/maps/cemetery/
├── cemetery.obj               # Modèle 3D
├── cemetery_grid.tres         # Grille de marche (généré)
├── [textures.png]             # Textures du modèle
```

## Exemple de code pour ajouter le cimetière à Accumula

Dans `maps/accumula/accumula.tscn`, ajouter un Warp :

```gdscript
[node name="EnterCemetery" type="Node" parent="Warps"]
script = ExtResource("warp")
trigger_cells = Array[Vector2i]([Vector2i(X, Y)])  # Ajuster les coordonnées
direction = Vector2i(0, -1)
target_map = &"cemetery"
target_cell = Vector2i(5, 5)  # Ajuster
target_facing = Vector2i(0, -1)
```

Et ajouter un Warp de retour dans `maps/cemetery/cemetery.tscn` :

```gdscript
[node name="EnterAccumula" type="Node" parent="Warps"]
script = ExtResource("warp")
trigger_cells = Array[Vector2i]([Vector2i(X, Y)])  # Ajuster
direction = Vector2i(0, 1)
target_map = &"accumula"
target_cell = Vector2i(X, Y)  # Ajuster
target_facing = Vector2i(0, 1)
```
