class_name DamageCalculator
extends RefCounted
## Calcul des dégâts d'une attaque, formule de la génération 5. Toute la formule est ici ;
## les cas particuliers passent par les multiplicateurs de DamageContext.


## Prépare le contexte : coup critique et facteur aléatoire tirés avec `rng`.
static func make_context(rules: BattleRules, rng: RandomNumberGenerator, attacker: BattlePokemon, defender: BattlePokemon, move: MoveData) -> DamageContext:
	var context := DamageContext.new()
	context.rules = rules
	context.attacker = attacker
	context.defender = defender
	context.move = move
	context.power = move.power
	context.is_critical = rng.randi_range(1, rules.critical_denominator(move.critical_stage)) == 1
	context.random_percent = rng.randi_range(rules.damage_random_min, rules.damage_random_max)
	context.stab = attacker.has_type(move.type)
	context.effectiveness = PokemonType.effectiveness(move.type, defender.types)
	return context


## Calcule les dégâts d'un contexte déjà préparé (aucun tirage ici : testable).
static func calculate(context: DamageContext) -> DamageResult:
	var result := DamageResult.new()
	result.effectiveness = context.effectiveness
	result.is_critical = context.is_critical
	result.stab = context.stab
	if context.effectiveness == 0.0 or not context.move.is_damaging():
		return result
	var rules := context.rules
	var physical := context.move.category == MoveData.Category.PHYSICAL
	var attack_stat := Stat.ATTACK if physical else Stat.SP_ATTACK
	var defense_stat := Stat.DEFENSE if physical else Stat.SP_DEFENSE
	# Un coup critique ignore les baisses d'attaque du lanceur et les hausses de défense de la cible.
	var attack := context.attacker.effective_stat(attack_stat, rules, false, context.is_critical)
	var defense := context.defender.effective_stat(defense_stat, rules, context.is_critical, false)
	for condition in context.attacker.conditions():
		condition.modify_damage_dealt(context)
	var level := context.attacker.level
	var damage := (2 * level / 5 + 2) * context.power * attack / defense / 50 + 2
	if context.is_critical:
		damage = int(floor(damage * rules.critical_multiplier))
	damage = damage * context.random_percent / 100
	if context.stab:
		damage = int(floor(damage * rules.stab_multiplier))
	damage = int(floor(damage * context.effectiveness))
	for value in context.modifiers.values():
		damage = int(floor(damage * float(value)))
	result.damage = maxi(1, damage)
	return result
