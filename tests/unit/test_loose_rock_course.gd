extends GutTest


func _course() -> LooseRockCourse:
	var course := LooseRockCourse.new()
	course.position = Vector3(210.0, 0.0, 10.0)
	add_child_autofree(course)
	return course


func test_flat_then_varying_outward_bank_with_level_entries() -> void:
	assert_eq(LooseRockCourse.SIZE.x, 4.5)
	for station: Vector2 in [Vector2(15.0, 0.0), Vector2(48.0, 12.0), Vector2(64.0, 5.0), Vector2(74.0, 14.0), Vector2(86.0, 0.0)]:
		assert_almost_eq(RoughPatch.loose_rock_angle_deg(station.x), station.y, 0.001)
		var rise := LooseRockCourse.floor_height(-2.25, -station.x) - LooseRockCourse.floor_height(2.25, -station.x)
		assert_almost_eq(rise, 4.5 * tan(deg_to_rad(station.y)), 0.001)
	assert_eq(LooseRockCourse.floor_height(0.0, 0.0), 0.0)
	assert_eq(LooseRockCourse.floor_height(0.0, -90.0), 0.0)


func test_120_sleeping_stones_match_collision_and_have_no_initial_penetration() -> void:
	var course := _course()
	var builder := course.talus
	assert_eq(builder.stones.size(), 120)
	for i in builder.stones.size():
		var stone := builder.stones[i]
		assert_true(stone.continuous_cd, "small fragments use swept collision")
		var hull: ConvexPolygonShape3D = stone.get_child(0).shape
		var diameter := 0.0
		for a in hull.points:
			for b in hull.points:
				diameter = maxf(diameter, a.distance_to(b))
		assert_lt(diameter, 0.30, "even an upright fragment stays below the 4x4's nominal chassis clearance")
		var lowest_clearance := INF
		for point in hull.points:
			var vertex := stone.transform * point
			var clearance := vertex.y - LooseRockCourse.floor_height(vertex.x, vertex.z)
			lowest_clearance = minf(lowest_clearance, clearance)
		assert_almost_eq(lowest_clearance, TalusBuilder.REST_GAP, 0.001, "no buried hull on a bank")
		assert_almost_eq(builder.instance_transforms[i].origin.distance_to(stone.position), 0.0, 0.001)
		var instance: MultiMeshInstance3D = builder.get_node("Talus%d" % builder._fields[i])
		var vertices := instance.multimesh.mesh.get_faces()
		for v in vertices.size():
			assert_lt((builder.instance_transforms[i] * vertices[v]).distance_to(stone.transform * hull.points[v]), 0.001)
		for j in i:
			var other := builder.stones[j]
			var horizontal := Vector2(stone.position.x - other.position.x, stone.position.z - other.position.z)
			assert_gte(horizontal.length(), builder._footprints[i] + builder._footprints[j] + 0.059)
	await wait_physics_frames(4)
	assert_eq(builder.awake_count(), 0)


func test_visual_follows_local_coordinates_and_reset_restores_pose_and_sleep() -> void:
	var course := _course()
	var builder := course.talus
	var before := builder.instance_transforms.duplicate()
	var stone := builder.stones[0]
	stone.apply_central_impulse(Vector3(0.0, 0.0, -stone.mass * 2.0))
	await wait_physics_frames(30)
	assert_gt(stone.position.distance_to(before[0].origin), 0.1)
	builder._physics_process(0.0)
	assert_lt(builder.instance_transforms[0].origin.distance_to(stone.position), 0.001)
	assert_lt((course.global_transform * builder.instance_transforms[0].origin).distance_to(stone.global_position), 0.001)
	builder.reset_stones()
	await wait_physics_frames(4)
	assert_eq(builder.awake_count(), 0)
	for i in builder.stones.size():
		assert_true(builder.instance_transforms[i].is_equal_approx(before[i]))
		assert_eq(builder.stones[i].linear_velocity, Vector3.ZERO)
		assert_eq(builder.stones[i].angular_velocity, Vector3.ZERO)


func test_rock_canyon_still_has_no_dynamic_stones() -> void:
	var trail: TrailDef = load("res://levels/rock_canyon/rock_canyon_trail.tres")
	assert_true(trail.talus.is_empty(), "owner must test the prototype before shelf integration")


func test_banked_floor_collision_matches_the_visible_height_profile() -> void:
	var course := _course()
	await wait_physics_frames(2)
	var excluded: Array[RID] = []
	for stone in course.talus.stones:
		excluded.append(stone.get_rid())
	for along: float in [15.0, 48.0, 64.0, 74.0]:
		for x: float in [-1.0, 0.0, 1.0]:
			var expected := course.to_global(Vector3(x, LooseRockCourse.floor_height(x, -along), -along))
			var ray := PhysicsRayQueryParameters3D.create(expected + Vector3.UP * 3.0, expected - Vector3.UP)
			ray.exclude = excluded
			var hit := course.get_world_3d().direct_space_state.intersect_ray(ray)
			assert_false(hit.is_empty())
			if not hit.is_empty():
				assert_lt((hit.position as Vector3).distance_to(expected), 0.002)
