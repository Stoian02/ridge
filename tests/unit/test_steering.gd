extends GutTest

var stats: CarStats
var steering: Steering


func before_each() -> void:
	stats = CarStats.new()
	steering = Steering.new(stats)


func test_full_lock_when_stopped() -> void:
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(0.0, stats)), 32.0, 0.001)


func test_lock_shrinks_with_speed() -> void:
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(20.0, stats)), 20.0, 0.001)
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(40.0, stats)), 8.0, 0.001)
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(80.0, stats)), 8.0, 0.001)


func test_wheels_turn_at_a_limited_rate() -> void:
	# 180 deg/s for 1/120 s = 1.5 degrees.
	steering.update(1.0 / 120.0, 1.0, 0.0)
	assert_almost_eq(rad_to_deg(steering.angle), 1.5, 0.001)


func test_reaches_full_lock_after_enough_time() -> void:
	for i in 120:
		steering.update(1.0 / 120.0, 1.0, 0.0)
	assert_almost_eq(rad_to_deg(steering.angle), 32.0, 0.001)


func test_left_input_turns_left() -> void:
	steering.update(1.0, -1.0, 0.0)
	assert_almost_eq(rad_to_deg(steering.angle), -32.0, 0.001)


func test_recentres_when_released() -> void:
	steering.update(1.0, 1.0, 0.0)
	steering.update(1.0, 0.0, 0.0)
	assert_almost_eq(rad_to_deg(steering.angle), 0.0, 0.0001)
