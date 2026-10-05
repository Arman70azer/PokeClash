extends SceneTree
## Tests automatiques de la logique de combat (aucun affichage).
##
## Usage, depuis le dossier du projet :
##   godot --headless --path . -s res://tools/tests/test_battle.gd
## Affiche chaque test raté et un bilan ; code de sortie 1 si un test échoue.

const CHARMANDER := preload("res://data/pokemon/charmander.tres")
const BULBASAUR := preload("res://data/pokemon/bulbasaur.tres")
const EMBER := preload("res://data/moves/ember.tres")
const SCRATCH := preload("res://data/moves/scratch.tres")
const GROWL := preload("res://data/moves/growl.tres")
const TACKLE := preload("res://data/moves/tackle.tres")
const LEECH_SEED := preload("res://data/moves/leech_seed.tres")
const POTION := preload("res://data/items/potion.tres")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	_test_data_is_valid()
	_test_type_chart()
	_test_stat_formula()
	_test_damage()
	_test_stages_and_accuracy()
	_test_statuses()
	_test_leech_seed()
	_test_turn_order()
	_test_victory_and_defeat()
	_test_replacement()
	_test_run()
	_test_items()
	_test_struggle()
	_test_network_round_trip()
	_test_experience()
	_test_evolution()
	_test_capture()
	print("Tests de combat : %d réussis, %d ratés" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --- Outils --------------------------------------------------------------------------

func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("ÉCHEC : ", label)


func check_eq(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, "%s (obtenu %s, attendu %s)" % [label, actual, expected])


func mon(species: PokemonSpecies, level: int, moves: Array = []) -> PokemonInstance:
	var p := PokemonInstance.create(species, level)
	if not moves.is_empty():
		var typed: Array[MoveData] = []
		for m in moves:
			typed.append(m)
		p.moves = typed
		p.restore()
	return p


## Combat joueur (camp 0, humain) contre IA aléatoire (camp 1), tirage fixe.
func battle(mine: Array, theirs: Array, seed := 1) -> BattleEngine:
	var engine := BattleEngine.new(null, seed)
	var a: Array[PokemonInstance] = []
	a.assign(mine)
	var b: Array[PokemonInstance] = []
	b.assign(theirs)
	engine.add_side("Joueur", a, true)
	engine.add_side("Adversaire", b, false, BattleAI.create(&"random"))
	engine.start()
	engine.take_events()
	return engine


func events_of(events: Array, type: StringName) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type)


func move_action(index: int) -> MoveAction:
	var a := MoveAction.new(index)
	a.side = 0
	return a


# --- Tests -----------------------------------------------------------------------------

func _test_data_is_valid() -> void:
	check(CHARMANDER.validate().is_empty(), "données de Salamèche valides : %s" % CHARMANDER.validate())
	check(BULBASAUR.validate().is_empty(), "données de Bulbizarre valides : %s" % BULBASAUR.validate())
	for path in ["scratch", "tackle", "growl", "ember", "leech_seed", "vine_whip", "smokescreen", "struggle"]:
		var move: MoveData = load("res://data/moves/%s.tres" % path)
		check(move != null and move.validate().is_empty(), "attaque %s valide" % path)
	# Toutes les espèces importées de PokeAPI (n°1 à 649).
	var species_count := 0
	var invalid: Array[String] = []
	for file in DirAccess.get_files_at("res://data/pokemon"):
		if not file.ends_with(".tres"):
			continue
		var species: PokemonSpecies = load("res://data/pokemon/" + file)
		species_count += 1
		# Les sprites de combat n'existent encore que pour quelques espèces.
		var problems := Array(species.validate()).filter(func(p: String) -> bool: return not p.contains("planche"))
		if not problems.is_empty() or species.abilities.is_empty() or species.icon_sheet == null:
			invalid.append(file)
	check_eq(species_count, 649, "649 espèces dans data/pokemon")
	check(invalid.is_empty(), "toutes les espèces sont valides : %s" % [invalid])
	var lyra: TrainerData = load("res://data/trainers/lyra.tres")
	check(lyra != null and lyra.validate().is_empty(), "dresseuse Lyra valide")
	var m := CHARMANDER.moves_at_level(8)
	check_eq(m.size(), 4, "Salamèche niveau 8 connaît quatre attaques (Griffe, Rugissement, Flammèche, Brouillard)")
	check(EMBER in m, "Salamèche niveau 8 connaît Flammèche")


