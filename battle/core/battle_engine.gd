class_name BattleEngine
extends RefCounted
## Moteur de combat : toute la logique, sans aucun affichage. Il reçoit les actions des
## camps, déroule les tours et produit une liste d'évènements (« Salamèche utilise
## Flammèche », « -12 PV », « K.O. »...) que la scène de combat joue ensuite, que les
## tests vérifient et que l'hôte envoie aux joueurs.
##
## Déroulement : setup (add_side) -> start() -> pour chaque tour, submit_action() de
## chaque camp humain (les camps IA choisissent seuls) -> résolution automatique ->
## éventuellement submit_replacement() après un K.O. -> ... -> phase FINISHED.
## Les étapes d'un tour sont la liste `turn_steps`, modifiable pour d'autres règles.
##
## Une attaque qu'un Pokémon du joueur ne peut pas apprendre (quatre déjà connues) est
## mise de côté ; à la fin du tour, le combat s'arrête (AWAITING_MOVE_CHOICE) jusqu'à ce
## que le joueur choisisse l'attaque à oublier, ou de ne pas l'apprendre
## (submit_move_choice). Celles proposées après la fin du combat (dernier K.O.,
## évolution) se choisissent de même, le combat étant FINISHED.

enum Phase {NOT_STARTED, AWAITING_ACTIONS, AWAITING_REPLACEMENT, FINISHED, AWAITING_MOVE_CHOICE}
enum Outcome {NONE, WIN, LOSS, ESCAPED, CANCELLED, CAUGHT}

## Secousses de la Ball avant une capture réussie (génération 5).
const CAPTURE_SHAKES := 3

const STRUGGLE_PATH := "res://data/moves/struggle.tres"

var rules: BattleRules
var rng := RandomNumberGenerator.new()
var sides: Array[BattleSide] = []
var phase: Phase = Phase.NOT_STARTED
var turn := 0
## Résultat pour le camp 0 (le joueur) : victoire, défaite, fuite, annulé.
var outcome: Outcome = Outcome.NONE
## Combat contre un Pokémon sauvage, fuite permise.
var is_wild := false
var can_run := false
var struggle_move: MoveData
## Pokémon sauvage capturé (son PokemonInstance), ou null.
var caught: PokemonInstance
## Pokémon du joueur qui ont monté de niveau pendant le combat (pour les évolutions).
var leveled_up: Array[PokemonInstance] = []
## Étapes d'un tour, dans l'ordre (voir _step_*). Une règle personnalisée peut en
## ajouter, en retirer ou les réordonner.
var turn_steps: Array[Callable] = []

var _events: Array[Dictionary] = []
var _pending := {}  # index de camp -> BattleAction
var _awaiting_replacement: Array[int] = []
## Attaques à proposer au joueur : {"source": PokemonInstance, "battler": BattlePokemon
## (null après le combat), "move": MoveData}. La première est celle en cours de choix.
var _move_offers: Array[Dictionary] = []
var _offers_open := false
var _after_offers := Callable()


func _init(p_rules: BattleRules = null, seed := -1) -> void:
	rules = p_rules if p_rules != null else BattleRules.default_rules()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	struggle_move = load(STRUGGLE_PATH)
	if struggle_move == null:
		push_error("BattleEngine : attaque Lutte introuvable (%s)" % STRUGGLE_PATH)
	turn_steps = [_step_turn_start, _step_actions, _step_end_of_turn, _step_after_turn]


# --- Mise en place -------------------------------------------------------------------

## Ajoute un camp ; ses Pokémon sont copiés depuis `team`. Renvoie le camp, ou null si
## l'équipe est invalide (erreur explicite).
func add_side(side_name: String, team: Array[PokemonInstance], is_human: bool, ai: BattleAI = null) -> BattleSide:
	if team.is_empty():
		push_error("BattleEngine : l'équipe de « %s » est vide" % side_name)
		return null
	if not is_human and ai == null:
		push_error("BattleEngine : le camp « %s » n'a ni joueur ni IA" % side_name)
		return null
	var side := BattleSide.new()
	side.index = sides.size()
	side.name = side_name
	side.is_human = is_human
	side.ai = ai
	for i in team.size():
		var pokemon := BattlePokemon.from_instance(team[i], side.index, i, rules)
		if pokemon == null:
			return null
		# Un statut conservé d'un combat précédent reprend là où il en était.
		if not team[i].status.is_empty():
			pokemon.status = BattleConditions.create(team[i].status)
			if pokemon.status != null:
				pokemon.status.counter = team[i].status_counter
		side.team.append(pokemon)
	if not side.has_usable_pokemon():
		push_error("BattleEngine : aucun Pokémon de « %s » ne peut se battre" % side_name)
		return null
	sides.append(side)
	return side


