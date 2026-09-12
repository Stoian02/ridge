extends GutTest
## Scripted-driver checks on flat ground. They catch accidental breakage of the
## car's behaviour; they do not judge feel. Ranges live in FeelBaseline.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const MUD := preload("res://surfaces/mud.tres")

var car: Car


func _spawn_on(surface: SurfaceDef) -> void:
	add_child_autofree(ScenarioHelper.make_flat_ground(surface))
	car = ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 0.0))


func _run(seconds: float) -> void:
	await wait_physics_frames(ScenarioHelper.ticks(seconds))


## Full throttle until the car reaches target_kmh. Returns seconds taken, or -1.
func _accelerate_to(target_kmh: float, timeout: float) -> float:
	car.input.virtual_throttle = 1.0
	var ticks := 0
	while car.forward_speed() * 3.6 < target_kmh:
		await get_tree().physics_frame
		ticks += 1
		if ticks > ScenarioHelper.ticks(timeout):
			return -1.0
	return ticks / float(Engine.physics_ticks_per_second)


func test_settles_at_ride_height() -> void:
	_spawn_on(ASPHALT)
	await _run(3.0)
	var expected_sag := car.stats.mass * 9.8 / 4.0 / car.stats.spring_stiffness
	for wheel in car.wheels:
		assert_true(wheel.in_contact, "every wheel on the ground")
		assert_almost_eq(wheel.compression, expected_sag, FeelBaseline.RIDE_HEIGHT_TOLERANCE)
	assert_lt(car.linear_velocity.length(), 0.05)


func test_does_not_creep_when_parked() -> void:
	_spawn_on(ASPHALT)
	await _run(2.0)
	var start := car.global_position
	await _run(3.0)
	var creep := (car.global_position - start).length()
	gut.p("parked creep: %.4f m" % creep)
	assert_lt(creep, FeelBaseline.MAX_PARKED_CREEP)


func test_zero_to_hundred() -> void:
	_spawn_on(ASPHALT)
	await _run(1.0)
	var seconds := await _accelerate_to(100.0, 20.0)
	gut.p("0-100 km/h: %.2f s" % seconds)
	assert_between(seconds, FeelBaseline.ZERO_TO_HUNDRED_MIN, FeelBaseline.ZERO_TO_HUNDRED_MAX)
	assert_true(ScenarioHelper.is_upright(car))


func test_braking_distance_from_hundred() -> void:
	_spawn_on(ASPHALT)
	await _run(1.0)
	await _accelerate_to(100.0, 20.0)
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 1.0
	var start := car.global_position
	var ticks := 0
	while car.forward_speed() > 0.5 and ticks < ScenarioHelper.ticks(15.0):
		await get_tree().physics_frame
		ticks += 1
	var distance := (car.global_position - start).length()
	gut.p("braking 100-0 km/h: %.1f m" % distance)
	assert_between(distance, FeelBaseline.BRAKING_FROM_HUNDRED_MIN, FeelBaseline.BRAKING_FROM_HUNDRED_MAX)
	assert_true(ScenarioHelper.is_upright(car))


func test_mud_slides_more_and_turns_wider_than_asphalt() -> void:
	# Two cars side by side, one on each surface, doing the same manoeuvre.
	add_child_autofree(ScenarioHelper.make_flat_ground(ASPHALT, Vector3.ZERO))
	add_child_autofree(ScenarioHelper.make_flat_ground(MUD, Vector3(1000.0, 0.0, 0.0)))
	var on_asphalt := ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 0.0))
	var on_mud := ScenarioHelper.spawn_car(self, Vector3(1000.0, 1.0, 0.0))
	var cars: Array[Car] = [on_asphalt, on_mud]
	await _run(1.0)
	for each in cars:
		each.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(15.0):
		await get_tree().physics_frame
		for each in cars:
			if each.forward_speed() * 3.6 >= 50.0:
				each.input.virtual_throttle = 0.3
		if on_asphalt.forward_speed() * 3.6 >= 50.0 and on_mud.forward_speed() * 3.6 >= 50.0:
			break
	for each in cars:
		each.input.virtual_steer = 1.0
	# Low grip shows up as bigger tire slip angles and a lazier turn (the front
	# tires wash out), not necessarily as the body moving sideways.
	var tire_slip_deg := [0.0, 0.0]
	var yaw_rate_deg := [0.0, 0.0]
	var turn_ticks := ScenarioHelper.ticks(1.5)
	for i in turn_ticks:
		await get_tree().physics_frame
		for c in cars.size():
			for wheel in cars[c].wheels:
				tire_slip_deg[c] += absf(rad_to_deg(wheel.slip_angle)) / (4.0 * turn_ticks)
			yaw_rate_deg[c] += absf(rad_to_deg(cars[c].angular_velocity.y)) / turn_ticks
	gut.p("tire slip: asphalt %.1f deg, mud %.1f deg | yaw rate: asphalt %.1f deg/s, mud %.1f deg/s"
			% [tire_slip_deg[0], tire_slip_deg[1], yaw_rate_deg[0], yaw_rate_deg[1]])
	assert_gt(tire_slip_deg[1], tire_slip_deg[0], "tires slide more on mud")
	assert_lt(yaw_rate_deg[1], yaw_rate_deg[0], "the car turns less sharply on mud")


func test_air_control_pitches_nose_up_only_when_airborne() -> void:
	_spawn_on(ASPHALT)
	car.position.y = 30.0
	car.input.virtual_throttle = 1.0
	await wait_physics_frames(3)
	assert_false(car.air_control.is_active, "not active before the grace period")
	await _run(0.3)
	assert_true(car.air_control.is_active)
	var local_spin := car.global_basis.inverse() * car.angular_velocity
	assert_gt(local_spin.x, 0.0, "gas pitches the nose up")


func test_reset_puts_the_car_back_upright_and_still() -> void:
	_spawn_on(ASPHALT)
	await _run(1.0)
	await _accelerate_to(40.0, 10.0)
	car.input.virtual_throttle = 0.0
	var target := Transform3D(Basis(Vector3.UP, 0.5), Vector3(5.0, 1.0, 5.0))
	car.reset_to(target)
	assert_almost_eq(car.global_position.distance_to(target.origin), 0.0, 0.001)
	assert_almost_eq(car.linear_velocity.length(), 0.0, 0.001)
	assert_eq(car.drivetrain.gear, 1)
	await _run(1.0)
	assert_true(ScenarioHelper.is_upright(car))


func test_telemetry_has_the_documented_shape() -> void:
	_spawn_on(ASPHALT)
	await _run(0.5)
	var telemetry := car.get_telemetry()
	var expected := TelemetrySample.make()
	assert_eq_deep(telemetry.keys(), expected.keys())
	assert_eq(telemetry.wheels.size(), 4)
	assert_eq_deep(telemetry.wheels[0].keys(), expected.wheels[0].keys())
