class_name EncounterDefinition
extends Resource

@export var title: String
@export var enemies: Array[UnitDefinition] = []
## A positive stage places this encounter on a branching map. Stage 0 uses
## the order in the GameLoop encounter list for simple linear scenes.
@export var map_stage: int = 0
@export_range(-1, 1) var map_lane: int = 0
@export var is_boss: bool = false
## Lanes on the next stage that can be reached after clearing this encounter.
@export var next_lanes: PackedInt32Array = []