func start() -> void:
	if sides.size() != 2:
		push_error("BattleEngine.start : il faut deux camps (%d)" % sides.size())
		return
	emit(&"battle_start", {"wild": is_wild, "sides": sides.map(func(s: BattleSide) -> String: return s.name)})
	# L'adversaire d'abord, comme dans les jeux : le joueur envoie son Pokémon ensuite.
	for i in [1, 0]:
		_send_out(sides[i], sides[i].first_usable_index())
	turn = 1
	_begin_choice()


# --- Interface avec les joueurs ------------------------------------------------------

## Vrai si ce camp doit choisir une action maintenant.
func needs_action(side_index: int) -> bool:
	return phase == Phase.AWAITING_ACTIONS and sides[side_index].is_human and not _pending.has(side_index)


## Vrai si ce camp doit choisir un Pokémon à envoyer après un K.O.
func needs_replacement(side_index: int) -> bool:
	return phase == Phase.AWAITING_REPLACEMENT and side_index in _awaiting_replacement


## Enregistre l'action d'un camp humain. Renvoie la raison du refus, ou "" si acceptée.
## Le tour se résout dès que tous les camps humains ont choisi.
func submit_action(action: BattleAction) -> String:
	if action == null:
		return "Action invalide."
	if action.side < 0 or action.side >= sides.size() or not needs_action(action.side):
		return "Ce n'est pas le moment de choisir une action."
	var reason := action.validate(self)
	if not reason.is_empty():
		return reason
	_pending[action.side] = action
	if _all_humans_ready():
		_resolve_turn()
	return ""


## Envoie un Pokémon après un K.O. Renvoie la raison du refus, ou "".
func submit_replacement(side_index: int, team_index: int) -> String:
	if not needs_replacement(side_index):
		return "Ce n'est pas le moment de changer de Pokémon."
	var side := sides[side_index]
	if not team_index in side.available_reserves():
		return "Ce Pokémon ne peut pas se battre."
	_send_out(side, team_index)
	_awaiting_replacement.erase(side_index)
	if _awaiting_replacement.is_empty():
		turn += 1
		_begin_choice()
	return ""


## Vrai si le joueur de ce camp doit choisir l'attaque à oublier.
func needs_move_choice(side_index: int) -> bool:
	return _offers_open and side_index == 0 and not _move_offers.is_empty()


## Vrai s'il reste des attaques à proposer (le combat ne peut pas être refermé).
func has_move_offers() -> bool:
	return not _move_offers.is_empty()


## Met de côté une attaque que ce Pokémon du joueur ne peut pas apprendre faute de place.
## `battler` : son double en combat, à tenir à jour (null après le combat).
func offer_move(source: PokemonInstance, move: MoveData, battler: BattlePokemon = null) -> void:
	if source != null and move != null and not move in source.moves:
		_move_offers.append({"source": source, "battler": battler, "move": move})


## Après la fin du combat : propose les attaques mises de côté (dernier K.O., évolution).
## Faux s'il n'y en a aucune.
func open_move_offers() -> bool:
	return _open_offers(Callable())