func _test_type_chart() -> void:
	var T := PokemonType.Type
	check_eq(PokemonType.effectiveness(T.FIRE, [T.GRASS]), 2.0, "Feu contre Plante")
	check_eq(PokemonType.effectiveness(T.WATER, [T.FIRE]), 2.0, "Eau contre Feu")
	check_eq(PokemonType.effectiveness(T.ELECTRIC, [T.GROUND]), 0.0, "Électrik contre Sol")
	check_eq(PokemonType.effectiveness(T.NORMAL, [T.GHOST]), 0.0, "Normal contre Spectre")
	check_eq(PokemonType.effectiveness(T.GRASS, [T.GRASS, T.POISON]), 0.25, "Plante contre Plante/Poison")
	check_eq(PokemonType.effectiveness(T.FIRE, [T.GRASS, T.POISON]), 2.0, "Feu contre Plante/Poison")
	check_eq(PokemonType.effectiveness(T.GROUND, [T.FIRE, T.STEEL]), 4.0, "Sol contre Feu/Acier")
	check_eq(PokemonType.effectiveness(T.NORMAL, [T.NORMAL]), 1.0, "Normal contre Normal")


func _test_stat_formula() -> void:
	var c := mon(CHARMANDER, 8)
	check_eq(c.max_hp(), 25, "PV de Salamèche niveau 8 (IV 15)")
	check_eq(c.stat(Stat.ATTACK), 14, "Attaque de Salamèche niveau 8")
	check_eq(c.stat(Stat.SP_ATTACK), 15, "Attaque Spé. de Salamèche niveau 8")
	c.nature = 3  # Rigide : +Attaque, -Attaque Spé.
	check_eq(c.stat(Stat.ATTACK), 15, "nature Rigide : Attaque +10 %")
	check_eq(c.stat(Stat.SP_ATTACK), 13, "nature Rigide : Attaque Spé. -10 %")


func _context(attacker: BattlePokemon, defender: BattlePokemon, move: MoveData, crit := false) -> DamageContext:
	var rng := RandomNumberGenerator.new()
	var ctx := DamageCalculator.make_context(BattleRules.default_rules(), rng, attacker, defender, move)
	ctx.is_critical = crit
	ctx.random_percent = 100
	return ctx


func _test_damage() -> void:
	var rules := BattleRules.default_rules()
	var c := BattlePokemon.from_instance(mon(CHARMANDER, 8), 0, 0, rules)
	var b := BattlePokemon.from_instance(mon(BULBASAUR, 8), 1, 0, rules)
	# Flammèche : base 5, STAB x1,5 -> 7, super efficace x2 -> 14.
	var r := DamageCalculator.calculate(_context(c, b, EMBER))
	check_eq(r.damage, 14, "Flammèche de Salamèche sur Bulbizarre")
	check(r.stab, "Flammèche a le bonus de même type")
	check_eq(r.effectiveness, 2.0, "Flammèche super efficace")
	check_eq(DamageCalculator.calculate(_context(c, b, EMBER, true)).damage, 30, "Flammèche critique (x2)")
	# Griffe : pas de STAB.
	var scratch := DamageCalculator.calculate(_context(c, b, SCRATCH))
	check(not scratch.stab, "Griffe n'a pas de bonus de même type")
	# Brûlure : attaques physiques divisées par deux.
	c.status = BattleConditions.create(&"burn")
	var burned := DamageCalculator.calculate(_context(c, b, SCRATCH))
	check_eq(burned.damage, maxi(1, scratch.damage / 2), "brûlure : dégâts physiques divisés par deux")
	check_eq(DamageCalculator.calculate(_context(c, b, EMBER)).damage, 14, "brûlure : dégâts spéciaux inchangés")
	c.status = null
	# Facteur aléatoire : toujours entre 85 et 100 %.
	var low := _context(c, b, EMBER)
	low.random_percent = 85
	check(DamageCalculator.calculate(low).damage <= 14, "facteur aléatoire minimal")
	# Immunité : dégâts nuls.
	var ghost_ctx := _context(c, b, SCRATCH)
	ghost_ctx.effectiveness = 0.0
	check(DamageCalculator.calculate(ghost_ctx).is_immune(), "immunité : aucun dégât")


