class_name RoadGapDef
extends Resource
## A real missing road span. Heights are offsets from the unchanged curve;
## the lip retains an upward tangent, unlike the existing rounded jump humps.

@export var takeoff_start: float = 835.0
@export var takeoff_end: float = 853.0
@export var landing_start: float = 869.0
@export var landing_end: float = 929.0
@export var recovery_end: float = 990.0
@export var rise: float = 2.0
@export var landing_drop: float = 1.5
@export var lip_angle_deg: float = 14.0
@export var landing_grade: float = -0.02
## The dry ravine extends across this much land either side of the centre.
@export var cut_half_width: float = 40.0
@export var cut_depth: float = 12.0
@export var face_color: Color = Color(0.38, 0.37, 0.35)


func validation_error(road_length: float) -> String:
	for value: float in [takeoff_start, takeoff_end, landing_start, landing_end,
			recovery_end, rise, landing_drop, lip_angle_deg, landing_grade, cut_half_width, cut_depth]:
		if not is_finite(value):
			return "gap values must be finite"
	if takeoff_start < 0.0 or takeoff_start >= takeoff_end or takeoff_end >= landing_start \
			or landing_start >= landing_end or landing_end >= recovery_end or recovery_end > road_length:
		return "gap stations must be ordered and inside the curve"
	if rise <= 0.0 or landing_drop < 0.0 or cut_half_width <= 0.0 or cut_depth < 3.0:
		return "gap rise, width and depth must be positive; depth must clear a car"
	if lip_angle_deg <= 0.0 or lip_angle_deg >= 30.0 or landing_grade > 0.0 or landing_grade < -0.08:
		return "gap lip or landing slope is outside the supported range"
	return ""


func contains(distance: float) -> bool:
	return distance > takeoff_end and distance < landing_start


## Cutting uses one straight XZ slab. Reject bends anywhere inside the profile,
## not just at its endpoints, before creating any partial geometry.
func alignment_error(sampler: RoadSampler) -> String:
	var start := sampler.position(takeoff_start)
	var forward := sampler.forward(takeoff_end)
	var at := takeoff_start
	while at <= recovery_end:
		var offset := sampler.position(at) - start
		if sampler.forward(at).dot(forward) < 0.999 or offset.cross(forward).length() > 0.05:
			return "Road gaps require a straight approach and landing"
		at += 2.0
	if (sampler.position(recovery_end) - start).cross(forward).length() > 0.05:
		return "Road gaps require a straight recovery"
	return ""


func boundaries() -> PackedFloat32Array:
	return PackedFloat32Array([takeoff_start, takeoff_end, landing_start, landing_end, recovery_end])


func height_offset(distance: float) -> float:
	if distance <= takeoff_start or distance >= recovery_end:
		return 0.0
	if distance <= takeoff_end:
		var length := takeoff_end - takeoff_start
		var t := (distance - takeoff_start) / length
		return _hermite(0.0, rise, 0.0, tan(deg_to_rad(lip_angle_deg)) * length, t)
	var landing_height := rise - landing_drop
	if distance < landing_start:
		# Route hints may sample the absent span. This creates no mesh/collision.
		return lerpf(rise, landing_height, (distance - takeoff_end) / (landing_start - takeoff_end))
	if distance <= landing_end:
		return landing_height + landing_grade * (distance - landing_start)
	var end_height := landing_height + landing_grade * (landing_end - landing_start)
	var length := recovery_end - landing_end
	return _hermite(end_height, 0.0, landing_grade * length, 0.0, (distance - landing_end) / length)


func floor_height(sampler: RoadSampler, profile: RoadProfile) -> float:
	return minf(sampler.surface_point(takeoff_end, 0.0, profile).y,
			sampler.surface_point(landing_start, 0.0, profile).y) - cut_depth


static func _hermite(a: float, b: float, slope_a: float, slope_b: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * a + (t3 - 2.0 * t2 + t) * slope_a \
			+ (-2.0 * t3 + 3.0 * t2) * b + (t3 - t2) * slope_b
