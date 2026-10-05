class_name RecoilEffect
extends MoveEffect
## Le lanceur subit un contrecoup : une fraction des dégâts infligés (Bélier...) ou de
## ses PV max (Lutte).

enum Base {DAMAGE_DEALT, USER_MAX_HP}

@export var base: Base = Base.DAMAGE_DEALT
## Le contrecoup vaut 1 / denominator de la base.
@export var denominator := 4


func _init() -> void:
	who = Who.USER


func _apply(engine: BattleEngine, user: BattlePokemon, _affected: BattlePokemon, _move: MoveData, damage: int) -> void:
	var total := damage if base == Base.DAMAGE_DEALT else user.max_hp
	if total <= 0:
		return
	engine.emit(&"recoil", {"pokemon": engine.ref(user)})
	engine.damage(user, BattleRules.fraction(total, denominator), &"recoil")