func _test_stages_and_accuracy() -> void:
	var rules := BattleRules.default_rules()
	check_eq(rules.stage_multiplier(-1), 2.0 / 3.0, "niveau -1 : x2/3")
	check_eq(rules.stage_multiplier(2), 2.0, "niveau +2 : x2")
	check_eq(rules.stage_multiplier(-6), 0.25, "niveau -6 : x1/4")
	check_eq(rules.accuracy_multiplier(-1), 0.75, "précision -1 : x3/4")
	check_eq(rules.critical_denominator(0), 16, "critique : 1 chance sur 16")
	var engine := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8)])
	var target := engine.sides[1].active()
	var attack_before := target.effective_stat(Stat.ATTACK, rules)
	for i in 6:
		engine.change_stage(target, Stat.ATTACK, -1, true)
	check_eq(target.stages[Stat.ATTACK], -6, "Attaque bloquée à -6")
	check(target.effective_stat(Stat.ATTACK, rules) < attack_before, "Attaque réduite par les niveaux")
	engine.take_events()
	check(not engine.change_stage(target, Stat.ATTACK, -1, true), "plus de baisse possible sous -6")
	check_eq(events_of(engine.take_events(), &"stat_unchanged").size(), 1, "échec annoncé")
	# Précision : sur 2000 tirages à 100 % de précision et esquive +6, environ 1/3 touchent.
	var a := engine.sides[0].active()
	target.stages[Stat.EVASION] = 6
	var hits := 0
	for i in 2000:
		if engine._accuracy_hits(a, target, SCRATCH):
			hits += 1
	check(hits > 560 and hits < 780, "esquive +6 : environ un tiers des attaques touchent (%d/2000)" % hits)


func _test_statuses() -> void:
	var engine := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8)])
	var c := engine.sides[0].active()
	var b := engine.sides[1].active()
	check(not engine.apply_condition(b, &"poison", true), "Bulbizarre (Poison) ne peut pas être empoisonné")
	check(not engine.apply_condition(c, &"burn", true), "Salamèche (Feu) ne peut pas être brûlé")
	check(engine.apply_condition(b, &"burn", true), "Bulbizarre peut être brûlé")
	check(not engine.apply_condition(b, &"paralysis", true), "un seul statut principal à la fois")
	engine.take_events()
	var hp_before := b.hp
	b.status.on_end_turn(engine, b)
	check_eq(hp_before - b.hp, BattleRules.fraction(b.max_hp, 8), "brûlure : 1/8 des PV en fin de tour")
	# Paralysie : Vitesse divisée par quatre.
	var speed := c.effective_stat(Stat.SPEED, engine.rules)
	engine.apply_condition(c, &"paralysis", true)
	check_eq(c.effective_stat(Stat.SPEED, engine.rules), maxi(1, int(floor(c.stats[Stat.SPEED] * 0.25))), "paralysie : Vitesse x1/4 (%d avant)" % speed)
	# Sommeil : bloque, puis réveil au bout de 1 à 3 tours.
	engine.cure_status(c)
	engine.apply_condition(c, &"sleep", true)
	var blocked := 0
	for i in 4:
		if c.status == null:
			break
		if not c.status.before_move(engine, c, SCRATCH):
			blocked += 1
	check(c.status == null, "réveil au plus tard au troisième tour")
	check(blocked >= 0 and blocked <= 2, "sommeil : 0 à 2 tours sans agir avant le réveil (%d)" % blocked)
	# Gel : une attaque Feu dégèle.
	engine.apply_condition(b, &"freeze", false)  # déjà brûlé : refusé
	check(b.status.id == &"burn", "gel refusé sur un Pokémon déjà brûlé")
	# Le statut reste après le combat.
	engine.cancel()
	check_eq(b.source.status, &"burn", "le statut principal est conservé après le combat")


func _test_leech_seed() -> void:
	var engine := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8)])
	var c := engine.sides[0].active()
	var b := engine.sides[1].active()
	check(not engine.apply_condition(b, &"leech_seed", true), "Vampigraine sans effet sur un Pokémon Plante")
	check(engine.apply_condition(c, &"leech_seed", true), "Vampigraine posée sur Salamèche")
	b.hp -= 5
	var c_hp := c.hp
	var b_hp := b.hp
	c.get_volatile(&"leech_seed").on_end_turn(engine, c)
	var drained := c_hp - c.hp
	check_eq(drained, BattleRules.fraction(c.max_hp, 8), "Vampigraine draine 1/8 des PV")
	check_eq(b.hp - b_hp, drained, "Vampigraine soigne le Pokémon d'en face")
	engine.switch_pokemon(0, 0)
	check(not c.has_volatile(&"leech_seed"), "Vampigraine disparaît quand le Pokémon est rappelé")


