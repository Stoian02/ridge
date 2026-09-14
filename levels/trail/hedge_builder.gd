class_name HedgeBuilder
extends Node3D
## Builds dense collidable hedges beside configured road sections. Visual bushes
## are batched per terrain chunk; overlapping box segments form the solid wall.

const DIRT := preload("res://surfaces/dirt.tres")

const BUSH_SPACING := 1.6
const WALL_SEGMENT_LENGTH := 8.0
const WALL_THICKNESS := 0.9
const WALL_HEIGHT := 1.4
## Leaves a narrow grass strip so a car using the full shoulder does not catch a
## hedge chord on bends; the one-metre-radius bushes still read from the road.
const OUTSIDE_OFFSET := 2.0
const SCREEN_OFFSET := 1.4
const VIEW_DISTANCE := 220.0

var bush_count: int = 0
var wall_segment_count: int = 0

var _bushes: Array[Transform3D] = []
var _collision: StaticBody3D
var _rng := RandomNumberGenerator.new()


func build(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	bush_count = 0
	wall_segment_count = 0
	_bushes.clear()
	if trail.hedges.is_empty():
		return
	_rng.seed = trail.seed * 7919 + 47
	_collision = StaticBody3D.new()
	_collision.name = "HedgeCollision"
	_collision.set_meta(SurfaceLookup.META_KEY, DIRT)
	add_child(_collision)

	for hedge: Vector3 in trail.hedges:
		if hedge.y <= 0.0 or is_zero_approx(hedge.z):
			continue
		var side := signf(hedge.z)
		for interval: Vector2 in _solid_intervals(hedge, trail):
			_append_road_section(field, sampler, trail, interval, side)
		_append_gap_screens(field, sampler, trail, hedge, side)
	for hedge_return: Vector3 in trail.hedge_returns:
		if hedge_return.y <= 0.0 or is_zero_approx(hedge_return.z):
			continue
		_append_return(field, sampler, trail, hedge_return.x, hedge_return.y, signf(hedge_return.z))

	bush_count = _bushes.size()
	_add_multimeshes(field, LowPolyMeshes.hedge_bush(trail.hedge_color, trail.seed + 101))


## Lateral position of a longitudinal hedge on `side`.
static func line_lateral(trail: TrailDef, side: float) -> float:
	return signf(side) * (trail.half_total_width() + OUTSIDE_OFFSET)


func _solid_intervals(hedge: Vector3, trail: TrailDef) -> Array[Vector2]:
	var intervals: Array[Vector2] = [Vector2(hedge.x, hedge.x + hedge.y)]
	var side := signf(hedge.z)
	for gap: Vector3 in trail.hedge_gaps:
		if gap.y <= 0.0 or signf(gap.z) != side:
			continue
		var gap_start := gap.x
		var gap_end := gap.x + gap.y
		var split: Array[Vector2] = []
		for interval: Vector2 in intervals:
			if gap_end <= interval.x or gap_start >= interval.y:
				split.append(interval)
				continue
			if gap_start > interval.x:
				split.append(Vector2(interval.x, minf(gap_start, interval.y)))
			if gap_end < interval.y:
				split.append(Vector2(maxf(gap_end, interval.x), interval.y))
		intervals = split
	return intervals


func _append_road_section(field: TerrainField, sampler: RoadSampler, trail: TrailDef,
		interval: Vector2, side: float) -> void:
	var start := clampf(interval.x, 0.0, sampler.length)
	var end := clampf(interval.y, 0.0, sampler.length)
	if end - start < 0.1:
		return
	var lateral := line_lateral(trail, side)
	var distance := start
	while distance <= end + 0.001:
		_append_bush(_road_ground_point(field, sampler, distance, lateral))
		distance += BUSH_SPACING
	var wall_start := start
	while wall_start < end - 0.001:
		var wall_end := minf(wall_start + WALL_SEGMENT_LENGTH, end)
		_add_wall_between(_road_ground_point(field, sampler, wall_start, lateral),
				_road_ground_point(field, sampler, wall_end, lateral))
		wall_start = wall_end


func _append_return(field: TerrainField, sampler: RoadSampler, trail: TrailDef,
		distance: float, length: float, side: float) -> void:
	var at := clampf(distance, 0.0, sampler.length)
	var start := _road_ground_point(field, sampler, at, line_lateral(trail, side))
	var across := sampler.right(at)
	var flat_across := Vector3(across.x, 0.0, across.z).normalized()
	var finish := start + flat_across * side * length
	finish.y = field.height_at(finish.x, finish.z)
	_append_world_bushes(field, start, finish)
	var segment_start := start
	var covered := 0.0
	while covered < length - 0.001:
		var next_covered := minf(covered + WALL_SEGMENT_LENGTH, length)
		var segment_end := start.lerp(finish, next_covered / length)
		segment_end.y = field.height_at(segment_end.x, segment_end.z)
		_add_wall_between(segment_start, segment_end)
		segment_start = segment_end
		covered = next_covered


func _append_gap_screens(field: TerrainField, sampler: RoadSampler, trail: TrailDef,
		hedge: Vector3, side: float) -> void:
	var hedge_start := hedge.x
	var hedge_end := hedge.x + hedge.y
	var lateral := line_lateral(trail, side) + side * SCREEN_OFFSET
	for gap: Vector3 in trail.hedge_gaps:
		if gap.y <= 1.0 or signf(gap.z) != side or gap.x >= hedge_end or gap.x + gap.y <= hedge_start:
			continue
		var inset := minf(0.8, gap.y * 0.2)
		_append_bush(_road_ground_point(field, sampler, gap.x + inset, lateral))
		_append_bush(_road_ground_point(field, sampler, gap.x + gap.y - inset, lateral))


func _append_world_bushes(field: TerrainField, start: Vector3, finish: Vector3) -> void:
	var length := Vector2(finish.x - start.x, finish.z - start.z).length()
	var covered := 0.0
	while covered <= length + 0.001:
		var point := start.lerp(finish, covered / length)
		point.y = field.height_at(point.x, point.z)
		_append_bush(point)
		covered += BUSH_SPACING


func _append_bush(point: Vector3) -> void:
	var yaw := _rng.randf() * TAU
	var scale := _rng.randf_range(0.9, 1.15)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, _rng.randf_range(0.9, 1.15), scale))
	_bushes.append(Transform3D(basis, point))


