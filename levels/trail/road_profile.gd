class_name RoadProfile
extends RefCounted
## Surface height offsets along a trail: gentle undulation everywhere, potholes
## and patched tarmac in rough ranges, and jump crests. Built once from a
## TrailDef. All randomness comes from its seed, so the same settings always
## give the same road.

## Patched tarmac is raised this much above the surrounding asphalt (m).
const PATCH_RAISE := 0.012
## Pothole clusters spread over this distance either side of their centre (m).
const CLUSTER_SPREAD := 8.0
## Detailed cross-sections extend this far either side of a cluster's centre (m).
const CLUSTER_DETAIL := 10.0

var def: TrailDef
var road_length: float
## Potholes as Vector4(distance, lateral, radius, depth), sorted by distance.
var potholes: Array[Vector4] = []
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

	var ranges: Array[Vector2] = []
	for section in def.rough_sections:
		var start := section.x
		var end := section.x + section.y
		for i in roundi(section.y / 100.0 * section.z):
			_add_random_pothole(rng, start + def.rough_margin, end - def.rough_margin)
		for i in int(section.y / 12.0):
			_add_random_patch(rng, start + def.rough_margin, end - def.rough_margin)
		ranges.append(Vector2(start, end))
	for cluster in def.pothole_clusters:
		for i in int(cluster.y):
			_add_random_pothole(rng, cluster.x - CLUSTER_SPREAD, cluster.x + CLUSTER_SPREAD)
		ranges.append(Vector2(cluster.x - CLUSTER_DETAIL, cluster.x + CLUSTER_DETAIL))

	potholes.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.x < b.x)
	for pothole in potholes:
		_pothole_distances.append(pothole.x)
		_max_pothole_radius = maxf(_max_pothole_radius, pothole.z)
	detail_ranges = _merged(ranges)


## Total surface offset at a point of the road (m).
func height(distance: float, lateral: float) -> float:
	return undulation(distance) + jump_height(distance) + rough_height(distance, lateral)


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
	var total := pothole_height(distance, lateral)
	if is_patch(distance, lateral):
		total += PATCH_RAISE
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
