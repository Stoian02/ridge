extends GutTest


func _quad(y: float, low := Vector2(-3.0, -3.0), high := Vector2(3.0, 3.0)) -> PackedVector3Array:
	var a := Vector3(low.x, y, low.y)
	var b := Vector3(high.x, y, low.y)
	var c := Vector3(low.x, y, high.y)
	var d := Vector3(high.x, y, high.y)
	return PackedVector3Array([a, b, c, b, d, c])


func test_refines_only_top_preserves_inputs_and_exact_negative_coordinate_footprint() -> void:
	var top := _quad(1.0)
	var bed := _quad(0.0)
	var original_top := top.duplicate()
	var original_bed := bed.duplicate()
	var data := WaterWaveMesh.new()
	assert_true(data.build(top, bed), data.error)
	assert_eq(top, original_top)
	assert_eq(bed, original_bed)
	assert_gt(data.indices.size(), top.size())
	assert_gte(data.triangle_at(Vector2(-3.0, 0.0)), 0)
	assert_gte(data.triangle_at(Vector2(3.0, 0.0)), 0)
	assert_eq(data.triangle_at(Vector2(-3.01, 0.0)), -1)
	assert_eq(data.triangle_at(Vector2(3.01, 0.0)), -1)
	assert_eq(data.triangle_at(Vector2(NAN, 0.0)), -1)
	for index in data.vertices.size():
		assert_eq(data.vertices[index].y, 1.0)
		assert_lte(data.limits[index], 0.12)
		assert_true(data.limit_gradients[index].is_finite())
		if absf(data.vertices[index].x) >= 3.0 or absf(data.vertices[index].z) >= 3.0:
			assert_eq(data.limits[index], 0.0)
	assert_lt(data.mesh.custom_aabb.position.y, 1.0)
	assert_gt(data.mesh.custom_aabb.end.y, 1.0)


func test_bed_peak_between_vertices_limits_every_overlapping_triangle() -> void:
	var bed := _quad(0.0)
	# A tiny raised rock whose peak is not on any regular grid vertex.
	bed.append_array([Vector3(0.16, 0.97, 0.19), Vector3(0.25, 0.80, 0.19), Vector3(0.16, 0.80, 0.26)])
	var data := WaterWaveMesh.new()
	assert_true(data.build(_quad(1.0), bed), data.error)
	var triangle := data.triangle_at(Vector2(0.16, 0.19))
	assert_gte(triangle, 0)
	for corner in 3:
		assert_lte(data.limits[data.indices[triangle * 3 + corner]], 0.00601)


func test_clipped_diagonal_keeps_dry_points_dry() -> void:
	var top := PackedVector3Array([Vector3(-2.0, 1.0, -2.0), Vector3(2.0, 1.0, -2.0), Vector3(-2.0, 1.0, 2.0)])
	var data := WaterWaveMesh.new()
	assert_true(data.build(top, _quad(0.0)), data.error)
	assert_gte(data.triangle_at(Vector2(-0.7, 0.2)), 0)
	assert_eq(data.triangle_at(Vector2(0.7, 0.2)), -1)
	for point: Vector3 in data.vertices:
		assert_lte(point.x + point.z, 0.0001)


func test_unsupported_tilt_and_multiple_footprints_fail_closed() -> void:
	var data := WaterWaveMesh.new()
	var top := _quad(1.0)
	top[0].y += 0.1
	assert_false(data.build(top, _quad(0.0)))
	assert_null(data.mesh)
	top = _quad(1.0, Vector2(-3.0, -3.0), Vector2(-1.0, 3.0))
	top.append_array(_quad(1.0, Vector2(1.0, -3.0), Vector2(3.0, 3.0)))
	assert_false(data.build(top, _quad(0.0)))
	assert_eq(data.vertices.size(), 0)