func _test_turn_order() -> void:
	var engine := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8)])
	# Salamèche (Vitesse 65) est plus rapide que Bulbizarre (45).
	var fast := move_action(0)
	var slow := MoveAction.new(0)
	slow.side = 1
	var order := ActionOrder.sort([slow, fast] as Array[BattleAction], engine)
	check(order[0] == fast, "le plus rapide agit d'abord")
	var switch := SwitchAction.new(0)
	switch.side = 1
	order = ActionOrder.sort([fast, switch] as Array[BattleAction], engine)
	check(order[0] == switch, "un changement passe avant une attaque")
	var quick: MoveData = SCRATCH.duplicate()
	quick.priority = 1
	engine.sides[1].active().moves[0] = quick
	order = ActionOrder.sort([fast, slow] as Array[BattleAction], engine)
	check(order[0] == slow, "une attaque prioritaire passe avant, même plus lente")


func _test_victory_and_defeat() -> void:
	var engine := battle([mon(CHARMANDER, 50)], [mon(BULBASAUR, 2)])
	check_eq(engine.submit_action(move_action(2)), "", "action acceptée")
	var events := engine.take_events()
	check_eq(engine.phase, BattleEngine.Phase.FINISHED, "combat terminé après le K.O.")
	check_eq(engine.outcome, BattleEngine.Outcome.WIN, "victoire")
	check_eq(events_of(events, &"faint").size(), 1, "K.O. annoncé une fois")
	check_eq(events.back()["type"], &"battle_end", "dernier évènement : fin du combat")
	check(engine.sides[0].team[0].source.current_hp > 0, "PV synchronisés après le combat")
	var lost := battle([mon(BULBASAUR, 2)], [mon(CHARMANDER, 50, [EMBER])])
	lost.submit_action(move_action(0))
	check_eq(lost.outcome, BattleEngine.Outcome.LOSS, "défaite")
	check(lost.sides[0].team[0].source.is_fainted(), "le Pokémon K.O. le reste après le combat")
	check(lost.submit_action(move_action(0)) != "", "plus d'action possible après la fin")


func _test_replacement() -> void:
	var engine := battle([mon(BULBASAUR, 2), mon(CHARMANDER, 8)], [mon(CHARMANDER, 50, [EMBER])])
	engine.submit_action(move_action(0))
	check(engine.needs_replacement(0), "après un K.O., le joueur doit envoyer un autre Pokémon")
	check(engine.submit_replacement(0, 0) != "", "impossible d'envoyer un Pokémon K.O.")
	check_eq(engine.submit_replacement(0, 1), "", "envoi du Pokémon de réserve")
	check(engine.needs_action(0), "le combat reprend")
	check_eq(engine.sides[0].active().name, "Salamèche", "Salamèche est au combat")


func _test_run() -> void:
	var engine := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8)])
	var run := RunAction.new()
	run.side = 0
	check(engine.submit_action(run) != "", "pas de fuite contre un dresseur")
	var wild := BattleEngine.new(null, 3)
	var a: Array[PokemonInstance] = [mon(CHARMANDER, 8)]
	var b: Array[PokemonInstance] = [mon(BULBASAUR, 8)]
	wild.add_side("Joueur", a, true)
	wild.add_side("Bulbizarre sauvage", b, false, BattleAI.create(&"random"))
	wild.is_wild = true
	wild.can_run = true
	wild.start()
	check_eq(wild.submit_action(run), "", "fuite permise contre un Pokémon sauvage")
	check_eq(wild.outcome, BattleEngine.Outcome.ESCAPED, "le plus rapide fuit à coup sûr")


func _test_items() -> void:
	var engine := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8, [GROWL])])
	var bag := Bag.new()
	bag.add(POTION, 2)
	engine.sides[0].bag = bag
	var item := ItemAction.new(&"potion", 0)
	item.side = 0
	check(engine.submit_action(item) != "", "pas de Potion sur un Pokémon en pleine forme")
	var c := engine.sides[0].active()
	c.hp = 3
	check_eq(engine.submit_action(item), "", "Potion utilisée")
	check_eq(c.hp, mini(c.max_hp, 23), "Potion : +20 PV")
	check_eq(bag.count(POTION), 1, "une Potion consommée")


