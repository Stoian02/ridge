extends GutTest


func test_builds_environment_with_fog_and_sky() -> void:
	var mood: GoldenHourMood = add_child_autofree(GoldenHourMood.new())
	assert_not_null(mood.environment)
	assert_true(mood.environment.fog_enabled)
	assert_eq(mood.environment.background_mode, Environment.BG_SKY)


func test_builds_a_low_shadow_casting_sun() -> void:
	var mood: GoldenHourMood = add_child_autofree(GoldenHourMood.new())
	assert_true(mood.sun.shadow_enabled)
	assert_lt(mood.sun.rotation_degrees.x, 0.0, "the sun points down")
	assert_gt(mood.sun.rotation_degrees.x, -45.0, "and sits low, golden-hour style")
