extends GutTest


func test_pothole_is_deepest_at_its_centre() -> void:
	assert_almost_eq(RoughShapes.pothole(0.0, 0.5, 0.12), -0.12, 0.0001)


func test_pothole_is_flat_at_and_beyond_its_radius() -> void:
	assert_almost_eq(RoughShapes.pothole(0.5, 0.5, 0.12), 0.0, 0.0001)
	assert_almost_eq(RoughShapes.pothole(2.0, 0.5, 0.12), 0.0, 0.0001)


func test_pothole_is_bowl_shaped() -> void:
	# Halfway out: -depth * (1 - 0.25)
	assert_almost_eq(RoughShapes.pothole(0.25, 0.5, 0.12), -0.09, 0.0001)


func test_bump_peaks_on_its_centre_line_and_ends_at_half_length() -> void:
	assert_almost_eq(RoughShapes.bump(0.0, 0.9, 0.08), 0.08, 0.0001)
	assert_almost_eq(RoughShapes.bump(0.45, 0.9, 0.08), 0.0, 0.0001)
	assert_almost_eq(RoughShapes.bump(-0.45, 0.9, 0.08), 0.0, 0.0001)


func test_washboard_is_a_sine() -> void:
	assert_almost_eq(RoughShapes.washboard(0.175, 0.025, 0.7), 0.025, 0.0001)
	assert_almost_eq(RoughShapes.washboard(0.35, 0.025, 0.7), 0.0, 0.0001)


func test_rut_is_deepest_on_its_centre_line() -> void:
	assert_almost_eq(RoughShapes.rut(0.0, 0.35, 0.1), -0.1, 0.0001)
	assert_almost_eq(RoughShapes.rut(0.35, 0.35, 0.1), 0.0, 0.0001)
