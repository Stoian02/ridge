class_name TunnelDef
extends Resource
## A road tunnel under a ridge. Distances follow the trail centre line.

@export var start: float = 0.0
@export var length: float = 250.0
@export var inner_width: float = 11.0
@export var height: float = 6.0
@export var lamp_spacing: float = 12.0
@export var cover: float = 8.0
@export var portal_length: float = 12.0
@export var wall_color: Color = Color(0.23, 0.27, 0.31)
@export var lamp_color: Color = Color(1.0, 0.88, 0.63)
@export var seed: int = 19


func end() -> float:
	return start + length


func contains(distance: float) -> bool:
	return distance >= start and distance <= end()
