extends GutTest
## Isolated matched-bed fixtures: real car integration, not a null water profile.

const CAR_SCENE := preload("res://car/car.tscn")
const ASPHALT := preload("res://surfaces/asphalt.tres")
const STATS: Array[CarStats] = [preload("res://car/rally_car.tres"), preload("res://car/rally_car_tuned.tres"), preload("res://car/offroad_4x4.tres")]
var _original_rate: int = 120


func before_each() -> void:
	_original_rate = Engine.physics_ticks_per_second


func after_each() -> void:
	Engine.physics_ticks_per_second = _original_rate


func _plane(y: float) -> PackedVector3Array:
	return PackedVector3Array([Vector3(-50.0, y, -50.0), Vector3(50.0, y, 50.0), Vector3(50.0, y, -50.0),
			Vector3(-50.0, y, -50.0), Vector3(-50.0, y, 50.0), Vector3(50.0, y, 50.0)])


func _pool(depth: float, current: Vector3 = Vector3.ZERO) -> WaterWorld:
	var world := WaterWorld.new()
	var def := WaterBodyDef.new()
	def.id = &"fixture_pool"
	def.current_velocity = current
	world.add_body(def, _plane(depth), _plane(0.0))
	return world


func _spawn(stats: CarStats, point: Vector3, world: WaterWorld = null) -> Car:
	var car: Car = CAR_SCENE.instantiate()
	car.stats = stats
	car.position = point
	add_child(car)
	car.water.set_world(world)
	assert_not_null(car.water.profile, "every fixture exercises the configured water profile")
	return car


func _ground() -> void:
	add_child_autofree(ScenarioHelper.make_flat_ground(ASPHALT, Vector3.ZERO, 120.0))


func _release(car: Car) -> void:
	remove_child(car)
	car.free()


func _wait(seconds: float) -> void:
	await wait_physics_frames(ScenarioHelper.ticks(seconds))


func _contacts(car: Car) -> int:
	var count := 0
	for wheel in car.wheels:
		if wheel.in_contact:
			count += 1
	return count


func test_unbound_and_empty_world_have_identical_dry_controls_for_all_cars() -> void:
	_ground()
	for stats in STATS:
		# Different X coordinates change floating-point contact geometry. Reuse
		# exactly the same bed/spawn in sequence; water binding is the ONLY input
		# difference. Keep the original 0.0001 speed tolerance, now at every tick.
		var speeds := PackedFloat32Array()
		var gears := PackedInt32Array()
		for bound: bool in [false, true]:
			await get_tree().physics_frame  # create both cars in the same physics-frame phase
			var world: WaterWorld = WaterWorld.new() if bound else null
			var car := _spawn(stats, Vector3(0.0, 1.0, 0.0), world)
			await _wait(1.0)
			car.input.virtual_throttle = 0.7
			for tick in ScenarioHelper.ticks(2.0):
				await get_tree().physics_frame
				if bound:
					assert_almost_eq(car.forward_speed(), speeds[tick], 0.0001, "%s tick %d" % [stats.display_name, tick])
					assert_eq(car.drivetrain.gear, gears[tick])
				else:
					speeds.append(car.forward_speed())
					gears.append(car.drivetrain.gear)
				assert_eq(car.water.drag_force, Vector3.ZERO)
				assert_eq(car.water.drag_torque, Vector3.ZERO)
				assert_eq(car.water.buoyancy_force, Vector3.ZERO)
				assert_eq(car.water.buoyancy_torque, Vector3.ZERO)
				assert_eq(car.water.state.torque_scale, 1.0)
				assert_false(car.water.state.stalled)
			_release(car)
			await wait_physics_frames(1)