func _test_struggle() -> void:
	var engine := battle([mon(CHARMANDER, 8, [SCRATCH])], [mon(BULBASAUR, 8, [GROWL])])
	var c := engine.sides[0].active()
	c.pp[0] = 0
	check(engine.submit_action(move_action(0)) != "", "attaque sans PP refusée")
	check_eq(engine.submit_action(move_action(MoveAction.STRUGGLE)), "", "Lutte permise sans PP")
	var events := engine.take_events()
	var recoil := events_of(events, &"recoil")
	check_eq(recoil.size(), 1, "Lutte : contrecoup")


func _test_network_round_trip() -> void:
	var a := ItemAction.new(&"potion", 2)
	a.side = 1
	var back := BattleAction.from_dict(a.to_dict())
	check(back is ItemAction and back.item_id == &"potion" and back.team_index == 2 and back.side == 1, "action transmise par dictionnaire")
	var engine := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8)])
	var snap := engine.snapshot(0)
	check_eq(snap["sides"][0]["team"][0]["moves"].size(), 4, "le joueur voit ses attaques")
	check(not snap["sides"][1]["team"][0].has("moves"), "le joueur ne voit pas les attaques adverses")


func _test_experience() -> void:
	check_eq(Growth.experience_for(&"medium", 10), 1000, "courbe moyenne : 1000 Exp. au niveau 10")
	check_eq(Growth.experience_for(&"medium-slow", 5), 135, "courbe parabolique : 135 Exp. au niveau 5")
	check_eq(Growth.experience_for(&"fast", 100), 800000, "courbe rapide : 800 000 Exp. au niveau 100")
	check_eq(Growth.experience_for(&"slow-then-very-fast", 100), 600000, "courbe erratique : 600 000 Exp. au niveau 100")
	check_eq(Growth.experience_for(&"fast-then-very-slow", 100), 1640000, "courbe fluctuante : 1 640 000 Exp. au niveau 100")
	check_eq(Growth.level_for(&"medium", 999), 9, "999 Exp. : niveau 9 (courbe moyenne)")
	var fresh := PokemonInstance.create(CHARMANDER, 8)
	check_eq(fresh.experience, fresh.level_floor(), "un Pokémon neuf a l'Exp. de son niveau")
	# Victoire : l'Exp. gagnée fait monter de niveau.
	var winner := mon(CHARMANDER, 5)
	var engine := battle([winner], [mon(BULBASAUR, 30, [GROWL])])
	engine.sides[1].team[0].hp = 1
	engine.submit_action(move_action(0))
	var events := engine.take_events()
	check_eq(engine.outcome, BattleEngine.Outcome.WIN, "victoire contre un Pokémon de haut niveau")
	var gains := events_of(events, &"exp_gain")
	check(not gains.is_empty() and gains[0]["amount"] > 0, "Exp. gagnée annoncée")
	check(winner.level > 5, "le Pokémon monte de niveau (niveau %d)" % winner.level)
	check_eq(events_of(events, &"level_up").size(), winner.level - 5, "une annonce par niveau gagné")
	check(winner.experience >= winner.level_floor() and winner.experience < winner.next_level_experience(),
		"Exp. cohérente avec le niveau")
	check(winner.moves.size() <= 4, "jamais plus de quatre attaques")
	check(engine.leveled_up.has(winner), "le moteur note les Pokémon qui ont monté")
	# Partage : deux Pokémon qui ont affronté l'adversaire se partagent l'Exp.
	var a := mon(CHARMANDER, 10)
	var b := mon(CHARMANDER, 10)
	var shared := battle([a, b], [mon(BULBASAUR, 10, [GROWL])])
	var switch := SwitchAction.new(1)
	switch.side = 0
	shared.submit_action(switch)
	shared.sides[1].team[0].hp = 1
	shared.submit_action(move_action(0))
	check(a.experience > a.level_floor() and b.experience > b.level_floor(), "l'Exp. est partagée entre les deux")
	# Un Pokémon déjà sauvegardé sans Exp. reprend celle de son niveau.
	var old := PokemonInstance.create(BULBASAUR, 12).to_dict()
	old["experience"] = 0
	var loaded := PokemonInstance.from_dict(old)
	check_eq(loaded.experience, loaded.level_floor(), "ancienne sauvegarde : Exp. du niveau rétablie")


