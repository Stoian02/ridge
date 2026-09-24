extends GutTest
## Finite triangle-defined volumes, deterministic overlaps and immutable data.


static func quad(height: float, from: Vector2 = Vector2(-2.0, -2.0),
		to: Vector2 = Vector2(2.0, 2.0)) -> PackedVector3Array:
	var a := Vector3(from.x, height, from.y)
	var b := Vector3(to.x, height, from.y)
	var c := Vector3(from.x, height, to.y)
	var d := Vector3(to.x, height, to.y)
	return PackedVector3Array([a, b, c, b, d, c])


static func definition(id: StringName = &"pool") -> WaterBodyDef:
	var def := WaterBodyDef.new()
	def.id = id
	return def


func test_column_is_valid_above_surface_but_finite_below_its_actual_bed() -> void:
	var world := WaterWorld.new()
	assert_not_null(world.add_body(definition(), quad(2.0), quad(0.0)))
	var sample := WaterSample.new()
	world.sample(Vector3(0.0, 8.0, 0.0), sample)
	assert_true(sample.valid, "above-water intake needs the column's clearance")
	assert_eq(sample.surface_y, 2.0)
	assert_eq(sample.bed_y, 0.0)
	world.sample(Vector3(0.0, -0.1, 0.0), sample)
	assert_false(sample.valid)
	world.sample(Vector3(0.0, -0.1, 0.0), sample, 0.2)
	assert_true(sample.valid, "sphere can intersect the column from below")
	world.sample(Vector3(0.0, -100.0, 0.0), sample, 0.2)
	assert_false(sample.valid, "off-map points never remain wet")
	assert_eq(sample.current, Vector3.ZERO)
	assert_eq(sample.body_id, &"")


func test_real_triangle_gaps_stay_dry_even_inside_the_same_body_bounds() -> void:
	var world := WaterWorld.new()
	var faces := quad(1.0, Vector2(-5.0, -2.0), Vector2(-2.0, 2.0))
	faces.append_array(quad(1.0, Vector2(2.0, -2.0), Vector2(5.0, 2.0)))
	world.add_body(definition(), faces, quad(0.0, Vector2(-6.0, -3.0), Vector2(6.0, 3.0)))
	var sample := WaterSample.new()
	world.sample(Vector3(-3.0, 0.5, 0.0), sample)
	assert_true(sample.valid)
	world.sample(Vector3(3.0, 0.5, 0.0), sample)
	assert_true(sample.valid)
	world.sample(Vector3(0.0, 0.5, 0.0), sample, 1.0)
	assert_false(sample.valid, "radius does not expand footprints sideways")


func test_shore_weight_has_no_fade_at_triangle_diagonal_or_shared_row_seam() -> void:
	var world := WaterWorld.new()
	var faces := quad(1.0, Vector2(-2.0, -2.0), Vector2(0.0, 2.0))
	faces.append_array(quad(1.0, Vector2(0.0, -2.0), Vector2(2.0, 2.0)))
	world.add_body(definition(), faces, quad(0.0))
	var sample := WaterSample.new()
	for point: Vector3 in [Vector3.ZERO, Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]:
		world.sample(point, sample)
		assert_true(sample.valid)
		assert_eq(sample.edge_weight, 1.0)
	world.sample(Vector3(1.95, 0.5, 0.0), sample)
	assert_almost_eq(sample.edge_weight, 0.5, 0.0001)
	world.sample(Vector3(2.01, 0.5, 0.0), sample, 0.5)
	assert_false(sample.valid)


func test_water_and_bed_use_triangle_interpolation_not_a_nominal_or_bilinear_depth() -> void:
	var world := WaterWorld.new()
	var top := quad(2.0, Vector2.ZERO, Vector2.ONE)
	for index in top.size():
		top[index].y += top[index].x * 0.5
	var bed := quad(0.0, Vector2.ZERO, Vector2.ONE)
	bed[4].y = 4.0
	world.add_body(definition(), top, bed)
	var sample := WaterSample.new()
	world.sample(Vector3(0.25, 1.0, 0.25), sample)
	assert_true(sample.valid)
	assert_almost_eq(sample.surface_y, 2.125, 0.000001)
	assert_eq(sample.bed_y, 0.0, "lower terrain triangle stays flat, bilinear would give .25")
	world.sample(Vector3(0.95, 4.0, 0.95), sample)
	assert_false(sample.valid, "bank above drawn ribbon is solid, not invisible water")


func test_t_junction_long_edge_against_short_edges_is_not_a_fake_shore() -> void:
	var world := WaterWorld.new()
	var faces := quad(1.0, Vector2(-2.0, -2.0), Vector2(0.0, 2.0))
	faces.append_array(quad(1.0, Vector2(0.0, -2.0), Vector2(2.0, 0.0)))
	faces.append_array(quad(1.0, Vector2(0.0, 0.0), Vector2(2.0, 2.0)))
	world.add_body(definition(), faces, quad(0.0))
	var sample := WaterSample.new()
	for z: float in [-1.0, -0.02, 0.0, 0.02, 1.0]:
		world.sample(Vector3(0.0, 0.5, z), sample)
		assert_true(sample.valid)
		assert_eq(sample.edge_weight, 1.0)


