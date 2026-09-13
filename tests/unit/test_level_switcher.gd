extends GutTest


func test_track_button_switches_between_the_two_levels() -> void:
	assert_eq(LevelSwitcher.other_level(LevelSwitcher.RALLY_ROAD), LevelSwitcher.TEST_GROUND)
	assert_eq(LevelSwitcher.other_level(LevelSwitcher.TEST_GROUND), LevelSwitcher.RALLY_ROAD)
	assert_eq(LevelSwitcher.other_level("res://anything_else.tscn"), LevelSwitcher.RALLY_ROAD)