## Réponse du joueur : `forget_index` est l'attaque à oublier (0 à 3), ou -1 pour ne pas
## apprendre la nouvelle. Renvoie la raison du refus, ou "".
func submit_move_choice(side_index: int, forget_index: int) -> String:
	if not needs_move_choice(side_index):
		return "Ce n'est pas le moment."
	var offer: Dictionary = _move_offers[0]
	var source: PokemonInstance = offer["source"]
	var move: MoveData = offer["move"]
	if forget_index >= source.moves.size():
		return "Cette attaque n'existe pas."
	var who := source.display_name()
	if forget_index < 0:
		emit(&"move_declined", {"name": who, "move_name": move.name})
	else:
		var forgotten := source.replace_move(forget_index, move)
		var battler: BattlePokemon = offer["battler"]
		if battler != null and phase != Phase.FINISHED:
			battler.moves[forget_index] = move
			battler.pp[forget_index] = move.pp
		emit(&"move_replaced", {"name": who, "old_move_name": forgotten.name, "move_name": move.name})
	_move_offers.pop_front()
	if _present_offer():
		return ""
	_offers_open = false
	if phase == Phase.AWAITING_MOVE_CHOICE:
		var resume := _after_offers
		_after_offers = Callable()
		resume.call()
	return ""


## Interrompt le combat (un joueur quitte la partie...).
func cancel() -> void:
	_move_offers.clear()
	_offers_open = false
	if phase != Phase.FINISHED:
		_finish(Outcome.CANCELLED)


## Évènements produits depuis le dernier appel.
func take_events() -> Array[Dictionary]:
	var taken := _events
	_events = []
	return taken


## Tout ce que l'interface d'un camp doit savoir : les deux camps, ses attaques et son
## sac. Seules des données simples (envoyables par le réseau).
func snapshot(side_index: int) -> Dictionary:
	var data := {
		"turn": turn, "phase": phase, "can_run": can_run, "wild": is_wild,
		"needs_action": needs_action(side_index), "needs_replacement": needs_replacement(side_index),
		"needs_move_choice": needs_move_choice(side_index),
		"sides": [], "bag": [],
	}
	if needs_move_choice(side_index):
		data["move_choice"] = _move_choice_info()
	for side in sides:
		var team := []
		for pokemon in side.team:
			team.append(_pokemon_info(pokemon, side.index == side_index))
		data["sides"].append({"name": side.name, "active": side.active_index, "team": team})
	var own := sides[side_index]
	data["balls_left"] = own.balls_left
	if own.bag != null:
		for item in own.bag.battle_items():
			data["bag"].append({"id": String(item.id), "name": item.name, "count": own.bag.count(item),
				"description": item.description, "ball": item is BallItem})
	return data


# --- Déroulement d'un tour -----------------------------------------------------------

func _begin_choice() -> void:
	phase = Phase.AWAITING_ACTIONS
	_pending.clear()
	emit(&"choose_action", {"turn": turn})


func _all_humans_ready() -> bool:
	for side in sides:
		if side.is_human and not _pending.has(side.index):
			return false
	return true


func _resolve_turn() -> void:
	for side in sides:
		if not side.is_human:
			_pending[side.index] = side.ai.choose_action(self, side)
	for step in turn_steps:
		if phase == Phase.FINISHED:
			return
		step.call()


func _step_turn_start() -> void:
	for pokemon in _active_by_speed():
		for condition in pokemon.conditions():
			condition.on_turn_start(self, pokemon)


func _step_actions() -> void:
	var actions: Array[BattleAction] = []
	for action in _pending.values():
		actions.append(action)
	for action in ActionOrder.sort(actions, self):
		if phase == Phase.FINISHED:
			return
		var actor := sides[action.side].active()
		# Un Pokémon mis K.O. plus tôt dans le tour n'attaque pas.
		if action.kind == BattleAction.Kind.MOVE and (actor == null or actor.is_fainted()):
			continue
		action.execute(self)
		_announce_faints()
		if _check_battle_over():
			return


func _step_end_of_turn() -> void:
	for pokemon in _active_by_speed():
		var ordered := pokemon.conditions()
		ordered.sort_custom(func(a: BattleCondition, b: BattleCondition) -> bool: return a.end_turn_order < b.end_turn_order)
		for condition in ordered:
			if pokemon.is_fainted():
				break
			# Un statut guéri entre-temps ne s'applique plus.
			if condition in pokemon.conditions():
				condition.on_end_turn(self, pokemon)
	_announce_faints()
	_check_battle_over()


