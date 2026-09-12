extends GutTest
## Braking hard while steering must still turn the car the way the wheels point.
## A locked or badly modelled tire pushes the nose out of the turn instead.

const ASPHALT := preload("res://surfaces/asphalt.tres")


func test_braking_while_steering_turns_into_the_corner() -> void:
	add_child_autofree(ScenarioHelper.make_flat_ground(ASPHALT))
	var car := ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 0.0))
	await wait_physics_frames(ScenarioHelper.ticks(1.0))

	car.input.virtual_throttle = 1.0
	var ticks := 0
	while car.forward_speed() * 3.6 < 60.0 and ticks < ScenarioHelper.ticks(15.0):
		await get_tree().physics_frame
		ticks += 1

	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 1.0
	car.input.virtual_steer = 1.0  # full right
	var worst_wrong_way := 0.0
	var total_yaw := 0.0
	var samples := ScenarioHelper.ticks(1.5)
	for i in samples:
		await get_tree().physics_frame
		# Yaw about +Y is to the left, so steering right should give negative yaw.
		var yaw_rate := rad_to_deg(car.angular_velocity.y)
		worst_wrong_way = maxf(worst_wrong_way, yaw_rate)
		total_yaw += yaw_rate / samples
	gut.p("brake-in-turn: average yaw %+.1f deg/s, worst wrong-way yaw %+.1f deg/s (+ = away from the turn)"
			% [total_yaw, worst_wrong_way])
	assert_lt(total_yaw, -3.0, "the car turns into the corner while braking")
	assert_lt(worst_wrong_way, 2.0, "it never swings noticeably the other way")
	assert_true(ScenarioHelper.is_upright(car))


func test_abs_keeps_the_wheels_turning_under_full_braking() -> void:
	add_child_autofree(ScenarioHelper.make_flat_ground(ASPHALT))
	var car := ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 0.0))
	await wait_physics_frames(ScenarioHelper.ticks(1.0))

	car.input.virtual_throttle = 1.0
	var ticks := 0
	while car.forward_speed() * 3.6 < 80.0 and ticks < ScenarioHelper.ticks(15.0):
		await get_tree().physics_frame
		ticks += 1

	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 1.0
	var worst_slip := 0.0
	for i in ScenarioHelper.ticks(1.0):
		await get_tree().physics_frame
		for wheel in car.wheels:
			worst_slip = minf(worst_slip, wheel.slip_ratio)
	gut.p("straight-line braking: worst slip ratio %.2f (-1 = locked)" % worst_slip)
	assert_gt(worst_slip, -0.9, "no wheel locks up solid")
