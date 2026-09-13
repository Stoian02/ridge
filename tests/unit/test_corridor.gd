extends GutTest

const ROAD := 100.0
const NATURAL := 112.0
const BLEND := 25.0
const DROP := 0.3


func _height(edge_distance: float) -> float:
	return Corridor.carved_height(ROAD, NATURAL, edge_distance, BLEND, DROP)


func test_terrain_meets_the_shoulder_edge_just_below_it() -> void:
	assert_almost_eq(_height(0.0), ROAD - Corridor.EDGE_GAP, 0.0001)


func test_terrain_is_natural_at_the_end_of_the_blend() -> void:
	assert_almost_eq(_height(BLEND), NATURAL, 0.0001)
	assert_almost_eq(_height(BLEND + 40.0), NATURAL, 0.0001)


func test_blend_rises_steadily_toward_higher_natural_terrain() -> void:
	var previous := _height(0.0)
	for step in range(1, 26):
		var current := _height(float(step))
		assert_gte(current, previous, "at %d m" % step)
		previous = current


func test_terrain_sits_well_below_the_asphalt() -> void:
	assert_almost_eq(_height(-5.0), ROAD - DROP, 0.0001)


func test_no_step_at_the_edge() -> void:
	assert_almost_eq(_height(-0.001), _height(0.001), 0.001)
