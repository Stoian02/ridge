class_name RoadProfile
extends RefCounted
## Surface height offsets along a trail: gentle undulation everywhere, potholes
## (and patched tarmac on asphalt) in rough ranges, jump crests, wheel ruts in
## surface stretches, permanent rock-step rises and eased river crossings. Built once
## from a TrailDef. All randomness comes from its seed, so the same settings
## always give the same road.

## Patched tarmac is raised this much above the surrounding asphalt (m).
const PATCH_RAISE := 0.012
## Pothole clusters spread over this distance either side of their centre (m).
const CLUSTER_SPREAD := 8.0
## Detailed cross-sections extend this far either side of a cluster's centre (m).
const CLUSTER_DETAIL := 10.0
## The row just past a rock step's face sits this far along from it (m).
const FACE_ROW_GAP := 0.02

var def: TrailDef
var road_length: float
## Potholes as Vector4(distance, lateral, radius, depth), sorted by distance.
var potholes: Array[Vector4] = []
## The locally authored holes also needing clearance in the underlying terrain.
var damage_potholes: Array[Vector4] = []
## Patches as Rect2: position = (start distance, lateral from), size = (length, width).
var patches: Array[Rect2] = []
## Ranges needing detailed cross-sections, as Vector2(start, end), sorted and merged.
var detail_ranges: Array[Vector2] = []

var _pothole_distances := PackedFloat32Array()
var _max_pothole_radius := 0.0
var _phases := Vector2.ZERO


func _init(trail_def: TrailDef, length: float) -> void:
	def = trail_def
	road_length = length
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	_phases = Vector2(rng.randf() * TAU, rng.randf() * TAU)

	var patched := def.base_surface == null or def.base_surface.id == &"asphalt"
	var ranges: Array[Vector2] = []
	for section in def.rough_sections:
		var start := section.x
		var end := section.x + section.y
		for i in roundi(section.y / 100.0 * section.z):
			_add_random_pothole(rng, start + def.rough_margin, end - def.rough_margin)
		if patched:
			for i in int(section.y / 12.0):
				_add_random_patch(rng, start + def.rough_margin, end - def.rough_margin)
		ranges.append(Vector2(start, end))
	for cluster in def.pothole_clusters:
		for i in int(cluster.y):
			_add_random_pothole(rng, cluster.x - CLUSTER_SPREAD, cluster.x + CLUSTER_SPREAD)
		ranges.append(Vector2(cluster.x - CLUSTER_DETAIL, cluster.x + CLUSTER_DETAIL))
	for section: RoadDamageDef in def.damage_sections:
		var holes := section.generate(def)
		damage_potholes.append_array(holes)
		potholes.append_array(holes)
		# Keep fine geometry around each hole, not the intact gaps in early
		# asphalt. A half-metre rim lets the coarse row spacing enter safely.
		for hole: Vector4 in holes:
			ranges.append(Vector2(hole.x - hole.z - 0.5, hole.x + hole.z + 0.5))
	for rut: CrossRutDef in def.cross_ruts:
		var span := rut.bounds()
		ranges.append(Vector2(span.x - 0.5, span.y + 0.5))
	for stretch in def.surface_stretches:
		for end: float in [stretch.start, stretch.end()]:
			ranges.append(Vector2(end - stretch.blend_length, end + stretch.blend_length))
	for bridge: BridgeDef in def.bridges:
		ranges.append(Vector2(bridge.start, bridge.end() + bridge.ramp_length))
	for roller: Vector3 in def.rollers:
		ranges.append(Vector2(roller.x - roller.z * 0.5, roller.x + roller.z * 0.5))
	for step: RockStepDef in def.rock_steps:
		ranges.append(Vector2(step.distance - 1.0, step.distance + step.ramp_length + 1.0))
	for ford: FordDef in def.fords:
		ranges.append(Vector2(ford.distance - ford.half_width() - ford.bank_run,
				ford.distance + ford.half_width() + ford.bank_run))

	potholes.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.x < b.x)
	for pothole in potholes:
		_pothole_distances.append(pothole.x)
		_max_pothole_radius = maxf(_max_pothole_radius, pothole.z)
	detail_ranges = _merged(ranges)


