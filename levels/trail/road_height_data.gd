class_name RoadHeightData
extends RefCounted
## Exact per-row profile values. No shared Resource calls in per-station maths.
## Float64 scalars retain the reference profile's accumulation precision/order.


static func snapshot(profile: RoadProfile, distance: float) -> Dictionary:
	var potholes: Array[Vector4] = []
	var i := profile._pothole_distances.bsearch(distance - profile._max_pothole_radius)
	while i < profile.potholes.size() and profile.potholes[i].x <= distance + profile._max_pothole_radius:
		potholes.append(profile.potholes[i])
		i += 1
	var steps: Array[PackedFloat64Array] = []
	for step: RockStepDef in profile.def.rock_steps:
		if distance <= step.distance:
			continue
		var lip := clampf((distance - step.distance) / maxf(step.face_length, 0.001), 0.0, 1.0)
		steps.append(PackedFloat64Array([step.lateral_from, step.lateral_to,
			step.height * (RockStepDef.LEDGE_SHARE + (1.0 - RockStepDef.LEDGE_SHARE) * lip), step.ramp_offset(distance)]))
	var channels: Array[PackedFloat64Array] = []
	for channel: CrossRutDef in profile.def.cross_ruts:
		channels.append(channel.snapshot())
	var stretch := profile.stretch_at(distance)
	var depth := 0.0
	var half_width := 1.0
	var centres := PackedFloat64Array()
	var deepest := false
	if stretch != null and stretch.rut_depth > 0.0:
		depth = stretch.rut_depth * stretch.weight(distance)
		half_width = stretch.rut_width * 0.5
		centres = stretch.rut_centres(distance)
		deepest = not stretch.extra_rut_paths.is_empty()
	return {"distance": distance, "base": profile.longitudinal_height(distance),
		"potholes": potholes, "patches": profile.patches, "steps": steps, "channels": channels,
		"depth": depth, "half_width": half_width, "centres": centres, "deepest": deepest}


static func height(input: Dictionary, lateral: float) -> float:
	var distance: float = input["distance"]
	var potholes: Array[Vector4] = input["potholes"]
	var patches: Array[Rect2] = input["patches"]
	var channels: Array[PackedFloat64Array] = input["channels"]
	var steps: Array[PackedFloat64Array] = input["steps"]
	var centres: PackedFloat64Array = input["centres"]
	var depth: float = input["depth"]
	var half_width: float = input["half_width"]
	var deepest: bool = input["deepest"]
	var base: float = input["base"]
	var pothole_height := 0.0
	for hole: Vector4 in potholes:
		var radius := Vector2(distance - hole.x, lateral - hole.y).length()
		if radius < hole.z:
			var t := radius / hole.z
			pothole_height += -hole.w * (1.0 - t * t)
	var cross_height := 0.0
	for channel: PackedFloat64Array in channels:
		var t := absf(distance - channel[0] - lateral * channel[3]) / maxf(channel[4] * 0.5, 0.001)
		if t < 1.0 and lateral > channel[1] and lateral < channel[2]:
			var fade := minf(smoothstep(channel[1], channel[1] + channel[6], lateral),
				1.0 - smoothstep(channel[2] - channel[6], channel[2], lateral))
			cross_height += -channel[5] * (0.5 + 0.5 * cos(PI * t)) * fade
	var rough := pothole_height + cross_height
	for patch: Rect2 in patches:
		if patch.has_point(Vector2(distance, lateral)):
			rough += RoadProfile.PATCH_RAISE
			break
	var rut_height := 0.0
	for centre: float in centres:
		var t := absf(lateral - centre) / half_width
		if t < 1.0:
			var depression := -depth * (0.5 + 0.5 * cos(PI * t))
			rut_height = minf(rut_height, depression) if deepest else rut_height + depression
	var step_height := 0.0
	for step: PackedFloat64Array in steps:
		step_height += step[2] if lateral >= step[0] and lateral <= step[1] else step[3]
	return base + rough + rut_height + step_height
