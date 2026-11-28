class_name UnitDefinition
extends Resource

enum Faction { NONE, BUG, BIRD, MAMMAL }
enum Ability {
	NONE,
	GRAVEYARD,
	ARMY_MARKS,
	OWN_MARKS,
	ALLIES_TO_RIGHT,
	DIE_IF_BLOCKED,
	SWAP_GROWTH,
	HOLD_GROWTH,
	SHIFT_LEFT,
	ANCHORED
}

const FACTION_NAMES := {
	Faction.BUG: "Bug",
	Faction.BIRD: "Bird",
	Faction.MAMMAL: "Mammal",
}
const ABILITY_DESCRIPTIONS := {
	Ability.GRAVEYARD: "Base +1/+1 per graveyard card",
	Ability.ARMY_MARKS: "+1/+1 per MARK on its allies",
	Ability.OWN_MARKS: "+4/+4 per MARK on this card",
	Ability.ALLIES_TO_RIGHT: "Shifts left. +1/+1 per ally to its right",
	Ability.DIE_IF_BLOCKED: "Shifts left, hops a still ally, dies if blocked",
	Ability.SWAP_GROWTH: "+1/+1 when it swaps slots",
	Ability.HOLD_GROWTH: "+1/+1 each round it stays put",
	Ability.SHIFT_LEFT: "Shifts left at the start of each round",
	Ability.ANCHORED: "Stays in its slot until it dies",
}

@export var title: String
@export_range(1, 99, 1, "or_greater") var attack: int = 1
@export_range(1, 99, 1, "or_greater") var hp: int = 1
@export var faction: Faction = Faction.NONE
@export var ability: Ability = Ability.NONE
@export_group("Art")
@export var portrait: Texture2D
## Drawn over the base portrait once the unit carries a MARK. Uses the same canvas size.
@export var mark_overlay: Texture2D
## Fallback portrait for units without a separate MARK layer.
@export var marked_portrait: Texture2D
## Multiplied into the portrait, e.g. to tell apart bosses that share art.
@export var portrait_tint: Color = Color.WHITE


func battle_ability(is_enemy: bool) -> Ability:
	return Ability.NONE if is_enemy and ability == Ability.GRAVEYARD else ability


func shifts_left() -> bool:
	return ability in [Ability.SHIFT_LEFT, Ability.ALLIES_TO_RIGHT, Ability.DIE_IF_BLOCKED]


func can_be_displaced() -> bool:
	return faction in [Faction.BUG, Faction.MAMMAL] and ability != Ability.ANCHORED