## Total surface offset at a point of the road (m).
func height(distance: float, lateral: float) -> float:
	return longitudinal_height(distance) + rough_height(distance, lateral) \
			+ rut_height(distance, lateral) + step_height(distance, lateral)


func longitudinal_height(distance: float) -> float:
	return undulation(distance) + jump_height(distance) + bridge_height(distance) \
			+ roller_height(distance) + ford_height(distance)


func ford_height(distance: float) -> float:
	var total := 0.0
	for ford: FordDef in def.fords:
		total += ford.height_offset(distance)
	return total


func roller_height(distance: float) -> float:
	var total := 0.0
	for roller: Vector3 in def.rollers:
		total += RoughShapes.bump(distance - roller.x, roller.z, roller.y)
	return total


func roughness_at(distance: float) -> float:
	var stretch := stretch_at(distance)
	return stretch.roughness if stretch != null else def.road_roughness


## Gravel is a material on the colliding road itself, never a second ribbon.
func gravel_at(distance: float) -> bool:
	for field: TalusDef in def.talus:
		if field.gravel_bed and distance >= field.start and distance < field.end():
			return true
	return false


func bridge_height(distance: float) -> float:
	var total := 0.0
	for bridge: BridgeDef in def.bridges:
		total += bridge.height_offset(distance)
	return total


func on_bridge(distance: float) -> bool:
	for bridge: BridgeDef in def.bridges:
		if bridge.contains(distance):
			return true
	return false


func undulation(distance: float) -> float:
	var waves := def.undulation_wavelengths
	return def.undulation_amplitude * 0.5 * (sin(TAU * distance / waves.x + _phases.x) \
			+ sin(TAU * distance / waves.y + _phases.y))


## A jump rises smoothly over the first 70% of its length, then drops away.
func jump_height(distance: float) -> float:
	var total := 0.0
	for jump in def.jumps:
		var t := (distance - (jump.x - jump.z * 0.5)) / jump.z
		if t <= 0.0 or t >= 1.0:
			continue
		if t < 0.7:
			total += jump.y * smoothstep(0.0, 0.7, t)
		else:
			total += jump.y * (1.0 - smoothstep(0.7, 1.0, t))
	return total


func rough_height(distance: float, lateral: float) -> float:
	var total := pothole_height(distance, lateral) + cross_rut_height(distance, lateral)
	if is_patch(distance, lateral):
		total += PATCH_RAISE
	return total


func cross_rut_height(distance: float, lateral: float) -> float:
	var total := 0.0
	for rut: CrossRutDef in def.cross_ruts:
		total += rut.height_at(distance, lateral)
	return total


func pothole_height(distance: float, lateral: float) -> float:
	var total := 0.0
	var i := _pothole_distances.bsearch(distance - _max_pothole_radius)
	while i < potholes.size() and potholes[i].x <= distance + _max_pothole_radius:
		var pothole := potholes[i]
		var from_centre := Vector2(distance - pothole.x, lateral - pothole.y).length()
		total += RoughShapes.pothole(from_centre, pothole.z, pothole.w)
		i += 1
	return total


func is_patch(distance: float, lateral: float) -> bool:
	for patch in patches:
		if patch.has_point(Vector2(distance, lateral)):
			return true
	return false


func in_detail_range(distance: float) -> bool:
	for range in detail_ranges:
		if distance >= range.x and distance <= range.y:
			return true
	return false


func row_step(distance: float) -> float:
	var step: float = def.detail_step if in_detail_range(distance) else def.sample_step
	var stretch := stretch_at(distance)
	if stretch != null and not stretch.extra_rut_paths.is_empty():
		step = minf(step, 0.5)
	return step


## The surface stretch covering `distance`, or null where the road has its base surface.
func stretch_at(distance: float) -> SurfaceStretch:
	for stretch in def.surface_stretches:
		if stretch.contains(distance):
			return stretch
	return null


