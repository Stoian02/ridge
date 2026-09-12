extends GutTest

var stats: CarStats
var steering: Steering


func before_each() -> void:
	stats = CarStats.new()
	steering = Steering.new(stats)


func test_full_lock_when_stopped() -> void:
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(0.0, stats)), 32.0, 0.001)


func test_assist_allows_only_the_useful_angle_at_speed() -> void:
	# At 14 m/s the tightest grip-limited arc needs 7.9 degrees of geometry, and
	# the assist adds 0.75 of the tire's 8 degree best slip angle on top.
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(14.0, stats)), 13.89, 0.01)
	assert_almost_eq(rad_to_deg(Steering.max_angle_for_speed(40.0, stats)), 6.97, 0.01)


func test_lock_shrinks_as_speed_rises() -> void:
	var previous := rad_to_deg(Steering.max_angle_for_speed(5.0, stats))
	for speed in [10.0, 20.0, 30.0, 40.0, 60.0]:
		var angle := rad_to_deg(Steering.max_angle_for_speed(speed, stats))
		assert_lt(angle, previous, "%.0f m/s allows less lock" % speed)
		previous = angle


func test_lock_never_exceeds_the_steering_limit() -> void:
	for speed in [0.0, 1.0, 3.0, 6.0]:
		assert_lte(rad_to_deg(Steering.max_angle_for_speed(speed, stats)), stats.max_steer_deg)


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
