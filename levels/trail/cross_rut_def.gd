class_name CrossRutDef
extends Resource
## An eroded channel across the road. The diagonal centre line is
## distance + lateral * skew. Rounded sides and tapered ends offer line choice.

@export var distance: float = 0.0
@export var lateral_from: float = -4.0
@export var lateral_to: float = 4.0
## Metres forward per metre across the road (negative reverses the diagonal).
@export var skew: float = 0.7
## Full width measured along the road, not perpendicular to the channel.
@export var width: float = 2.4
@export var depth: float = 0.25
@export var end_blend: float = 0.8


func height_at(at: float, lateral: float) -> float:
	var t := absf(at - distance - lateral * skew) / maxf(width * 0.5, 0.001)
	if t >= 1.0 or lateral <= lateral_from or lateral >= lateral_to:
		return 0.0
	var fade := minf(smoothstep(lateral_from, lateral_from + end_blend, lateral),
			1.0 - smoothstep(lateral_to - end_blend, lateral_to, lateral))
	return -depth * (0.5 + 0.5 * cos(PI * t)) * fade


func bounds() -> Vector2:
	return Vector2(distance + minf(lateral_from * skew, lateral_to * skew) - width * 0.5,
			distance + maxf(lateral_from * skew, lateral_to * skew) + width * 0.5)


## Value-only snapshot for independent road workers.
func snapshot() -> PackedFloat64Array:
	return PackedFloat64Array([distance, lateral_from, lateral_to, skew, width, depth, end_blend])
