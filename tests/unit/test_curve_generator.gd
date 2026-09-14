extends GutTest
## CurveGenerator's segments, and each level's saved curve matching its tool.

const LEVEL_CURVES := {
	"res://tools/generate_rally_road_curve.gd": "res://levels/rally_road/rally_road_curve.tres",
	"res://tools/generate_muddy_valley_curve.gd": "res://levels/muddy_valley/muddy_valley_curve.tres",
}


func test_a_straight_climbs_by_its_grade() -> void:
	var curve := CurveGenerator.build_curve([["straight", 100.0, -0.08]])
	assert_almost_eq(curve.get_point_position(1), Vector3(0.0, -8.0, -100.0), Vector3.ONE * 0.0001)


func test_a_left_hairpin_turns_the_road_around() -> void:
	var curve := CurveGenerator.build_curve([["straight", 50.0, 0.0], ["arc", 15.0, 180.0, 0.0]])
	assert_almost_eq(curve.get_point_position(curve.point_count - 1), Vector3(-30.0, 0.0, -50.0), Vector3.ONE * 0.001)


func test_parts_that_pass_too_close_are_reported() -> void:
	var curve := CurveGenerator.build_curve([["straight", 100.0, 0.0], ["arc", 5.0, 180.0, 0.0], ["straight", 100.0, 0.0]])
	assert_gt(CurveGenerator.separation_problems(curve).size(), 0)


func test_each_saved_level_curve_is_what_its_tool_builds() -> void:
	for tool_path: String in LEVEL_CURVES:
		var segments: Array = load(tool_path).get_script_constant_map()["SEGMENTS"]
		var built := CurveGenerator.build_curve(segments)
		var saved: Curve3D = load(LEVEL_CURVES[tool_path])
		assert_eq(saved.point_count, built.point_count, tool_path)
		for i in mini(saved.point_count, built.point_count):
			assert_almost_eq(saved.get_point_position(i), built.get_point_position(i), Vector3.ONE * 0.001,
					"%s point %d" % [tool_path, i])
		assert_eq(CurveGenerator.separation_problems(saved), [], "%s keeps its parts apart" % tool_path)
