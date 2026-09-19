extends GutTest

const TRAIL := preload("res://levels/rock_canyon/rock_canyon_trail.tres")
const TERRAIN := preload("res://levels/rock_canyon/rock_canyon_terrain.tres")
const SCATTER := preload("res://levels/rock_canyon/rock_canyon_scatter.tres")
const CURVE := preload("res://levels/rock_canyon/rock_canyon_curve.tres")


func _level() -> TrailLevel:
	var level := TrailLevel.new()
	level.trail = TRAIL
	level.terrain = TERRAIN
	level.scatter = SCATTER
	var path := Path3D.new()
	path.name = "Road"
	path.curve = CURVE
	level.add_child(path)
	add_child_autofree(level)
	return level


func test_bank_is_outward_varies_smoothly_and_stops_at_checkpoint_five() -> void:
	var sampler := RoadSampler.new(CURVE, true, TRAIL)
	var plain: TrailDef = TRAIL.duplicate()
	plain.bank_profile = []
	var before := RoadSampler.new(CURVE, true, plain)
	for d: float in range(0, 2170):
		assert_eq(sampler.position(d), before.position(d), "no centre-line edits")
		if d <= 1500.0 or d >= 1900.0:
			assert_eq(sampler.up(d), before.up(d), "all earlier sections and finish unchanged")
		elif d >= 1525.0 and d <= 1880.0:
			assert_lt(sampler.right(d).y, 0.0, "right edge downhill")
			assert_lt(absf(TRAIL.bank_degrees_at(d + 0.1) - TRAIL.bank_degrees_at(d)), 0.08)
	assert_eq(TRAIL.bank_degrees_at(1580.0), 12.0)
	assert_eq(TRAIL.bank_degrees_at(1630.0), 5.0)
	assert_eq(TRAIL.bank_degrees_at(1685.0), 14.0)


func test_dense_stones_cover_every_ten_metres_and_all_three_lateral_bands() -> void:
	var level := _level()
	var stones := level.talus_builder
	var bins := PackedInt32Array()
	bins.resize(40 * 3)
	assert_gt(stones.stones.size(), 4500)
	for i in stones.stones.size():
		var stone := stones.stones[i]
		var distance := level.sampler.closest_distance(stone.position)
		var lateral := level.sampler.lateral_offset(stone.position)
		assert_between(distance, 1501.4, 1898.6, "only checkpoint centre clearances are left empty")
		assert_lte(absf(lateral) + stones._footprints[i], level.sampler.road_half_width_at(distance) + 0.01)
		var row := clampi(int((distance - 1500.0) / 10.0), 0, 39)
		var band := clampi(int((lateral / level.sampler.road_half_width_at(distance) + 1.0) * 1.5), 0, 2)
		bins[row * 3 + band] += 1
		assert_true(stone.continuous_cd)
		assert_almost_eq(stone.physics_material_override.friction, 0.20, 0.00001)
	for bin in bins:
		assert_gte(bin, 12, "no bare strip or isolated short rock patch")
	await wait_physics_frames(4)
	assert_eq(stones.awake_count(), 0, "no build-time avalanche")
	assert_true(stones._active.is_empty(), "no polling of sleeping stones")
	gut.p("Shelf: %d movable stones, least populated 10 m/lateral band %d; build %.3f s (%s)" % [
		stones.stones.size(), Array(bins).min(), level.build_seconds, level.phase_summary()])


func test_banked_road_and_close_left_cut_have_matching_real_collision() -> void:
	var level := _level()
	await wait_physics_frames(2)
	var excluded: Array[RID] = []
	for stone in level.talus_builder.stones:
		excluded.append(stone.get_rid())
	for child in level.boulder_builder.get_children():
		if child is StaticBody3D:
			excluded.append(child.get_rid())
	var space := level.get_world_3d().direct_space_state
	for distance: float in [1525.1, 1580.1, 1685.1, 1790.1, 1880.1]:
		for lateral: float in [-1.8, 0.03, 1.8]:
			var point := level.sampler.surface_point(distance, lateral, level.profile)
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP)
			query.exclude = excluded
			var hit := space.intersect_ray(query)
			assert_false(hit.is_empty())
			if not hit.is_empty():
				assert_lt((hit.position as Vector3).distance_to(point), 0.01, "terrain does not bury the bank")
		var origin := level.sampler.surface_point(distance, 0.0, level.profile) + Vector3.UP * 1.2
		var outward := -level.sampler.right(distance)
		var query := PhysicsRayQueryParameters3D.create(origin, origin + outward * 4.0)
		query.exclude = excluded
		var face := space.intersect_ray(query)
		assert_false(face.is_empty(), "left hillside immediately beside the road")
		if not face.is_empty():
			assert_true(str(face.collider.name).begins_with("LeftCut"))
			assert_between(origin.distance_to(face.position), 2.3, 3.2)
	assert_eq(level.shelf_builder.wall_chunks, 10)
	assert_eq(level.shelf_builder.gravel_chunks, 10)


func test_dense_stones_keep_safe_diameters_and_banked_hulls_above_the_road() -> void:
	var level := _level()
	var builder := level.talus_builder
	for i in range(0, builder.stones.size(), 47):
		var stone := builder.stones[i]
		var hull: ConvexPolygonShape3D = stone.get_child(0).shape
		var diameter := 0.0
		var minimum_gap := INF
		for a in hull.points:
			for b in hull.points:
				diameter = maxf(diameter, a.distance_to(b))
			var vertex := stone.transform * a
			var distance := level.sampler.closest_distance(vertex)
			var lateral := level.sampler.lateral_offset(vertex)
			var floor := level.sampler.surface_point(distance, lateral, level.profile)
			minimum_gap = minf(minimum_gap, (vertex - floor).dot(level.sampler.up(distance)))
		assert_lt(diameter, 0.30, "safe span even when tipped upright")
		assert_between(minimum_gap, -0.002, 0.012, "neither embedded nor floating")
		assert_eq(builder.instance_transforms[i].origin, stone.position)
