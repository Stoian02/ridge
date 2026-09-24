extends GutTest
## Compare the accelerated index to the original interpolation on shipped
## ford, creek and rut geometry, not merely rectangular synthetic pools.


func test_canyon_ford_and_ruts_match_the_unrefined_query() -> void:
	_check_level("rock_canyon")


func test_valley_creek_matches_the_unrefined_query() -> void:
	_check_level("muddy_valley")


func _check_level(id: String) -> void:
	var level: Node = load("res://levels/%s/%s.tscn" % [id, id]).instantiate()
	var trail: TrailLevel = level.get_node("Trail")
	level.remove_child(trail)
	level.free()
	add_child_autofree(trail)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14952
	var refined := WaterSample.new()
	var original := WaterSample.new()
	var fast_tests := 0
	var slow_tests := 0
	for body: WaterBody in trail.water_world.bodies:
		for index in 500:
			var triangle := rng.randi_range(0, body.top_triangle_count - 1) * 3
			var a := body._top[triangle]
			var b := body._top[triangle + 1]
			var c := body._top[triangle + 2]
			var point := a.lerp(b, rng.randf()).lerp(c, rng.randf())
			# Include exact vertices/seams and finite-bottom rejection as well.
			if index % 5 == 0:
				point = a
			point.y += rng.randf_range(-1.0, 0.5)
			body.sample(point, refined, 0.3)
			fast_tests += body.triangle_tests
			var saved := body._refined_bed_cells
			body._refined_bed_cells = {}
			body.sample(point, original, 0.3)
			body._refined_bed_cells = saved
			slow_tests += body.triangle_tests
			assert_eq(refined.valid, original.valid, str(body.id))
			assert_eq(refined.surface_y, original.surface_y)
			assert_eq(refined.bed_y, original.bed_y)
			assert_eq(refined.current, original.current)
			assert_eq(refined.edge_weight, original.edge_weight)
	assert_lte(fast_tests, slow_tests, "refinement cannot add candidate tests")
	if id == "rock_canyon":
		assert_lt(fast_tests, slow_tests, "dense canyon beds must benefit")