func _step_after_turn() -> void:
	# Attaques à apprendre d'abord : le tour reprend ici une fois qu'elles sont choisies.
	if _open_offers(_step_after_turn):
		return
	_awaiting_replacement.clear()
	for side in sides:
		var active := side.active()
		if active != null and active.is_fainted():
			if side.is_human:
				_awaiting_replacement.append(side.index)
			else:
				_send_out(side, side.ai.choose_replacement(self, side))
	if _awaiting_replacement.is_empty():
		turn += 1
		_begin_choice()
	else:
		phase = Phase.AWAITING_REPLACEMENT
		for index in _awaiting_replacement:
			emit(&"choose_replacement", {"side": index})


## Pokémon actifs, du plus rapide au plus lent (ordre des effets de début et fin de tour).
func _active_by_speed() -> Array[BattlePokemon]:
	var active: Array[BattlePokemon] = []
	for side in sides:
		if side.active() != null and not side.active().is_fainted():
			active.append(side.active())
	active.sort_custom(func(a: BattlePokemon, b: BattlePokemon) -> bool:
		return a.effective_stat(Stat.SPEED, rules) > b.effective_stat(Stat.SPEED, rules))
	return active


# --- Actions -------------------------------------------------------------------------

## Exécute une attaque (appelé par MoveAction).
func execute_move(user: BattlePokemon, move_index: int) -> void:
	var move: MoveData = struggle_move if move_index == MoveAction.STRUGGLE else user.moves[move_index]
	for condition in user.conditions():
		if not condition.before_move(self, user, move):
			return
	if move_index != MoveAction.STRUGGLE:
		user.pp[move_index] -= 1
	emit(&"move_used", {"pokemon": ref(user), "move": String(move.id), "move_name": move.name,
		"type": move.type, "category": move.category, "contact": move.makes_contact,
		"animation": String(move.animation)})
	var target := user if move.target == MoveData.Target.USER else opponent_active(user)
	if target == null or target.is_fainted():
		emit(&"move_failed", {"pokemon": ref(user), "reason": "no_target"})
		return
	if target != user and not _accuracy_hits(user, target, move):
		emit(&"move_missed", {"pokemon": ref(user), "target": ref(target)})
		return
	var damage := 0
	if move.is_damaging():
		var context := DamageCalculator.make_context(rules, rng, user, target, move)
		if move == struggle_move:
			# Lutte n'a pas de type : ni efficacité, ni bonus de même type.
			context.effectiveness = 1.0
			context.stab = false
		var result := DamageCalculator.calculate(context)
		if result.is_immune():
			emit(&"no_effect", {"target": ref(target)})
			return
		damage = mini(result.damage, target.hp)
		emit(&"hit", {"target": ref(target), "move": String(move.id), "effectiveness": result.effectiveness})
		self.damage(target, result.damage, &"move")
		if result.is_critical:
			emit(&"critical_hit", {"target": ref(target)})
		if result.effectiveness != 1.0:
			emit(&"effectiveness", {"target": ref(target), "value": result.effectiveness})
		for condition in target.conditions():
			condition.on_hit(self, target, move)
	elif move.effects.is_empty():
		emit(&"move_failed", {"pokemon": ref(user), "reason": "no_effect"})
	for effect in move.effects:
		effect.apply(self, user, target, move, damage)


func switch_pokemon(side_index: int, team_index: int) -> void:
	var side := sides[side_index]
	var leaving := side.active()
	if leaving != null:
		for condition in leaving.conditions():
			condition.on_switch_out(self, leaving)
		leaving.volatiles.clear()
		leaving.reset_stages()
		emit(&"withdraw", {"pokemon": ref(leaving)})
	_send_out(side, team_index)


func use_item(side_index: int, item: ItemData, team_index: int) -> void:
	if item is BallItem:
		throw_ball(side_index, item)
		return
	var side := sides[side_index]
	var target := side.team[team_index]
	if not side.bag.remove(item):
		push_error("BattleEngine : %s introuvable dans le sac" % item.id)
		return
	emit(&"item_used", {"side": side_index, "side_name": side.name, "item": String(item.id),
		"item_name": item.name, "target": ref(target)})
	item.use_on(self, target)


