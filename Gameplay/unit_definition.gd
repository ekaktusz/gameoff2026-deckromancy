class_name UnitDefinition
extends Resource

@export var title: String
@export_range(1, 99, 1, "or_greater") var attack: int = 1
@export_range(1, 99, 1, "or_greater") var hp: int = 1
