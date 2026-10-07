class_name RoadBarrierDef
extends Resource
## Selective static edge protection, outside the roadway. Empty arrays opt out.

enum Kind { GUARDRAIL, STONE }
@export var start: float = 0.0
@export var length: float = 30.0
@export_enum("Left:-1", "Right:1") var side: int = 1
## Distance inward from the shoulder edge; roadway clearance is checked.
@export var inset: float = 0.10
@export var kind: Kind = Kind.GUARDRAIL
@export var height: float = 0.85
@export var width: float = 0.20
## Both ends flare outward and lower over this distance, never hooking inward.
@export var end_length: float = 4.0
@export var end_flare: float = 0.6
@export var color: Color = Color(0.64, 0.67, 0.65)


func end() -> float:
	return start + length


func end_weight(at: float) -> float:
	var fade := minf(end_length, length * 0.5)
	return minf(smoothstep(start, start + fade, at), 1.0 - smoothstep(end() - fade, end(), at))


func lateral(trail: TrailDef, at: float) -> float:
	return side * (trail.half_total_width_at(at) - inset + end_flare * (1.0 - end_weight(at)))


func validation_error(trail: TrailDef, route_length: float) -> String:
	if start < 0.0 or length <= 0.0 or end() > route_length or not side in [-1, 1]:
		return "Invalid barrier range or side"
	if height <= 0.0 or width <= 0.0 or end_length <= 0.0 or end_flare < 0.0:
		return "Invalid barrier dimensions/end treatment"
	for at: float in [start, (start + end()) * 0.5, end()]:
		if absf(lateral(trail, at)) - width * 0.5 < trail.road_width_at(at) * 0.5 + 0.5:
			return "Barrier intrudes into driving clearance"
	for gap: RoadGapDef in trail.road_gaps:
		if start < gap.recovery_end and end() > gap.takeoff_start - 100.0:
			return "Barrier overlaps the protected jump approach/recovery"
	for tunnel: TunnelDef in trail.tunnels:
		if start < tunnel.end() and end() > tunnel.start:
			return "Barrier overlaps tunnel"
	return ""