func _test_evolution() -> void:
	check_eq(BULBASAUR.evolutions.size(), 1, "Bulbizarre a une évolution")
	check_eq(BULBASAUR.evolutions[0].species_id, &"ivysaur", "vers Herbizarre")
	check_eq(BULBASAUR.evolutions[0].min_level, 16, "au niveau 16")
	var eevee := PokemonSpecies.find(&"eevee")
	check(eevee != null and eevee.evolutions.size() >= 5, "Évoli a plusieurs évolutions")
	var bulb := mon(BULBASAUR, 15)
	check(bulb.ready_evolution() == null, "pas d'évolution avant le niveau 16")
	bulb.gain_experience(bulb.next_level_experience() - bulb.experience)
	check_eq(bulb.level, 16, "niveau 16 atteint")
	var next := bulb.ready_evolution()
	check(next != null and next.id == &"ivysaur", "Herbizarre prêt")
	var hp_before := bulb.max_hp()
	bulb.evolve_into(next)
	check_eq(bulb.species.id, &"ivysaur", "le Pokémon est devenu Herbizarre")
	check(bulb.max_hp() > hp_before, "ses statistiques augmentent")
	check(bulb.ability_data() != null, "il garde un talent valide")


func _test_capture() -> void:
	var ball: BallItem = load("res://data/items/poke_ball.tres")
	check(ball != null and ball.usable_in_battle, "la Poké Ball s'utilise en combat")
	# Contre un dresseur : refusé.
	var trainer := battle([mon(CHARMANDER, 8)], [mon(BULBASAUR, 8, [GROWL])])
	var bag := Bag.new()
	bag.add(ball, 5)
	trainer.sides[0].bag = bag
	var throw := ItemAction.new(&"poke_ball", -1)
	throw.side = 0
	check(trainer.submit_action(throw) != "", "pas de capture contre un dresseur")
	# Contre un Pokémon sauvage très affaibli et endormi : capture quasi sûre.
	var wild := BattleEngine.new(null, 5)
	var a: Array[PokemonInstance] = [mon(CHARMANDER, 8)]
	var target := mon(BULBASAUR, 3, [GROWL])
	var b: Array[PokemonInstance] = [target]
	wild.add_side("Joueur", a, true).bag = bag
	wild.add_side("", b, false, BattleAI.create(&"random"))
	wild.is_wild = true
	wild.can_run = true
	wild.sides[0].balls_left = 2
	wild.start()
	wild.take_events()
	var foe := wild.sides[1].active()
	foe.hp = 1
	check_eq(wild.capture_shakes(foe, 255.0), BattleEngine.CAPTURE_SHAKES, "Pokémon très faible : capture certaine")
	var odds := 0
	for i in 200:
		if wild.capture_shakes(foe, 1.0) >= BattleEngine.CAPTURE_SHAKES:
			odds += 1
	check(odds > 50, "PV au plus bas, taux 45 : environ une capture sur trois (%d / 200)" % odds)
	foe.hp = foe.max_hp
	var full := 0
	for i in 200:
		if wild.capture_shakes(foe, 1.0) >= BattleEngine.CAPTURE_SHAKES:
			full += 1
	check(full < odds, "PV au maximum : moins de captures (%d / 200)" % full)
	foe.hp = 1
	wild.rng.seed = 2
	var tries := 0
	while wild.phase != BattleEngine.Phase.FINISHED and tries < 2:
		tries += 1
		var t := ItemAction.new(&"poke_ball", -1)
		t.side = 0
		wild.submit_action(t)
		if wild.phase == BattleEngine.Phase.AWAITING_REPLACEMENT:
			break
	check_eq(bag.count(ball), 5 - tries, "chaque lancer coûte une Poké Ball")
	check_eq(wild.sides[0].balls_left, 2 - tries, "le nombre de lancers permis baisse")
	if wild.outcome == BattleEngine.Outcome.CAUGHT:
		check(wild.caught == target, "le Pokémon capturé est le Pokémon sauvage")
	if wild.phase != BattleEngine.Phase.FINISHED:
		var t := ItemAction.new(&"poke_ball", -1)
		t.side = 0
		check(wild.submit_action(t) != "", "plus de lancer une fois la limite atteinte")
	var player := PlayerData.new()
	for i in 6:
		player.party.append(mon(CHARMANDER, 5))
	var message := player.receive_pokemon(target)
	check(player.party.size() == 6 and player.storage.count() == 1, "équipe pleine : le Pokémon capturé va au PC")
	check(message.contains("PC"), "message : envoyé au PC")