## Lance une Ball sur le Pokémon sauvage (formule de capture de la génération 5) : chaque
## secousse réussie le retient un peu plus ; après trois, il est capturé.
func throw_ball(side_index: int, ball: BallItem) -> void:
	var side := sides[side_index]
	var target := opponent_active(side.active())
	if not side.bag.remove(ball):
		push_error("BattleEngine : %s introuvable dans le sac" % ball.id)
		return
	if side.balls_left > 0:
		side.balls_left -= 1
	var shakes := capture_shakes(target, ball.catch_modifier)
	var success := shakes >= CAPTURE_SHAKES
	emit(&"ball_thrown", {"side": side_index, "item": String(ball.id), "item_name": ball.name,
		"target": ref(target), "shakes": shakes, "caught": success, "balls_left": side.balls_left})
	if success:
		caught = target.source
		_finish(Outcome.CAUGHT)


## Nombre de secousses (0 à 3) avant que le Pokémon ne sorte ; 3 = capturé.
func capture_shakes(target: BattlePokemon, modifier: float) -> int:
	var status_bonus := 1.0
	if target.status != null:
		status_bonus = 2.5 if target.status.id in [&"sleep", &"freeze"] else 1.5
	var a := (3.0 * target.max_hp - 2.0 * target.hp) * target.species.catch_rate * modifier / (3.0 * target.max_hp) * status_bonus
	if a >= 255.0:
		return CAPTURE_SHAKES
	var b := 65536.0 / pow(255.0 / maxf(a, 0.1), 0.1875)
	var shakes := 0
	while shakes < CAPTURE_SHAKES and rng.randi_range(0, 65535) < b:
		shakes += 1
	return shakes


## Tentative de fuite (formule de la génération 5).
func try_run(side_index: int) -> void:
	var side := sides[side_index]
	var mine := side.active().effective_stat(Stat.SPEED, rules)
	var theirs := maxi(1, opponent_active(side.active()).effective_stat(Stat.SPEED, rules))
	side.run_attempts += 1
	var odds := (mine * 128 / theirs + 30 * side.run_attempts) % 256
	if mine >= theirs or rng.randi_range(0, 255) < odds:
		emit(&"run_success", {"side": side_index})
		_finish(Outcome.ESCAPED)
	else:
		emit(&"run_failed", {"side": side_index})


# --- Opérations utilisées par les attaques, statuts et objets ------------------------

func emit(type: StringName, data := {}) -> void:
	var event := data.duplicate()
	event["type"] = type
	_events.append(event)


## Référence à un Pokémon dans un évènement : camp, place dans l'équipe et nom.
func ref(pokemon: BattlePokemon) -> Dictionary:
	return {"side": pokemon.side, "slot": pokemon.team_index, "name": pokemon.name}


## Le Pokémon actif d'en face.
func opponent_active(pokemon: BattlePokemon) -> BattlePokemon:
	for side in sides:
		if side.index != pokemon.side:
			return side.active()
	return null


func damage(pokemon: BattlePokemon, amount: int, cause: StringName) -> void:
	if pokemon.is_fainted() or amount <= 0:
		return
	var dealt := mini(amount, pokemon.hp)
	pokemon.hp -= dealt
	emit(&"hp_change", {"pokemon": ref(pokemon), "hp": pokemon.hp, "max_hp": pokemon.max_hp, "delta": -dealt, "cause": cause})


func heal(pokemon: BattlePokemon, amount: int) -> void:
	if pokemon.is_fainted():
		return
	var healed := mini(amount, pokemon.max_hp - pokemon.hp)
	if healed <= 0:
		return
	pokemon.hp += healed
	emit(&"hp_change", {"pokemon": ref(pokemon), "hp": pokemon.hp, "max_hp": pokemon.max_hp, "delta": healed, "cause": &"heal"})


## Change un niveau de statistique. `announce_failure` : annoncer qu'il ne peut plus
## monter ou baisser (attaque de statut) ; sinon l'échec est silencieux.
func change_stage(pokemon: BattlePokemon, stat: int, delta: int, announce_failure: bool) -> bool:
	var current: int = pokemon.stages.get(stat, 0)
	var updated := clampi(current + delta, rules.stage_min, rules.stage_max)
	if updated == current:
		if announce_failure:
			emit(&"stat_unchanged", {"pokemon": ref(pokemon), "stat": stat, "rising": delta > 0})
		return false
	pokemon.stages[stat] = updated
	emit(&"stat_change", {"pokemon": ref(pokemon), "stat": stat, "delta": delta})
	return true