func test_sampler_uses_drawn_triangle_not_continuous_function_and_invalidates_each_tick() -> void:
	var data := WaterWaveMesh.new()
	assert_true(data.build(_quad(1.0), _quad(0.0)), data.error)
	var field := WaterWaveField.new()
	var snapshot := WaterWaveSnapshot.new()
	field.step(0.5)
	field.write_snapshot(&"a", true, snapshot)
	var sampler := WaterWaveSampler.new()
	sampler.configure(data, snapshot)
	var at := Vector2(0.31, 0.22)
	var triangle := data.triangle_at(at)
	var weights := data.barycentric(at, triangle)
	var expected := 1.0
	for corner in 3:
		var index := data.indices[triangle * 3 + corner]
		var vertex := data.vertices[index]
		expected += weights[corner] * WaterWaveMath.bounded(WaterWaveMath.raw(Vector2(vertex.x, vertex.z), snapshot), data.limits[index]).x
	assert_almost_eq(sampler.height_at(at), expected, 0.000001)
	var count := sampler.evaluated_vertices
	assert_eq(sampler.height_at(at), sampler.height_at(at))
	assert_eq(sampler.evaluated_vertices, count)
	var before := sampler.height_at(at)
	field.step(0.5)
	field.write_snapshot(&"a", true, snapshot)
	assert_ne(sampler.height_at(at), before)
	assert_eq(sampler.evaluated_vertices, count + 3)
	assert_eq(sampler.height_at(Vector2(20.0, 20.0)), -INF)


func test_existing_six_bodies_fit_geometry_budget_and_do_not_change_world() -> void:
	var course := WaterCourse.new()
	add_child_autofree(course)
	var top := course.pool_water_faces.duplicate()
	var bed := course.pool_floor_faces.duplicate()
	var data := WaterWaveMesh.new()
	assert_true(data.build(top, bed, course.pool_water_colors), data.error)
	if data.mesh == null:
		return
	for gradient: Vector2 in data.limit_gradients:
		assert_true(gradient.is_finite(), "clipped/welded shore triangles must not make singular normals")
	var triangles := data.indices.size() / 3 * 2
	var built_usec := data.build_usec
	# Sample the entire pool against the actual static bed, not just source corners.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6240
	var measured := 0
	for index in 2000:
		var at := Vector2(rng.randf_range(-16.0, 16.0), rng.randf_range(28.0, 164.0))
		var triangle := data.triangle_at(at)
		var floor_y := WaterCourse.pool_floor_height(at.x, at.y)
		if floor_y < WaterCourse.POOL_LEVEL - 0.001:
			assert_gte(triangle, 0, "wet interior must remain covered")
		if triangle < 0:
			continue
		var weights := data.barycentric(at, triangle)
		var maximum_trough := 0.0
		for corner in 3:
			maximum_trough += weights[corner] * data.limits[data.indices[triangle * 3 + corner]]
		assert_gte(data.level - maximum_trough, floor_y - 0.0001, "even maximum trough must stay above bed")
		measured += 1
	assert_gt(measured, 1000)
	# There must not be an invented calm line along the source's centre seam.
	for at: Vector2 in [Vector2(0.0, 96.0), Vector2(-5.0, 96.0), Vector2(5.0, 96.0)]:
		var triangle := data.triangle_at(at)
		for corner in 3:
			assert_gt(data.limits[data.indices[triangle * 3 + corner]], 0.11)
	for index in WaterCourse.BAY_STARTS.size():
		var rows := WaterCourse._shallow_bay_rows(index)
		var source := WaterCourse._water_data(rows, 3.8, 4.0, WaterCourse.SHALLOW_LEVEL, WaterCourse.SHALLOW_LEVEL, true)
		var bay := WaterWaveMesh.new()
		assert_true(bay.build(source.faces, course.shallow_floor_faces, source.colors), bay.error)
		triangles += bay.indices.size() / 3
		built_usec += bay.build_usec
	assert_lte(triangles, 40000, "all six complete wave tops, before subtracting hidden originals")
	assert_eq(course.pool_water_faces, top)
	assert_eq(course.pool_floor_faces, bed)
	assert_eq(course.water_world.bodies.size(), 6)
	assert_lte(course.geometry_primitives, 9300)
	print("wave standalone geometry: %d triangles across six tops; elapsed build %.3f s (desktop, not phone acceptance)" % [triangles, built_usec / 1000000.0])


func test_adjacent_grid_cells_agree_on_shared_vertices_and_wave_height() -> void:
	var data := WaterWaveMesh.new()
	assert_true(data.build(_quad(1.0), _quad(0.0)))
	var positions: Dictionary = {}
	for vertex: Vector3 in data.vertices:
		assert_false(positions.has(vertex), "shared grid vertices must be welded")
		positions[vertex] = true
	var field := WaterWaveField.new()
	var snapshot := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", true, snapshot)
	var sampler := WaterWaveSampler.new()
	sampler.configure(data, snapshot)
	for index in range(-3, 4):
		var x := index * 0.75
		var left := sampler.height_at(Vector2(x - 0.0001, 0.123))
		var right := sampler.height_at(Vector2(x + 0.0001, 0.123))
		assert_lt(absf(left - right), 0.0001)
