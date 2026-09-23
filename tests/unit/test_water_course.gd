extends GutTest


func _course() -> WaterCourse:
	var course := WaterCourse.new()
	add_child_autofree(course)
	return course


func test_approved_profile_stations_plateaus_and_dry_approaches() -> void:
	for station: Vector2 in [Vector2(0.0, 0.02), Vector2(24.0, 2.92), Vector2(28.0, 2.82),
			Vector2(84.0, 0.02), Vector2(108.0, 0.02), Vector2(164.0, 2.82),
			Vector2(168.0, 2.92), Vector2(192.0, 0.02)]:
		assert_almost_eq(WaterCourse.pool_center_height(station.x), station.y, 0.000001)
		assert_almost_eq(WaterCourse.pool_floor_height(0.0, station.x), station.y, 0.000001)
	for along: float in [0.0, 24.0, 50.0, 84.0, 96.0, 108.0, 144.0, 168.0, 192.0]:
		assert_almost_eq(WaterCourse.pool_floor_height(-6.0, along), WaterCourse.pool_floor_height(6.0, along), 0.000001)
		assert_almost_eq(WaterCourse.pool_floor_height(-16.0, along), 2.92, 0.000001)
		assert_almost_eq(WaterCourse.pool_floor_height(16.0, along), 2.92, 0.000001)
	assert_almost_eq(WaterCourse.shallow_center_height(0.0), 0.02, 0.000001)
	assert_almost_eq(WaterCourse.shallow_center_height(100.0), 0.02, 0.000001)
	for index: int in WaterCourse.BAY_STARTS.size():
		var start := WaterCourse.BAY_STARTS[index]
		assert_almost_eq(WaterCourse.shallow_center_height(start), 0.37, 0.000001)
		assert_almost_eq(WaterCourse.shallow_center_height(start + 6.0), 0.37 - WaterCourse.SHALLOW_DEPTHS[index], 0.000001)
		assert_almost_eq(WaterCourse.shallow_center_height(start + 12.0), 0.37, 0.000001)


func test_three_separate_footprints_leave_old_courses_skidpad_and_spawn_alone() -> void:
	var course := _course()
	var boxes: Array[AABB] = []
	for name: String in ["ShallowBed", "CalmBed", "CurrentBed"]:
		var body: StaticBody3D = course.get_node(name)
		var mesh: MeshInstance3D = body.get_node("Ground")
		var box := mesh.mesh.get_aabb()
		box.position += body.position
		boxes.append(box)
		assert_gte(box.position.z, 30.0, "old courses end at +Z 10; new ground starts at +Z 30")
		assert_gte(box.position.x, 56.0, "skidpad's right edge is X=15, spawn X=0")
		assert_almost_eq(box.position.y, 0.0, 0.000001, "closed outside/bottom reaches the slab")
	for index: int in boxes.size():
		for other: int in range(index + 1, boxes.size()):
			assert_false(boxes[index].intersects(boxes[other]))
	assert_almost_eq(boxes[0].size.x, 8.0, 0.000001)
	assert_almost_eq(boxes[0].size.z, 100.0, 0.000001)
	assert_almost_eq(boxes[1].size.x, 32.0, 0.000001)
	assert_almost_eq(boxes[1].size.z, 192.0, 0.000001)


