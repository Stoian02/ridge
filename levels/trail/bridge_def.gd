class_name BridgeDef
extends Resource
## Transverse logs over a gorge, with a dropped far half and a recovery ramp.

@export var start: float = 0.0
@export var length: float = 30.0
@export var drop: float = 0.7
@export var gorge_depth: float = 6.0
@export var gorge_width: float = 40.0
@export var ramp_length: float = 20.0
@export var log_diameter_range: Vector2 = Vector2(0.25, 0.35)
@export var seed: int = 29


func end() -> float:
	return start + length


func contains(distance: float) -> bool:
	return distance >= start and distance < end()


func height_offset(distance: float) -> float:
	if distance < start + length * 0.5 or distance >= end() + ramp_length:
		return 0.0
	return -drop * (1.0 - smoothstep(end(), end() + ramp_length, distance))