## Pose un statut ou un effet volatil. `announce_failure` : annoncer l'échec.
func apply_condition(target: BattlePokemon, id: StringName, announce_failure: bool) -> bool:
	var condition := BattleConditions.create(id)
	if condition == null:
		return false
	var blocked := ""
	if condition.is_major and target.status != null:
		blocked = "already_major"
	elif not condition.is_major and target.has_volatile(id):
		blocked = "already"
	elif not condition.can_apply(self, target):
		blocked = "immune"
	if not blocked.is_empty():
		if announce_failure:
			emit(&"condition_failed", {"pokemon": ref(target), "condition": id, "reason": blocked})
		return false
	if condition.is_major:
		target.status = condition
	else:
		target.volatiles.append(condition)
	condition.on_apply(self, target)
	emit(&"condition_applied", {"pokemon": ref(target), "condition": id, "short": condition.short_name})
	return true


## Guérit le statut principal. `reason` : &"cured" (objet), &"wake_up", &"thaw".
func cure_status(pokemon: BattlePokemon, reason: StringName = &"cured") -> void:
	if pokemon.status == null:
		return
	var id := pokemon.status.id
	pokemon.status = null
	emit(&"condition_cured", {"pokemon": ref(pokemon), "condition": id, "reason": reason})


# --- Interne ---------------------------------------------------------------------------

## Note quels Pokémon du joueur affrontent le Pokémon adverse actif.
func _mark_participation() -> void:
	if sides.size() < 2 or sides[0].active() == null or sides[1].active() == null:
		return
	var foe := sides[1].active()
	var own := sides[0].active()
	if not own.is_fainted() and not own.team_index in foe.fought_by:
		foe.fought_by.append(own.team_index)


## Expérience pour les Pokémon du joueur qui ont affronté `defeated` (formule de la
## génération 5, partagée entre eux), avec montées de niveau et nouvelles attaques.
func _award_experience(defeated: BattlePokemon) -> void:
	var earners: Array[BattlePokemon] = []
	for index in defeated.fought_by:
		var pokemon := sides[0].team[index]
		if not pokemon.is_fainted() and pokemon.level < Growth.MAX_LEVEL:
			earners.append(pokemon)
	for pokemon in earners:
		var amount := Growth.reward(defeated.species, defeated.level, pokemon.level, not is_wild, earners.size())
		var steps := pokemon.source.gain_experience(amount)
		emit(&"exp_gain", {"pokemon": ref(pokemon), "amount": amount, "exp_ratio": _exp_ratio(pokemon.source),
			"levels": steps.size()})
		for step in steps:
			pokemon.refresh_from_source(rules)
			if not pokemon.source in leveled_up:
				leveled_up.append(pokemon.source)
			emit(&"level_up", {"pokemon": ref(pokemon), "level": step["level"], "hp": pokemon.hp, "max_hp": pokemon.max_hp})
			for move in step["learned"]:
				emit(&"move_learned", {"pokemon": ref(pokemon), "move_name": move.name})
			for move in step["skipped"]:
				offer_move(pokemon.source, move, pokemon)


## Ouvre le choix des attaques mises de côté ; `resume` reprend le combat une fois toutes
## choisies (vide après la fin du combat). Faux s'il n'y a rien à proposer.
func _open_offers(resume: Callable) -> bool:
	if _offers_open or not _present_offer():
		return false
	_offers_open = true
	_after_offers = resume
	if phase != Phase.FINISHED:
		phase = Phase.AWAITING_MOVE_CHOICE
	return true


## Annonce la prochaine attaque à proposer (en sautant celles devenues inutiles) ; faux
## s'il n'en reste aucune.
func _present_offer() -> bool:
	while not _move_offers.is_empty():
		var offer: Dictionary = _move_offers[0]
		var source: PokemonInstance = offer["source"]
		var move: MoveData = offer["move"]
		if move in source.moves:
			_move_offers.pop_front()
		elif source.learn_move(move):
			# Une place s'est libérée entre-temps : il l'apprend sans rien oublier.
			var battler: BattlePokemon = offer["battler"]
			if battler != null and phase != Phase.FINISHED:
				battler.moves.append(move)
				battler.pp.append(move.pp)
			emit(&"move_learned", {"pokemon": {"side": 0, "name": source.display_name()}, "move_name": move.name})
			_move_offers.pop_front()
		else:
			emit(&"move_offer", {"name": source.display_name(), "move_name": move.name})
			return true
	return false


