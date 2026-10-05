class_name SaveService
extends RefCounted
## Fichiers de sauvegarde des joueurs, écrits par l'hôte : un fichier JSON par pseudo
## dans user://saves/. On n'enregistre que des données (PlayerData.to_dict), jamais
## des nœuds.

const DIR := "user://saves/"
## Version du format. 1 : sans PC ni identifiants de Pokémon ; 2 : avec. Une sauvegarde
## en version 1 se charge telle quelle (boîtes vides, identifiants créés au chargement)
## et sera réécrite en version 2 à la sauvegarde suivante.
const VERSION := 2


## Nom de fichier d'un pseudo : minuscules, lettres et chiffres seulement.
static func path_for(player_name: String) -> String:
	var slug := ""
	for c in player_name.to_lower():
		slug += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	slug = slug.strip_edges()
	return DIR + (slug if not slug.replace("_", "").is_empty() else "joueur") + ".json"


static func exists(player_name: String) -> bool:
	return FileAccess.file_exists(path_for(player_name))


static func save(data: PlayerData) -> Error:
	DirAccess.make_dir_recursive_absolute(DIR)
	var content := {"version": VERSION, "saved_at": Time.get_datetime_string_from_system(), "player": data.to_dict()}
	# Écrit d'abord à côté puis remplace : une coupure en pleine écriture ne détruit pas
	# l'ancienne sauvegarde.
	var path := path_for(data.player_name)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_error("SaveService : impossible d'écrire %s" % path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(content, "\t"))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)


## Sauvegarde d'un pseudo, ou null s'il n'en a pas (ou si elle est illisible).
static func load_player(player_name: String) -> PlayerData:
	var path := path_for(player_name)
	if not FileAccess.file_exists(path):
		return null
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.has("player"):
		push_error("SaveService : sauvegarde illisible %s" % path)
		return null
	# Ancien format : on en garde une copie intacte avant qu'il soit réécrit.
	var version := int(parsed.get("version", 1))
	if version < VERSION and not FileAccess.file_exists(path + ".v%d.bak" % version):
		DirAccess.copy_absolute(path, path + ".v%d.bak" % version)
	return PlayerData.from_dict(parsed["player"])


static func delete(player_name: String) -> void:
	var path := path_for(player_name)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
