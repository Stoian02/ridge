extends GutTest

var stats: CarStats
var air: AirControl


func before_each() -> void:
	stats = CarStats.new()
	air = AirControl.new(stats)


func test_inactive_while_any_wheel_touches() -> void:
	air.update(0.5, 1)
	assert_false(air.is_active)


func test_activates_only_after_the_grace_period() -> void:
	air.update(0.05, 0)
	assert_false(air.is_active, "0.05 s airborne is still a bump")
	air.update(0.06, 0)
	assert_true(air.is_active, "0.11 s airborne is a real jump")


func test_one_wheel_touching_turns_it_off_immediately() -> void:
	air.update(0.2, 0)
	air.update(0.01, 1)
	assert_false(air.is_active)
	assert_almost_eq(air.airborne_time, 0.0, 0.0001)


func test_no_torque_while_inactive() -> void:
	assert_eq(air.local_torque(1.0, 0.0, 1.0), Vector3.ZERO)


func test_gas_pitches_nose_up_and_brake_pitches_it_down() -> void:
	air.update(0.2, 0)
	assert_gt(air.local_torque(1.0, 0.0, 0.0).x, 0.0)
	assert_lt(air.local_torque(0.0, 1.0, 0.0).x, 0.0)


func test_steering_right_rolls_right() -> void:
	air.update(0.2, 0)
	# Rolling right = right side down = negative rotation about +Z.
	assert_lt(air.local_torque(0.0, 0.0, 1.0).z, 0.0)


func test_reset_clears_state() -> void:
	air.update(0.2, 0)
	air.reset()
	assert_false(air.is_active)
	assert_almost_eq(air.airborne_time, 0.0, 0.0001)