func test_identical_calm_current_meshes_matching_collision_and_asphalt_beds() -> void:
	var course := _course()
	var calm: MeshInstance3D = course.get_node("CalmBed/Ground")
	var current: MeshInstance3D = course.get_node("CurrentBed/Ground")
	assert_same(calm.mesh, current.mesh, "one immutable geometry resource, not independently rounded shapes")
	var calm_water: MeshInstance3D = course.get_node("CalmWater")
	var current_water: MeshInstance3D = course.get_node("CurrentWater")
	assert_same(calm_water.mesh, current_water.mesh)
	for name: String in ["ShallowBed", "CalmBed", "CurrentBed"]:
		var body: StaticBody3D = course.get_node(name)
		var mesh: MeshInstance3D = body.get_node("Ground")
		var collision: CollisionShape3D = body.get_node("Collision")
		var shape: ConcavePolygonShape3D = collision.shape
		assert_same(body.get_meta(SurfaceLookup.META_KEY), WaterCourse.ASPHALT)
		var collision_faces := shape.get_faces()
		# These meshes are unindexed. The actual vertex buffer is authoritative:
		# Mesh.get_faces() builds a TriangleMesh and welds near-identical vertices,
		# which introduces tiny reconstruction differences on these long ramps.
		var drawn_faces: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var reconstructed_faces := mesh.mesh.get_faces()
		assert_eq(collision_faces.size(), drawn_faces.size())
		var maximum_gap := 0.0
		var reconstruction_gap := 0.0
		for index: int in mini(collision_faces.size(), drawn_faces.size()):
			maximum_gap = maxf(maximum_gap, collision_faces[index].distance_to(drawn_faces[index]))
			reconstruction_gap = maxf(reconstruction_gap, drawn_faces[index].distance_to(reconstructed_faces[index]))
		print("water course %s collision/vertex-buffer gap %.9f m; TriangleMesh reconstruction gap %.9f m" % [name, maximum_gap, reconstruction_gap])
		assert_eq(maximum_gap, 0.0, "actual drawn vertex buffer and collision faces match exactly")
	assert_eq(course.find_children("*", "StaticBody3D", true, false).size(), 3)
	assert_eq(course.find_children("*", "RigidBody3D", true, false).size(), 0)
	for name: String in ["ShallowWater", "CalmWater", "CurrentWater"]:
		assert_eq(course.get_node(name).get_child_count(), 0, "water has no solid collision")


func test_queries_match_depth_current_and_dry_shallow_gaps() -> void:
	var course := _course()
	var sample := WaterSample.new()
	assert_eq(course.water_world.bodies.size(), 6)
	for index: int in WaterCourse.BAY_STARTS.size():
		course.water_world.sample(Vector3(60.0, 0.37, 30.0 + WaterCourse.BAY_STARTS[index] + 6.0), sample)
		assert_true(sample.valid)
		assert_almost_eq(sample.surface_y - sample.bed_y, WaterCourse.SHALLOW_DEPTHS[index], 0.00001)
		assert_eq(sample.current, Vector3.ZERO)
	for station: float in [10.0, 18.0, 36.0, 56.0, 76.0, 94.0]:
		course.water_world.sample(Vector3(60.0, 0.37, 30.0 + station), sample)
		assert_false(sample.valid, "independent bays never connect through their dry decks")
	for center: float in [105.0, 155.0]:
		course.water_world.sample(Vector3(center, 2.0, 30.0 + 96.0), sample)
		assert_true(sample.valid)
		assert_almost_eq(sample.surface_y - sample.bed_y, 2.8, 0.00001)
		assert_eq(sample.current, Vector3.ZERO if center == 105.0 else Vector3(0.75, 0.0, 0.0))
		course.water_world.sample(Vector3(center, -0.1, 30.0 + 96.0), sample)
		assert_false(sample.valid, "water never reaches through the bottom/slab")
		course.water_world.sample(Vector3(center + 15.95, 2.9, 30.0 + 96.0), sample)
		assert_false(sample.valid, "the outer rim is dry")


func test_collision_rays_reach_the_drawn_floor_on_both_banks_and_deep_bed() -> void:
	var course := _course()
	await wait_physics_frames(2)
	for center: float in [105.0, 155.0]:
		for station: Vector2 in [Vector2(0.0, 50.3), Vector2(-11.25, 50.3), Vector2(11.25, 50.3),
				Vector2(0.0, 96.0), Vector2(-14.0, 138.5), Vector2(14.0, 138.5)]:
			var y := WaterCourse.pool_floor_height(station.x, station.y)
			var point := Vector3(center + station.x, y, 30.0 + station.y)
			var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5.0, point - Vector3.UP)
			var hit := course.get_world_3d().direct_space_state.intersect_ray(ray)
			assert_false(hit.is_empty())
			if not hit.is_empty():
				assert_lt((hit.position as Vector3).distance_to(point), 0.0001)
		var wall_point := Vector3(center - 16.0, 1.5, 30.0 + 96.0)
		var side_ray := PhysicsRayQueryParameters3D.create(wall_point - Vector3.RIGHT * 2.0,
			wall_point + Vector3.RIGHT * 2.0)
		var wall_hit := course.get_world_3d().direct_space_state.intersect_ray(side_ray)
		assert_false(wall_hit.is_empty(), "raised sides are solid, not a floating floor")
		if not wall_hit.is_empty():
			assert_lt((wall_hit.position as Vector3).distance_to(wall_point), 0.0001)