## Ce que le joueur doit voir pour choisir : le Pokémon, ses attaques et la nouvelle.
func _move_choice_info() -> Dictionary:
	var offer: Dictionary = _move_offers[0]
	var source: PokemonInstance = offer["source"]
	var battler: BattlePokemon = offer["battler"]
	var move: MoveData = offer["move"]
	var known := []
	for i in source.moves.size():
		var m := source.moves[i]
		var left := battler.pp[i] if battler != null and phase != Phase.FINISHED else source.pp_left(i)
		known.append({"name": m.name, "type": m.type, "pp": left, "max_pp": m.pp})
	return {"name": source.display_name(), "move_name": move.name, "move_type": move.type,
		"move_pp": move.pp, "moves": known}


## Avancée dans le niveau actuel, de 0 à 1.
static func _exp_ratio(pokemon: PokemonInstance) -> float:
	var floor_exp := pokemon.level_floor()
	var span := pokemon.next_level_experience() - floor_exp
	return clampf(float(pokemon.experience - floor_exp) / span, 0.0, 1.0) if span > 0 else 0.0

func _send_out(side: BattleSide, team_index: int) -> void:
	if team_index < 0:
		push_error("BattleEngine : aucun Pokémon à envoyer pour « %s »" % side.name)
		return
	side.active_index = team_index
	var pokemon := side.active()
	pokemon.has_battled = true
	_mark_participation()
	var info := _pokemon_info(pokemon, false)
	info["side_name"] = side.name
	info["wild"] = is_wild and side.index == 1
	emit(&"send_out", {"pokemon": ref(pokemon), "info": info})


func _accuracy_hits(user: BattlePokemon, target: BattlePokemon, move: MoveData) -> bool:
	if move.accuracy == 0:
		return true
	var stage: int = user.stages[Stat.ACCURACY] - target.stages[Stat.EVASION]
	var threshold := int(floor(move.accuracy * rules.accuracy_multiplier(stage)))
	return rng.randi_range(1, 100) <= threshold


func _announce_faints() -> void:
	for side in sides:
		for pokemon in side.team:
			if pokemon.is_fainted() and not pokemon.faint_announced:
				pokemon.faint_announced = true
				emit(&"faint", {"pokemon": ref(pokemon)})
				if side.index == 0:
					pokemon.source.change_happiness(-1)
				if side.index == 1 and sides[0].is_human:
					_award_experience(pokemon)


## Termine le combat si un camp n'a plus de Pokémon. Un camp du joueur sans Pokémon
## perd, même si l'adversaire tombe en même temps.
func _check_battle_over() -> bool:
	if not sides[0].has_usable_pokemon():
		_finish(Outcome.LOSS)
	elif not sides[1].has_usable_pokemon():
		_finish(Outcome.WIN)
	return phase == Phase.FINISHED


func _finish(result: Outcome) -> void:
	outcome = result
	phase = Phase.FINISHED
	for side in sides:
		for pokemon in side.team:
			pokemon.sync_to_source()
	emit(&"battle_end", {"outcome": result})


## Description d'un Pokémon pour l'interface. `with_moves` : attaques et PP (son camp).
func _pokemon_info(pokemon: BattlePokemon, with_moves: bool) -> Dictionary:
	var info := {
		"slot": pokemon.team_index, "name": pokemon.name, "species": pokemon.species.resource_path,
		"level": pokemon.level, "hp": pokemon.hp, "max_hp": pokemon.max_hp,
		"status": pokemon.status.short_name if pokemon.status != null else "",
		"types": pokemon.types.duplicate(),
	}
	if with_moves:
		info["exp_ratio"] = _exp_ratio(pokemon.source)
		var moves := []
		for i in pokemon.moves.size():
			var move := pokemon.moves[i]
			moves.append({"index": i, "id": String(move.id), "name": move.name, "type": move.type,
				"category": move.category, "pp": pokemon.pp[i], "max_pp": move.pp})
		info["moves"] = moves
	return info