func test_shallow_matched_beds_have_progressive_drag_at_3_8_and_15_mps() -> void:
	_ground()
	for stats in STATS:
		for speed: float in [3.0, 8.0, 15.0]:
			var losses: Array[float] = []
			for depth: float in [0.0, 0.05, 0.15, 0.30, 0.35]:
				var car := _spawn(stats, Vector3(0.0, 1.0, 0.0))
				await _wait(1.0)
				if depth > 0.0:
					car.water.set_world(_pool(depth))
				car.linear_velocity = Vector3(0.0, 0.0, -speed)
				for wheel in car.wheels:
					wheel.spin_speed = speed / stats.wheel_radius
				await _wait(0.25)
				losses.append(speed - car.forward_speed())
				assert_gt(car.forward_speed(), 0.0, "water never reverses the entry speed")
				assert_false(car.water.state.stalled, "shallow water/spray cannot drown the intake")
				assert_lt(car.linear_velocity.y, 0.5, "a shallow entry is not a flotation jump")
				assert_true(car.linear_velocity.is_finite() and car.angular_velocity.is_finite())
				_release(car)
			gut.p("%s %.0f m/s shallow losses (dry/.05/.15/.30/.35): %s" % [stats.display_name, speed, losses])
			assert_gt(losses[1], losses[0], "first wet bay adds drag on the identical solid bed")
			assert_gt(losses[2], losses[1], "deeper wheels add more resistance")
			assert_gt(losses[3], losses[2], "deeper bay continues progressive resistance")
			assert_gt(losses[4], losses[3], "the final approved 0.35 m bay adds resistance too")


func test_fresh_flotation_then_flooding_sinks_every_car_to_the_bed() -> void:
	_ground()
	for stats in STATS:
		var car := _spawn(stats, Vector3(0.0, 2.20, 0.0), _pool(3.0))
		await _wait(1.5)
		assert_eq(_contacts(car), 0, "fresh car is ungrounded: " + stats.display_name)
		assert_gt(car.position.y, 2.20, "fresh fully wet capacity exceeds weight")
		assert_false(car.air_control.is_active, "floating never grants flight controls")
		car.input.virtual_throttle = 1.0
		car.input.virtual_steer = 1.0
		var start := car.position
		await _wait(1.0)
		assert_lt(Vector2(car.position.x - start.x, car.position.z - start.z).length(), 0.01, "spinning airborne tyres do not propel a boat")
		assert_false(car.air_control.is_active)
		car.input.virtual_throttle = 0.0
		car.input.virtual_steer = 0.0
		await _wait(16.0)
		gut.p("%s deep pool: body %.3f flood %.3f y %.3f contact %d stalled %s" % [stats.display_name,
				car.water.state.body_immersion, car.water.state.flooding, car.position.y, _contacts(car), car.water.state.stalled])
		assert_almost_eq(car.water.state.flooding, 1.0, 0.001)
		assert_gt(_contacts(car), 0, "fully flooded car sinks to the existing bed")
		assert_lt(car.position.y, 1.0)
		assert_true(car.water.state.stalled)
		assert_true(car.water.state.sinking)
		_release(car)


func test_current_drifts_ungrounded_cars_and_reverse_current_reverses_drift() -> void:
	_ground()
	for stats in STATS:
		for flow: float in [-0.75, 0.0, 0.75]:
			var car := _spawn(stats, Vector3(0.0, 2.3, 0.0), _pool(3.0, Vector3(flow, 0.0, 0.0)))
			await _wait(2.0)
			if flow == 0.0:
				assert_almost_eq(car.position.x, 0.0, 0.001)
			else:
				assert_gt(car.position.x * signf(flow), 0.001)
				assert_gt(car.linear_velocity.x * signf(flow), 0.0)
				assert_lt(absf(car.linear_velocity.x), absf(flow), "drag accelerates progressively, never snaps to current")
			assert_eq(_contacts(car), 0)
			_release(car)


