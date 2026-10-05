class_name BattleText
extends RefCounted
## Textes affichés pendant le combat, à partir des évènements du moteur. Tout le texte
## du combat est ici : la logique n'en produit aucun.

const APPLIED := {
	&"poison": "%s est empoisonné !",
	&"toxic": "%s est gravement empoisonné !",
	&"burn": "%s est brûlé !",
	&"paralysis": "%s est paralysé ! Il aura du mal à attaquer !",
	&"sleep": "%s s'endort !",
	&"freeze": "%s est gelé !",
	&"leech_seed": "%s est infecté !",
}
const TICK := {
	&"poison": "%s souffre du poison !",
	&"toxic": "%s souffre du poison !",
	&"burn": "%s souffre de sa brûlure !",
	&"leech_seed": "Vampigraine draine l'énergie de %s !",
}
const BLOCKS := {
	&"paralysis": "%s est paralysé ! Il ne peut pas attaquer !",
	&"sleep": "%s dort profondément.",
	&"freeze": "%s est gelé !",
}
const CURED := {
	&"wake_up": "%s se réveille !",
	&"thaw": "%s n'est plus gelé !",
	&"cured": "%s est guéri !",
}


## Messages d'un évènement, vus par le joueur du camp `own_side`. `side_names` : nom de
## chaque camp. Liste vide si l'évènement n'affiche rien.
static func messages(event: Dictionary, own_side: int, side_names: Array) -> PackedStringArray:
	var out := PackedStringArray()
	var who := _who(event.get("pokemon", {}), own_side)
	match event["type"]:
		&"battle_start":
			if event.get("wild", false):
				pass  # annoncé à l'envoi du Pokémon sauvage
			else:
				out.append("%s veut se battre !" % side_names[1 - own_side])
		&"send_out":
			var pokemon: Dictionary = event["pokemon"]
			if pokemon["side"] == own_side:
				out.append("Go ! %s !" % pokemon["name"])
			elif event["info"].get("wild", false):
				out.append("Un %s sauvage apparaît !" % pokemon["name"])
			else:
				out.append("%s envoie %s !" % [event["info"]["side_name"], pokemon["name"]])
		&"withdraw":
			var pokemon: Dictionary = event["pokemon"]
			if pokemon["side"] == own_side:
				out.append("%s, reviens !" % pokemon["name"])
			else:
				out.append("%s rappelle %s !" % [side_names[pokemon["side"]], pokemon["name"]])
		&"move_used":
			out.append("%s utilise %s !" % [who, event["move_name"]])
		&"move_missed":
			out.append("%s évite l'attaque !" % _who(event["target"], own_side))
		&"move_failed":
			out.append("Mais cela échoue !")
		&"no_effect":
			out.append("Ça n'affecte pas %s…" % _who(event["target"], own_side))
		&"critical_hit":
			out.append("Coup critique !")
		&"effectiveness":
			out.append("C'est super efficace !" if event["value"] > 1.0 else "Ce n'est pas très efficace…")
		&"stat_change":
			var delta: int = event["delta"]
			var verb := ("monte" if delta > 0 else "baisse") + (" beaucoup" if absi(delta) >= 2 else "")
			out.append("%s de %s %s !" % [_stat_with_article(event["stat"]), who, verb])
		&"stat_unchanged":
			out.append("%s de %s ne peut plus %s !" % [_stat_with_article(event["stat"]), who,
				"monter" if event["rising"] else "baisser"])
		&"condition_applied":
			out.append(APPLIED.get(event["condition"], "%s est affecté !") % who)
		&"condition_failed":
			if event["reason"] == "immune":
				out.append("Ça n'affecte pas %s…" % _who(event["pokemon"], own_side))
			else:
				out.append("Mais cela échoue !")
		&"condition_tick":
			if TICK.has(event["condition"]):
				out.append(TICK[event["condition"]] % who)
		&"condition_blocks":
			out.append(BLOCKS.get(event["condition"], "%s ne peut pas attaquer !") % who)
		&"condition_cured":
			out.append(CURED.get(event["reason"], "%s est guéri !") % who)
		&"recoil":
			out.append("%s est blessé par le contrecoup !" % who)
		&"faint":
			out.append("%s est K.O. !" % who)
		&"item_used":
			if event["side"] == own_side:
				out.append("Vous utilisez %s !" % event["item_name"])
			else:
				out.append("%s utilise %s !" % [event["side_name"], event["item_name"]])
		&"hp_change":
			if event.get("cause", &"") == &"heal":
				out.append("%s récupère des PV !" % who)
		&"exp_gain":
			if event["amount"] > 0:
				out.append("%s gagne %d points d'Exp. !" % [who, event["amount"]])
		&"level_up":
			out.append("%s monte au niveau %d !" % [who, event["level"]])
		&"move_learned":
			out.append("%s apprend %s !" % [who, event["move_name"]])
		&"move_skipped":
			out.append("%s veut apprendre %s, mais il connaît déjà quatre attaques." % [who, event["move_name"]])
		&"ball_thrown":
			out.append("Vous lancez une %s !" % event["item_name"])
		&"ball_escaped":
			out.append(["Oh non ! Le Pokémon s'est libéré !", "Raaah ! Ça y était presque !",
				"Aaaah ! Il s'en est fallu de peu !"][clampi(event["shakes"], 0, 2)])
			if event.get("balls_left", -1) >= 0:
				out.append("Il vous reste %d lancer%s." % [event["balls_left"], "s" if event["balls_left"] > 1 else ""])
		&"evolution":
			out.append("Quoi ? %s évolue !" % event["name"])
		&"run_success":
			out.append("Vous prenez la fuite !")
		&"run_failed":
			out.append("Impossible de fuir !")
		&"say":
			out.append(event["text"])
	return out


## Nom d'un Pokémon tel qu'affiché : « Bulbizarre ennemi » pour l'adversaire.
static func _who(pokemon: Dictionary, own_side: int) -> String:
	if pokemon.is_empty():
		return ""
	var pokemon_name: String = pokemon["name"]
	if pokemon["side"] != own_side:
		return "%s ennemi" % pokemon_name
	return pokemon_name


static func _stat_with_article(stat: int) -> String:
	var stat_name := Stat.stat_name(stat)
	if stat_name.begins_with("A") or stat_name.begins_with("E"):
		return "L'%s" % stat_name
	return "La %s" % stat_name
