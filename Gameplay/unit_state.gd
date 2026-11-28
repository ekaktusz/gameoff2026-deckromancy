class_name UnitState
extends RefCounted

const POOP_MARKS := 4

var definition: UnitDefinition
var attack: int
var hp: int
var marks: int = 0
var battle_bonus: int = 0
var bonus_hp: int = 0


func _init(unit_definition: UnitDefinition) -> void:
	definition = unit_definition
	attack = definition.attack
	hp = definition.hp


func title(after_revival: bool = false) -> String:
	return "Poop Warrior" if is_poop_warrior(after_revival) else definition.title


func is_poop_warrior(after_revival: bool = false) -> bool:
	return marks + int(after_revival) >= POOP_MARKS


func revival_stats() -> Vector2i:
	var base_stats := Vector2(definition.attack, definition.hp)
	match marks:
		0:
			return Vector2i(base_stats)
		1:
			return Vector2i((base_stats * 0.7).round()).max(Vector2i.ONE)
		2:
			return Vector2i((base_stats * 0.3).round()).max(Vector2i.ONE)
		_:
			return Vector2i.ONE


func revive() -> void:
	var stats := revival_stats()
	attack = stats.x
	hp = stats.y
	marks += 1
	set_battle_bonus(0)


func combat_attack() -> int:
	return attack + battle_bonus


func combat_hp() -> int:
	return hp + bonus_hp


func set_battle_bonus(amount: int) -> void:
	bonus_hp = clampi(bonus_hp + amount - battle_bonus, 0, amount)
	battle_bonus = amount


func take_damage(amount: int) -> void:
	var absorbed := mini(bonus_hp, amount)
	bonus_hp -= absorbed
	hp = maxi(0, hp - (amount - absorbed))
