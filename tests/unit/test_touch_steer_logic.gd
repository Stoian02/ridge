extends GutTest


func test_analog_inside_deadzone_is_zero() -> void:
	assert_almost_eq(TouchSteerLogic.analog_steer(10.0, 140.0, 12.0), 0.0, 0.0001)


func test_analog_full_lock() -> void:
	assert_almost_eq(TouchSteerLogic.analog_steer(140.0, 140.0, 12.0), 1.0, 0.0001)
	assert_almost_eq(TouchSteerLogic.analog_steer(-400.0, 140.0, 12.0), -1.0, 0.0001)


func test_analog_is_proportional_past_the_deadzone() -> void:
	# (76 - 12) / (140 - 12) = 0.5
	assert_almost_eq(TouchSteerLogic.analog_steer(76.0, 140.0, 12.0), 0.5, 0.0001)
	assert_almost_eq(TouchSteerLogic.analog_steer(-76.0, 140.0, 12.0), -0.5, 0.0001)


func test_buttons_ramp_toward_the_held_side() -> void:
	assert_almost_eq(TouchSteerLogic.button_steer(0.0, false, true, 3.0, 5.0, 0.1), 0.3, 0.0001)
	assert_almost_eq(TouchSteerLogic.button_steer(0.0, true, false, 3.0, 5.0, 0.1), -0.3, 0.0001)


func test_buttons_recentre_when_released() -> void:
	assert_almost_eq(TouchSteerLogic.button_steer(0.8, false, false, 3.0, 5.0, 0.1), 0.3, 0.0001)


func test_holding_both_buttons_recentres() -> void:
	assert_almost_eq(TouchSteerLogic.button_steer(0.4, true, true, 3.0, 5.0, 0.1), 0.0, 0.0001)
