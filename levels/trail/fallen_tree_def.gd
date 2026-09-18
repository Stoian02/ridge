class_name FallenTreeDef
extends Resource
## A fixed, tapered trunk crossing the road. Its root is on the left, its
## thinner tip on the right. Branches are restricted to the off-road root end.

@export var distance: float = 940.0
@export var lateral: float = -1.0
@export var length: float = 12.0
@export_range(-60.0, 60.0) var angle_degrees: float = 25.0
@export var root_radius: float = 0.4
@export var tip_radius: float = 0.18
## Trunk centre below the road surface; the buried lower half has no snagging gap.
@export var burial: float = 0.06
@export var bark_color: Color = Color(0.29, 0.20, 0.13)
@export var wood_color: Color = Color(0.67, 0.49, 0.29)


## (road distance, lateral) at the root (0) or tip (1).
func road_point(t: float) -> Vector2:
	var offset := (t - 0.5) * length
	var angle := deg_to_rad(angle_degrees)
	return Vector2(distance + sin(angle) * offset, lateral + cos(angle) * offset)
