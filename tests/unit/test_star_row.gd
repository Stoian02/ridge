extends GutTest


func test_earned_is_kept_between_zero_and_three() -> void:
	var row := StarRow.new()
	add_child_autofree(row)
	row.earned = 5
	assert_eq(row.earned, 3)
	row.earned = -1
	assert_eq(row.earned, 0)


func test_the_row_is_sized_for_three_stars() -> void:
	var row := StarRow.new()
	add_child_autofree(row)
	row.star_size = 50.0
	assert_eq(row.custom_minimum_size, Vector2(50.0 * 3 + row.gap * 2, 50.0))


func test_a_star_has_ten_corners_with_the_first_straight_up() -> void:
	var points := StarRow.star_points(Vector2(100.0, 100.0), 40.0)
	assert_eq(points.size(), 10)
	assert_almost_eq(points[0].x, 100.0, 0.001)
	assert_almost_eq(points[0].y, 60.0, 0.001)
	assert_almost_eq(points[1].distance_to(Vector2(100.0, 100.0)), 40.0 * StarRow.INNER_RATIO, 0.001)
	assert_false(Geometry2D.triangulate_polygon(points).is_empty(), "the outline can be filled")