func test_highest_bed_masks_a_rock_or_bridge_deck_not_just_the_lower_terrain() -> void:
	var world := WaterWorld.new()
	var bed := quad(0.0)
	bed.append_array(quad(1.2, Vector2(-0.5, -0.5), Vector2(0.5, 0.5)))
	world.add_body(definition(), quad(1.0), bed)
	var sample := WaterSample.new()
	world.sample(Vector3(1.0, 0.5, 0.0), sample)
	assert_true(sample.valid)
	world.sample(Vector3(0.0, 2.0, 0.0), sample)
	assert_false(sample.valid)


func test_highest_surface_wins_and_equal_height_ties_use_stable_id_not_registration_order() -> void:
	var world := WaterWorld.new()
	var sample := WaterSample.new()
	var higher := world.add_body(definition(&"z"), quad(2.0), quad(0.0))
	world.add_body(definition(&"a"), quad(1.0), quad(0.0))
	world.sample(Vector3.ZERO, sample)
	assert_eq(sample.body_id, &"z")
	world.remove_body(higher)
	world.add_body(definition(&"b"), quad(1.0), quad(0.0))
	world.sample(Vector3.ZERO, sample)
	assert_eq(sample.body_id, &"a")
	world.clear()
	world.add_body(definition(&"b"), quad(1.0), quad(0.0))
	world.add_body(definition(&"a"), quad(1.0), quad(0.0))
	world.sample(Vector3.ZERO, sample)
	assert_eq(sample.body_id, &"a")


func test_rigid_transform_rotates_geometry_and_current_without_translating_velocity() -> void:
	var world := WaterWorld.new()
	var def := definition()
	def.current_velocity = Vector3(0.75, 0.0, 0.0)
	var transform := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(35.0, 7.0, -18.0))
	world.add_body(def, quad(2.0), quad(0.0), transform)
	var sample := WaterSample.new()
	world.sample(transform * Vector3(0.5, 1.0, 0.0), sample)
	assert_true(sample.valid)
	assert_almost_eq(sample.surface_y, 9.0, 0.0001)
	assert_almost_eq(sample.bed_y, 7.0, 0.0001)
	assert_lt(sample.current.distance_to(Vector3(0.0, 0.0, -0.75)), 0.0001)
	world.sample(Vector3.ZERO, sample)
	assert_false(sample.valid)


func test_tilted_water_triangles_are_sampled_in_world_vertical_columns() -> void:
	var world := WaterWorld.new()
	var transform := Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0.0, 3.0, 0.0))
	world.add_body(definition(), quad(2.0), quad(0.0), transform)
	var top_point := transform * Vector3(0.0, 2.0, 0.0)
	var sample := WaterSample.new()
	world.sample(top_point, sample)
	assert_true(sample.valid)
	assert_almost_eq(sample.surface_y, top_point.y, 0.00001)
	assert_gt(sample.surface_y, sample.bed_y)


func test_invalid_transforms_are_rejected_and_uniform_scale_is_supported() -> void:
	var world := WaterWorld.new()
	assert_null(world.add_body(definition(), quad(1.0), quad(0.0),
			Transform3D(Basis.from_scale(Vector3(1.0, 2.0, 1.0)), Vector3.ZERO)))
	assert_null(world.add_body(definition(), quad(1.0), quad(0.0),
			Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO)))
	assert_eq(world.bodies.size(), 0)
	assert_not_null(world.add_body(definition(), quad(1.0), quad(0.0),
			Transform3D(Basis.from_scale(Vector3.ONE * 2.0), Vector3.ZERO)))
	var sample := WaterSample.new()
	world.sample(Vector3(3.0, 1.0, 0.0), sample)
	assert_true(sample.valid)
	assert_eq(sample.surface_y, 2.0)


func test_registered_values_are_immutable_snapshots_of_resources_arrays_and_currents() -> void:
	var world := WaterWorld.new()
	var def := definition()
	var faces := quad(1.0)
	var bed := quad(0.0)
	var currents := PackedVector3Array([Vector3.RIGHT, Vector3.RIGHT])
	world.add_body(def, faces, bed, Transform3D.IDENTITY, currents)
	faces[0] = Vector3(50.0, 50.0, 50.0)
	bed.fill(Vector3(0.0, 20.0, 0.0))
	currents.fill(Vector3.ZERO)
	def.id = &"changed"
	def.color = Color.RED
	var sample := WaterSample.new()
	world.sample(Vector3(0.0, 0.5, 0.0), sample)
	assert_true(sample.valid)
	assert_eq(sample.body_id, &"pool")
	assert_eq(sample.surface_y, 1.0)
	assert_eq(sample.bed_y, 0.0)
	assert_eq(sample.current, Vector3.RIGHT)
	assert_ne(sample.color, Color.RED)


