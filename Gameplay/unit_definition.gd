class_name UnitDefinition
extends Resource

## How the unit moves along its row at the start of every round after the first.
enum Shift { HOLD, LEFT, RIGHT, BOUNCE }
enum Faction { NONE, BUG, BIRD, MAMMAL }
enum Ability {
	NONE,
	GRAVEYARD,
	ARMY_MARKS,
	OWN_MARKS,
	ALLIES_TO_RIGHT,
	DIE_IF_BLOCKED,
	SWAP_GROWTH,
	HOLD_GROWTH
}

const FACTION_NAMES := {
	Faction.BUG: "Bug",
	Faction.BIRD: "Bird",
	Faction.MAMMAL: "Mammal",
}
const ABILITY_DESCRIPTIONS := {
	Ability.GRAVEYARD: "+1/+1 per graveyard card",
	Ability.ARMY_MARKS: "+1/+1 per MARK on its side",
	Ability.OWN_MARKS: "+4/+4 per MARK on this card",
	Ability.ALLIES_TO_RIGHT: "+1/+1 per ally to its right",
	Ability.DIE_IF_BLOCKED: "Dies if its shift is blocked",
	Ability.SWAP_GROWTH: "+1/+1 when it swaps",
	Ability.HOLD_GROWTH: "+1/+1 each round it holds",
}

@export var title: String
@export_range(1, 99, 1, "or_greater") var attack: int = 1
@export_range(1, 99, 1, "or_greater") var hp: int = 1
@export var shift: Shift = Shift.HOLD
@export var faction: Faction = Faction.NONE
@export var ability: Ability = Ability.NONE
@export_group("Art")
@export var portrait: Texture2D
## Shown once the unit carries at least one MARK. Without it the portrait is tinted.
@export var marked_portrait: Texture2D
## Multiplied into the portrait, e.g. to tell apart bosses that share art.
@export var portrait_tint: Color = Color.WHITE


func starting_shift_direction() -> int:
	match shift:
		Shift.LEFT:
			return -1
		Shift.RIGHT, Shift.BOUNCE:
			return 1
		_:
			return 0


func ability_text() -> String:
	var faction_name: String = FACTION_NAMES.get(faction, "")
	var description: String = ABILITY_DESCRIPTIONS.get(ability, "")
	if faction_name.is_empty() or description.is_empty():
		return faction_name + description
	return "%s · %s" % [faction_name, description]
