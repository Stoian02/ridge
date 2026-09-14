class_name SurfaceStretch
extends Resource
## A stretch of a trail's road with another surface than the trail's base, such
## as mud with two wheel ruts. Distances are metres along the road.

@export var start: float = 0.0
@export var length: float = 50.0
@export var surface: SurfaceDef
@export var color: Color = Color(0.27, 0.2, 0.14)
## Depth of the two wheel ruts (m); 0 = no ruts.
@export var rut_depth: float = 0.0
## Distance between the two ruts' centre lines, centred on the road (m).
@export var rut_spacing: float = 1.55
## Width of each rut (m).
@export var rut_width: float = 0.8
## The colour and the ruts fade in over this distance inside each end (m).
@export var blend_length: float = 2.0


func end() -> float:
	return start + length


func contains(distance: float) -> bool:
	return distance >= start and distance < end()


## How strongly the stretch shows at `distance`: 0 outside it, rising to 1 over
## blend_length inside each end.
func weight(distance: float) -> float:
	if not contains(distance):
		return 0.0
	var blend := maxf(blend_length, 0.001)
	return minf(smoothstep(start, start + blend, distance), 1.0 - smoothstep(end() - blend, end(), distance))