func _road_ground_point(field: TerrainField, sampler: RoadSampler, distance: float, lateral: float) -> Vector3:
	var point := sampler.position(distance) + sampler.right(distance) * lateral
	point.y = field.height_at(point.x, point.z)
	return point


func _add_wall_between(start: Vector3, finish: Vector3) -> void:
	var flat := Vector3(finish.x - start.x, 0.0, finish.z - start.z)
	if flat.length_squared() < 0.01:
		return
	var shape := BoxShape3D.new()
	shape.size = Vector3(WALL_THICKNESS, WALL_HEIGHT + absf(finish.y - start.y), flat.length() + 0.35)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "Wall_%d" % wall_segment_count
	collision_shape.shape = shape
	var centre := (start + finish) * 0.5
	centre.y += WALL_HEIGHT * 0.5
	collision_shape.transform = Transform3D(Basis.looking_at(flat.normalized(), Vector3.UP), centre)
	_collision.add_child(collision_shape)
	wall_segment_count += 1


func _add_multimeshes(field: TerrainField, mesh: ArrayMesh) -> void:
	var chunk_metres := field.cells_per_chunk * field.spacing
	var buckets := {}
	for transform: Transform3D in _bushes:
		var key := Vector2i(floori((transform.origin.x - field.origin.x) / chunk_metres),
				floori((transform.origin.z - field.origin.y) / chunk_metres))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(transform)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	for key: Vector2i in buckets:
		var bucket: Array = buckets[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = bucket.size()
		for i in bucket.size():
			multimesh.set_instance_transform(i, bucket[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.visibility_range_end = VIEW_DISTANCE
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