## The road's surface at `distance`: a stretch's surface, or the trail's base surface.
func surface_at(distance: float) -> SurfaceDef:
	if on_bridge(distance):
		return preload("res://surfaces/logs.tres")
	var stretch := stretch_at(distance)
	return stretch.surface_at(distance) if stretch != null else def.base_surface


## The rise from every rock step at a point: vertical inside a face's span, a ramp beside it.
func step_height(distance: float, lateral: float) -> float:
	var total := 0.0
	for step: RockStepDef in def.rock_steps:
		total += step.height_at(distance, lateral)
	return total


## Distances the road must have a cross-section row at exactly: every surface
## boundary, and both sides of each rock step's face, so the face is a sharp
## edge in the road mesh rather than a slope.
func exact_rows() -> PackedFloat32Array:
	var rows := surface_boundaries()
	for field: TalusDef in def.talus:
		if not field.gravel_bed:
			continue
		for at: float in [field.start, field.end()]:
			if at > 0.0 and at < road_length and not rows.has(at):
				rows.append(at)
	for step: RockStepDef in def.rock_steps:
		for at: float in [step.distance, step.distance + FACE_ROW_GAP]:
			if at > 0.0 and at < road_length and not rows.has(at):
				rows.append(at)
	rows.sort()
	return rows


## Every stretch start and end on the road, sorted.
func surface_boundaries() -> PackedFloat32Array:
	var boundaries := PackedFloat32Array()
	for stretch in def.surface_stretches:
		for boundary: float in stretch.surface_boundaries():
			if boundary > 0.0 and boundary < road_length and not boundaries.has(boundary):
				boundaries.append(boundary)
	for bridge: BridgeDef in def.bridges:
		for boundary: float in [bridge.start, bridge.end(), bridge.end() + bridge.ramp_length]:
			if boundary > 0.0 and boundary < road_length and not boundaries.has(boundary):
				boundaries.append(boundary)
	boundaries.sort()
	return boundaries


## The two wheel ruts of a stretch, fading in and out with the stretch.
func rut_height(distance: float, lateral: float) -> float:
	var stretch := stretch_at(distance)
	if stretch == null or stretch.rut_depth <= 0.0:
		return 0.0
	var depth := stretch.rut_depth * stretch.weight(distance)
	var half_spacing := stretch.rut_spacing * 0.5
	var half_width := stretch.rut_width * 0.5
	if not stretch.extra_rut_paths.is_empty():
		var deepest := 0.0
		for centre: float in stretch.rut_centres(distance):
			deepest = minf(deepest, RoughShapes.rut(lateral - centre, half_width, depth))
		return deepest
	return RoughShapes.rut(lateral + half_spacing, half_width, depth) \
			+ RoughShapes.rut(lateral - half_spacing, half_width, depth)


func _add_random_pothole(rng: RandomNumberGenerator, from: float, to: float) -> void:
	var radius := rng.randf_range(def.pothole_radius_range.x, def.pothole_radius_range.y)
	var depth := rng.randf_range(def.pothole_depth_range.x, def.pothole_depth_range.y)
	var lateral_limit := def.road_width * 0.5 - radius
	potholes.append(Vector4(rng.randf_range(from, to), rng.randf_range(-lateral_limit, lateral_limit), radius, depth))


func _add_random_patch(rng: RandomNumberGenerator, from: float, to: float) -> void:
	var length := rng.randf_range(2.0, 5.0)
	var start := rng.randf_range(from, maxf(from, to - length))
	var lateral_from := -def.road_width * 0.5 if rng.randf() < 0.5 else 0.0
	patches.append(Rect2(start, lateral_from, length, def.road_width * 0.5))


static func _merged(ranges: Array[Vector2]) -> Array[Vector2]:
	var sorted := ranges.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var result: Array[Vector2] = []
	for range in sorted:
		if not result.is_empty() and range.x <= result[-1].y:
			result[-1] = Vector2(result[-1].x, maxf(result[-1].y, range.y))
		else:
			result.append(range)
	return result
