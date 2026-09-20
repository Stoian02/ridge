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


func test_cached_support_rows_match_the_exact_road_sampler() -> void:
	var sampler := RoadSampler.new(CURVE, true, TRAIL)
	var profile := RoadProfile.new(TRAIL, sampler.length)
	var builder := ShelfBuilder.new()
	add_child_autofree(builder)
	var laterals: Array[float] = [-4.0, -1.5, 0.0, 1.5, 4.0]
	for distance: float in [1500, 1505, 1512, 1580.25, 1631, 1685, 1888, 1899.75]:
		var points := builder._support_row(sampler, profile, distance, laterals)
		var scale := RoadBuilder.width_scales(TRAIL, distance).x
		for i in laterals.size():
			assert_eq(points[i], sampler.surface_point(distance, laterals[i] * scale, profile))


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
	for distance: float in [1505.0, 1580.0, 1685.0, 1790.0, 1895.0]:
		var ring := level.shelf_builder._ring(level.sampler, level.profile, level.field,
			TRAIL.shelf_walls[0], distance)
		assert_gt(ring.size(), 12, "broken strata and a stepped return into the mountain")
		var outward := -level.sampler.right(distance)
		outward.y = 0.0
		outward = outward.normalized()
		var edge := level.sampler.surface_point(distance, -level.sampler.half_width_at(distance), level.profile)
		for point: Vector3 in ring:
			assert_gte((point - edge).dot(outward), 0.18, "cliff relief stays outside road and widening shoulders")


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


func test_visible_gravel_has_support_right_up_to_its_edges() -> void:
	var level := _level()
	await wait_physics_frames(2)
	var excluded: Array[RID] = []
	for stone in level.talus_builder.stones:
		excluded.append(stone.get_rid())
	for child in level.boulder_builder.get_children():
		if child is StaticBody3D:
			excluded.append(child.get_rid())
	var space := level.get_world_3d().direct_space_state
	var largest_gap := 0.0
	var worst := Vector3.ZERO
	var terrain_hits := 0
	var probes := 0
	for child in level.shelf_builder.get_children():
		assert_false(str(child.name).begins_with("GravelBed"), "no separate visual gravel sheet")
	for child in level.road_builder.get_children():
		if not child is MeshInstance3D or not child.material_override is ShaderMaterial:
			continue
		if child.material_override.shader != RoadBuilder.GRAVEL:
			continue
		var faces: PackedVector3Array = child.mesh.get_faces()
		var stride := maxi(1, int(faces.size() / 600.0)) * 3
		for i in range(0, faces.size(), stride):
			# A collapsing shoulder can emit a zero-area, invisible triangle.
			if (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).length_squared() < 0.00000001:
				continue
			for weights: Vector3 in [Vector3.ONE / 3.0, Vector3(0.002, 0.499, 0.499)]:
				var visible := faces[i] * weights.x + faces[i + 1] * weights.y + faces[i + 2] * weights.z
				var query := PhysicsRayQueryParameters3D.create(visible + Vector3.UP * 0.25, visible - Vector3.UP * 3.0)
				query.exclude = excluded
				var hit := space.intersect_ray(query)
				assert_false(hit.is_empty(), "visible road must have collision")
				if hit.is_empty():
					continue
				probes += 1
				var gap: float = absf(visible.y - hit.position.y)
				if gap > 0.01:
					gut.p("Mismatch at %.3f m, lateral %.3f, signed gap %.4f, area %.7f, collider %s: %s" % [
						level.sampler.closest_distance(visible), level.sampler.lateral_offset(visible), visible.y - hit.position.y,
						(faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).length() * 0.5,
						hit.collider.get_path(), [faces[i], faces[i + 1], faces[i + 2]]])
				if gap > largest_gap:
					largest_gap = gap
					worst = visible
				if SurfaceLookup.surface_of(hit.collider).id == &"dirt":
					terrain_hits += 1
	gut.p("Visible shelf support: %d probes, worst gap %.4f m at %s, terrain hits %d" % [
		probes, largest_gap, worst, terrain_hits])
	assert_gt(probes, 100)
	assert_lt(largest_gap, 0.01, "visible gravel and physical road agree within a centimetre")
	assert_eq(terrain_hits, 0, "no visible drivable gravel supported only by the mountain below")
