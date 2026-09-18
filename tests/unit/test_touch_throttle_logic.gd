extends GutTest
## The throttle lever's pure maths (M5 spec §11.2).


func test_bottom_dead_zone_middle_top_and_beyond_both_ends() -> void:
	var rect := Rect2(100.0, 400.0, 250.0, 560.0)  # the track's bottom is at y = 960
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 960.0)), 0.0, 0.0001, "bottom")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 930.0)), 0.0, 0.0001, "inside the bottom 10% dead zone")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 904.0)), 0.0, 0.0001, "at the dead-zone boundary")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 890.0)), 0.125, 0.0001, "just above it reads its height")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 680.0)), 0.5, 0.0001, "mid-track")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 400.0)), 1.0, 0.0001, "top")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 100.0)), 1.0, 0.0001, "beyond the top")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(200.0, 1050.0)), 0.0, 0.0001, "beyond the bottom")
	assert_almost_eq(TouchThrottleLogic.value_for(rect, Vector2(900.0, 680.0)), 0.5, 0.0001, "horizontal position is ignored")
	assert_almost_eq(TouchThrottleLogic.value_for(Rect2(0.0, 0.0, 10.0, 0.0), Vector2.ZERO), 0.0, 0.0001, "a flat rect is closed")