func test_surface_stays_planar_and_its_shoreline_follows_the_actual_bed() -> void:
	var course := _course()
	var max_buried := 0.0
	var max_fade_error := 0.0
	var shore_vertices := 0
	for index: int in course.pool_water_faces.size():
		var vertex := course.pool_water_faces[index]
		assert_almost_eq(vertex.y, 2.82, 0.00001)
		var depth := 2.82 - WaterCourse.pool_floor_height(vertex.x, vertex.z)
		max_buried = maxf(max_buried, -depth)
		if depth < 0.05:
			shore_vertices += 1
			max_fade_error = maxf(max_fade_error,
				absf(course.pool_water_colors[index].a - WaterAppearance.pool_color(depth).a))
	assert_lte(max_buried, 0.00001, "no drawn water beyond the bed/rim intersection")
	assert_gt(shore_vertices, 100)
	assert_lte(max_fade_error, 0.0001, "the last 5 cm of depth owns the alpha fade")


func test_simplified_water_colors_match_submetre_source_samples_and_fit_drawing_budget() -> void:
	var course := _course()
	var rows := _face_row_bins(course.pool_water_faces)
	var maximum := 0.0
	var worst := Vector2.ZERO
	var count := 0
	for station: int in range(28, 164):
		for shift: float in [0.25, 0.75]:
			var z := station + shift
			for column: int in range(-31, 32):
				var x := column * 0.5
				var depth := 2.82 - WaterCourse.pool_floor_height(x, z)
				if depth <= 0.002:
					continue
				var color := _color_at(course, rows.get(station, []), Vector2(x, z))
				assert_gte(color.a, 0.0, "wet bed always has a drawn surface")
				var error := WaterCourse._color_error(color, WaterAppearance.pool_color(depth))
				if error > maximum:
					maximum = error
					worst = Vector2(x, z)
				count += 1
	assert_gt(count, 10000)
	assert_lte(maximum, 0.01, "max RGBA error %f at %s" % [maximum, worst])
	# Reserve budget for bounded labels and the 32-quad body emitter as well.
	assert_lte(course.geometry_primitives, 9300, "course geometry, excluding labels/effects")
	assert_lte(course.find_children("*", "MeshInstance3D", true, false).size(), 7)
	for label: Label3D in course.find_children("*", "Label3D", true, false):
		assert_gt(label.visibility_range_end, 0.0)
		assert_lte(label.visibility_range_end, WaterCourse.TITLE_RANGE)
	print("water course: %.3f s build, %d geometry triangles, sampled max RGBA error %.6f" %
		[course.build_seconds, course.geometry_primitives, maximum])


func test_rebuild_replaces_registrations_and_exit_clears_the_same_world() -> void:
	var course := _course()
	var world := course.water_world
	var nodes := course.get_child_count()
	var primitives := course.geometry_primitives
	course.build()
	assert_same(course.water_world, world)
	assert_eq(world.bodies.size(), 6)
	assert_eq(course.get_child_count(), nodes)
	assert_eq(course.geometry_primitives, primitives)
	remove_child(course)
	assert_eq(world.bodies.size(), 0)
	add_child(course)


func _face_row_bins(faces: PackedVector3Array) -> Dictionary:
	var bins: Dictionary = {}
	for index: int in range(0, faces.size(), 3):
		var low := floori(minf(faces[index].z, minf(faces[index + 1].z, faces[index + 2].z)))
		var high := floori(maxf(faces[index].z, maxf(faces[index + 1].z, faces[index + 2].z)))
		for row: int in range(low, high + 1):
			var entries: Array = bins.get(row, [])
			entries.append(index)
			bins[row] = entries
	return bins


func _color_at(course: WaterCourse, candidates: Array, point: Vector2) -> Color:
	for index: int in candidates:
		var va := course.pool_water_faces[index]
		var vb := course.pool_water_faces[index + 1]
		var vc := course.pool_water_faces[index + 2]
		var a := Vector2(va.x, va.z)
		var b := Vector2(vb.x, vb.z)
		var c := Vector2(vc.x, vc.z)
		var denominator := (b - a).cross(c - a)
		if absf(denominator) < 0.000001:
			continue
		var u := (point - a).cross(c - a) / denominator
		var v := (b - a).cross(point - a) / denominator
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return course.pool_water_colors[index] * (1.0 - u - v) + course.pool_water_colors[index + 1] * u + course.pool_water_colors[index + 2] * v
	return Color(0.0, 0.0, 0.0, -1.0)
