extends GutTest


func test_packaged_meshes_match_fresh_derivation_exactly_including_masks_and_lookup() -> void:
	var course := WaterCourse.new()
	add_child_autofree(course)
	var cache := WaterWaveCourseCache.new()
	assert_true(cache.prepare(course), cache.error)
	if cache.tops.size() != 5:
		return
	var source_top := course.pool_water_faces.duplicate()
	var source_bed := course.pool_floor_faces.duplicate()
	for index in 5:
		var top := source_top
		var bed := source_bed
		var colors := course.pool_water_colors
		if index > 0:
			var rows := WaterCourse._shallow_bay_rows(index - 1)
			var source := WaterCourse._water_data(rows, 3.8, 4.0, WaterCourse.SHALLOW_LEVEL, WaterCourse.SHALLOW_LEVEL, true)
			top = source.faces
			colors = source.colors
			bed = course.shallow_floor_faces
		var fresh := WaterWaveMesh.new()
		assert_true(fresh.build(top, bed, colors), fresh.error)
		var baked := cache.tops[index]
		assert_eq(baked.vertices, fresh.vertices)
		assert_eq(baked.indices, fresh.indices)
		assert_eq(baked.colors, fresh.colors)
		assert_eq(baked.limits, fresh.limits)
		assert_eq(baked.limit_gradients, fresh.limit_gradients)
		assert_eq(baked._cells, fresh._cells)
		assert_eq(baked.mesh.surface_get_arrays(0), fresh.mesh.surface_get_arrays(0))
		assert_eq(baked.mesh.custom_aabb, fresh.mesh.custom_aabb)
		var snapshot := WaterWaveSnapshot.new()
		var field := WaterWaveField.new()
		field.step(0.7)
		field.write_snapshot(&"fixture", true, snapshot)
		var a := WaterWaveSampler.new()
		var b := WaterWaveSampler.new()
		a.configure(fresh, snapshot)
		b.configure(baked, snapshot)
		for triangle in range(0, baked.indices.size() / 3, 71):
			var at := Vector3.ZERO
			for corner in 3:
				at += baked.vertices[baked.indices[triangle * 3 + corner]] / 3.0
			assert_eq(a.height_at(Vector2(at.x, at.z)), b.height_at(Vector2(at.x, at.z)))
	assert_eq(course.pool_water_faces, source_top)
	assert_eq(course.pool_floor_faces, source_bed)
	assert_eq(course.water_world.bodies.size(), 6)
	print("wave prepared cache ", cache.phases, " (desktop only)")


func test_geometry_or_cap_changes_fail_closed_without_slow_runtime_fallback() -> void:
	var course := WaterCourse.new()
	add_child_autofree(course)
	var cache := WaterWaveCourseCache.new()
	var profile := WaterWaveProfile.new()
	profile.maximum_offset = 0.10
	assert_false(cache.prepare(course, profile))
	assert_true(cache.tops.is_empty())
	assert_string_contains(cache.error, "stale")
	profile.maximum_offset = 0.12
	profile.ambient_amplitudes = Vector2.ZERO
	assert_true(cache.prepare(course, profile), "runtime wave strength does not change static topology")
	var bed := course.pool_floor_faces.duplicate()
	bed[0].y += 0.001
	var expected := WaterWaveBake.fingerprint(course.pool_water_faces, bed, course.pool_water_colors, profile)
	var bake: WaterWaveBake = load("res://water/waves/baked/deep.res")
	var data := WaterWaveMesh.new()
	assert_false(data.use_bake(bake, expected))
	assert_null(data.mesh)
	assert_false(data.use_bake(null, expected))
	var wrong := bake.duplicate() as WaterWaveBake
	wrong.revision += 1
	assert_false(data.use_bake(wrong, bake.source_fingerprint))


func test_preparation_audit_partitions_cost_without_changing_geometry() -> void:
	var top := PackedVector3Array([Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(-1, 1, 1)])
	var bed := top.duplicate()
	for index in bed.size():
		bed[index].y = 0.0
	var a := WaterWaveMesh.new()
	var b := WaterWaveMesh.new()
	assert_true(a.build(top, bed))
	assert_true(b.build(top, bed, PackedColorArray(), null, true))
	assert_eq(a.vertices, b.vertices)
	assert_eq(a.limits, b.limits)
	assert_eq(a.indices, b.indices)
	var sum := 0
	for key: String in ["source_index_usec", "outline_shore_index_usec", "depth_derivation_usec",
		"topology_attributes_usec", "normals_arrays_usec", "mesh_commit_usec"]:
		assert_gte(int(b.build_phases[key]), 0)
		sum += int(b.build_phases[key])
	assert_lte(sum, b.build_usec)