func test_remove_replace_clear_and_teleport_invalidate_nearby_candidates() -> void:
	var world := WaterWorld.new()
	var sample := WaterSample.new()
	var body := world.add_body(definition(), quad(1.0), quad(0.0))
	world.sample(Vector3.ZERO, sample)
	assert_true(sample.valid)
	world.remove_body(body)
	world.sample(Vector3.ZERO, sample)
	assert_false(sample.valid)
	world.add_body(definition(), quad(1.0), quad(0.0))
	world.add_body(definition(), quad(2.0), quad(0.0))
	assert_eq(world.bodies.size(), 1)
	world.sample(Vector3.ZERO, sample)
	assert_eq(sample.surface_y, 2.0)
	world.sample(Vector3(1000.0, 0.0, 1000.0), sample)
	assert_false(sample.valid)
	world.sample(Vector3.ZERO, sample)
	assert_true(sample.valid)
	world.clear()
	world.sample(Vector3.ZERO, sample)
	assert_false(sample.valid)


func test_dry_broad_phase_does_not_inspect_triangles_and_nonfinite_input_is_safe() -> void:
	var world := WaterWorld.new()
	world.add_body(definition(), quad(1.0), quad(0.0))
	var sample := WaterSample.new()
	world.reset_metrics()
	world.sample(Vector3(500.0, 0.0, 500.0), sample)
	assert_eq(world.query_count, 1)
	assert_eq(world.triangle_tests, 0)
	world.sample(Vector3(NAN, 0.0, 0.0), sample)
	assert_false(sample.valid)
	assert_eq(world.triangle_tests, 0)


func test_missing_bed_and_invalid_face_current_counts_do_not_make_unbounded_water() -> void:
	var world := WaterWorld.new()
	assert_null(world.add_body(definition(), quad(1.0), PackedVector3Array()))
	assert_null(world.add_body(definition(), quad(1.0), quad(0.0), Transform3D.IDENTITY,
			PackedVector3Array([Vector3.ZERO])))
	assert_eq(world.bodies.size(), 0)


func test_dense_bed_refinement_matches_original_bins_at_edges_and_random_points() -> void:
	var bed := PackedVector3Array()
	for z in 32:
		for x in 32:
			var from := Vector2(x, z) * 0.125 - Vector2.ONE * 2.0
			var faces := quad(0.0, from, from + Vector2.ONE * 0.125)
			for index in faces.size():
				faces[index].y = sin(faces[index].x * 2.0) * cos(faces[index].z) * 0.2
			bed.append_array(faces)
	# Overlapping raised faces, slopes, a projected vertical face and a large
	# diagonal all retain the highest-bed rule and original face interpolation.
	bed.append_array(quad(1.5, Vector2(-0.6, -0.5), Vector2(0.6, 0.5)))
	bed.append_array([Vector3(-2, 0, -2), Vector3(2, 0.2, 2), Vector3(2, 0.3, -2)])
	bed.append_array([Vector3.ZERO, Vector3.UP, Vector3.FORWARD])
	var world := WaterWorld.new()
	var body := world.add_body(definition(), quad(1.0), bed)
	assert_gt(body._refined_bed_cells.size(), 0)
	var original := WaterSample.new()
	var refined := WaterSample.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6214
	var original_tests := 0
	var refined_tests := 0
	for index in 2500:
		var point := Vector3(rng.randf_range(-2.1, 2.1), rng.randf_range(-0.5, 2.0), rng.randf_range(-2.1, 2.1))
		if index < 300:
			# Exact sub-cell edges and either side, also at negative coordinates.
			point.x = (index % 9 - 4) * 0.5 + (index % 3 - 1) * 0.00001
			point.z = (index % 7 - 3) * 0.5
		body.sample(point, refined, 0.25)
		refined_tests += body.triangle_tests
		var saved := body._refined_bed_cells
		body._refined_bed_cells = {}
		body.sample(point, original, 0.25)
		body._refined_bed_cells = saved
		original_tests += body.triangle_tests
		assert_eq(refined.valid, original.valid)
		assert_eq(refined.bed_y, original.bed_y)
		assert_eq(refined.surface_y, original.surface_y)
		assert_eq(refined.current, original.current)
		assert_eq(refined.edge_weight, original.edge_weight)
	assert_lt(refined_tests, original_tests / 4)


func test_refinement_keeps_barycentric_tolerance_beyond_a_long_triangle_tip() -> void:
	var bed := quad(-2.0)
	for index in 33:
		bed.append_array([Vector3(-1000.0, 0.0, 1.0), Vector3(0.4985, 0.0, 1.0), Vector3(-1000.0, 0.0, 2.0)])
	var world := WaterWorld.new()
	var body := world.add_body(definition(), quad(1.0), bed)
	var point := Vector3(0.5001, 0.5, 0.9999992)
	var original := WaterSample.new()
	var refined := WaterSample.new()
	body.sample(point, refined)
	body._refined_bed_cells.clear()
	body.sample(point, original)
	assert_true(original.valid)
	assert_eq(original.bed_y, 0.0, "original barycentric tolerance accepts the extended tip")
	assert_eq(refined.bed_y, original.bed_y, "padding must cross the next 0.5 m bin boundary")
