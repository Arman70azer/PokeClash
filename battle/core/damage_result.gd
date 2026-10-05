class_name DamageResult
extends RefCounted
## Résultat d'un calcul de dégâts.

var damage := 0
var effectiveness := 1.0
var is_critical := false
var stab := false


func is_immune() -> bool:
	return effectiveness == 0.0
