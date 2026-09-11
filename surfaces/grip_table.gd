class_name GripTable
extends Resource
## Car archetype x surface grip multipliers: the main tool for making the right
## car suit the right terrain. Missing entries mean 1.0 (no change).

## Keys are "archetype/surface", for example "rally/mud".
@export var multipliers: Dictionary = {}


func multiplier(archetype: StringName, surface_id: StringName) -> float:
	return float(multipliers.get("%s/%s" % [archetype, surface_id], 1.0))
