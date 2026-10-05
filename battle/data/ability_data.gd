class_name AbilityData
extends Resource
## Un talent (Brasier, Engrais…). Un fichier .tres par talent dans data/abilities, créé par
## tools/data/import_pokeapi.py. Les effets en combat ne sont pas encore gérés : pour en
## ajouter un, créer une sous-classe et redéfinir ses points d'extension.

@export var id: StringName
@export var name := ""
@export_multiline var description := ""