func test_actual_intake_points_stall_rally_before_reserved_snorkel_and_reset_clears_everything() -> void:
	_ground()
	for stats in STATS:
		var car := _spawn(stats, Vector3(0.0, 1.0, 0.0), _pool(1.5))
		car.freeze = true
		await _wait(0.8)
		var should_stall := stats.archetype == &"rally"
		assert_eq(car.water.state.stalled, should_stall)
		assert_almost_eq(car.water.intake_world_position.y, 1.0 + stats.water_profile.intake_local_position.y, 0.000001)
		car.water.state.flooding = 0.8
		car.water.state.deep_seconds = 10.0
		var serial := car.water.reset_serial
		car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 5.0, 0.0)))
		assert_eq(car.water.reset_serial, serial + 1)
		assert_eq(car.water.state.flooding, 0.0)
		assert_false(car.water.state.stalled)
		assert_eq(car.water.drag_force, Vector3.ZERO)
		assert_eq(car.water.buoyancy_force, Vector3.ZERO)
		await _wait(0.1)
		assert_eq(car.water.state.body_immersion, 0.0)
		car.reset_to(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.0, 0.8, 0.0)))
		await _wait(0.1)
		assert_gt(car.water.state.body_immersion, 0.0, "reset into water samples the new pose on the next tick")
		assert_true(car.water.buoyancy_force.is_finite())
		_release(car)


func test_all_cars_recover_after_intake_clears_without_clearing_flooding_or_overriding_throttle() -> void:
	for stats in STATS:
		var car := _spawn(stats, Vector3(0.0, 2.0, 0.0), _pool(4.0))
		# Freeze motion, not processing: exercise the real Car/drivetrain order
		# at controlled intake heights, without resetting the controller state.
		car.freeze = true
		car.input.virtual_throttle = 1.0
		await _wait(0.65)
		assert_true(car.water.state.stalled, stats.display_name)
		assert_eq(car.drivetrain.rpm, 0.0)
		assert_eq(car.drivetrain.drive_torque, 0.0)
		car.water.state.flooding = 0.5
		car.position.y = 4.06 - stats.water_profile.intake_local_position.y
		await _wait(0.50)
		assert_true(car.water.state.stalled)
		assert_true(car.water.state.restarting)
		assert_eq(car.drivetrain.drive_torque, 0.0)
		car.position.y = 4.20 - stats.water_profile.intake_local_position.y
		await _wait(0.65)
		assert_false(car.water.state.stalled)
		assert_gt(car.drivetrain.rpm, 0.0)
		assert_gt(car.water.state.torque_scale, 0.0)
		assert_lt(car.water.state.torque_scale, 1.0)
		assert_gt(car.water.state.flooding, 0.40, "restart does not magically empty the car")
		car.input.virtual_throttle = 0.0
		await wait_physics_frames(2)
		assert_lte(car.drivetrain.drive_torque, 0.0, "restart ramp never overrides released throttle")
		car.position.y = 2.0
		await _wait(0.65)
		assert_true(car.water.state.stalled, "re-entering water can stall the restarted engine")
		assert_eq(car.drivetrain.drive_torque, 0.0)
		assert_eq(car.water.state.torque_scale, 0.0)
		_release(car)


func test_wet_body_suppresses_air_control_then_restarts_original_dry_grace() -> void:
	for stats in STATS:
		var car := _spawn(stats, Vector3(0.0, 2.0, 0.0), _pool(3.0))
		car.freeze = true
		car.input.virtual_throttle = 1.0
		await _wait(0.2)
		assert_false(car.air_control.is_active)
		assert_eq(car.air_control.airborne_time, 0.0)
		car.water.set_world(null)
		await wait_physics_frames(1)
		assert_false(car.air_control.is_active)
		await _wait(stats.airborne_grace + 0.05)
		assert_true(car.air_control.is_active)
		_release(car)


func test_fast_sideways_and_inverted_water_entries_remain_finite_at_60_and_120_hz() -> void:
	_ground()
	for hz: int in [60, 120]:
		Engine.physics_ticks_per_second = hz
		for stats in STATS:
			for roll: float in [0.0, PI]:
				var car := _spawn(stats, Vector3(0.0, 2.2, 0.0), _pool(3.0))
				car.rotation.z = roll
				car.linear_velocity = Vector3(15.0, -2.0, -8.0)
				car.angular_velocity = Vector3(1.0, 2.0, 3.0)
				await _wait(0.5)
				assert_true(car.linear_velocity.is_finite() and car.angular_velocity.is_finite())
				assert_lt(car.linear_velocity.length(), 20.0)
				assert_lt(car.angular_velocity.length(), 10.0)
				assert_false(car.air_control.is_active)
				_release(car)
