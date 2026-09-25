extends GutTest
## Remaining live-car edges; never modifies protected fixtures or car tuning.

const GROUND := preload("res://levels/test_ground/test_ground.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/offroad_4x4.tres"),
	preload("res://car/cars/rally.tres"), preload("res://car/cars/rally_tuned.tres")]
var _rate := 120


func before_each() -> void:
	SaveSandbox.enter()
	_rate = Engine.physics_ticks_per_second


func after_each() -> void:
	Engine.physics_ticks_per_second = _rate
	get_tree().paused = false
	# Allow the audio thread's next mix block after the last stopped car. This
	# is wall time, unlike the accelerated physics clock used by this suite.
	var audio_deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_deadline:
		await get_tree().process_frame
	SaveSandbox.leave()


func _level(definition: CarDef, mode: int) -> Node3D:
	var level: Node3D = GROUND.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = definition
	add_child(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(level.water_waves.set_mode(mode), level.water_waves.error)
	return level


func _release(level: Node3D) -> void:
	remove_child(level)
	level.free()


func test_slow_and_fast_live_entries_remain_bounded_for_each_car_at_both_rates() -> void:
	for hz: int in [60, 120]:
		Engine.physics_ticks_per_second = hz
		for definition: CarDef in CARS:
			for speed: float in [3.0, 15.0]:
				var level := _level(definition, WaterWaveTestGround.Mode.FULL)
				var rig: DrivingRig = level.rig
				var waves: WaterWaveTestGround = level.water_waves
				var start := Vector3(105.0, WaterCourse.pool_floor_height(0.0, 29.0) + 1.0, 59.0)
				rig.place_car(Transform3D(Basis(Vector3.UP, PI), start))
				await wait_physics_frames(hz)
				rig.car.linear_velocity = Vector3(0.0, 0.0, speed)
				rig.car.input.virtual_throttle = 1.0
				for wheel: Wheel in rig.car.wheels:
					wheel.spin_speed = speed / rig.car.stats.wheel_radius
				for tick in hz * 5:
					await get_tree().physics_frame
					assert_true(rig.car.linear_velocity.is_finite())
					assert_true(rig.car.angular_velocity.is_finite())
					assert_lte(waves.runtime.field.active_count(), 16)
					for sample: WaterSample in rig.car.water.body_samples:
						assert_lte(absf(sample.surface_y - sample.rest_surface_y), 0.12)
				assert_eq(waves.emitter.source.entries, 1,
					"%s %d Hz initial %.0f m/s: one entry, not repeated by waves" % [definition.id, hz, speed])
				assert_gt(waves.emitter.source.wakes, 0)
				_release(level)
				await get_tree().process_frame


func test_live_current_drift_remains_finite_through_flooding_for_all_cars() -> void:
	for hz: int in [60, 120]:
		Engine.physics_ticks_per_second = hz
		for definition: CarDef in CARS:
			var level := _level(definition, WaterWaveTestGround.Mode.FULL)
			var rig: DrivingRig = level.rig
			rig.place_car(Transform3D(Basis.IDENTITY, Vector3(155.0, 2.5, 126.0)))
			for tick in hz * 10:
				await get_tree().physics_frame
				assert_true(rig.car.global_position.is_finite())
				assert_true(rig.car.linear_velocity.is_finite())
				assert_lte(level.water_waves.runtime.field.active_count(), 16)
			assert_gt(rig.car.global_position.x, 155.05, "current still drifts a live car")
			assert_eq(level.water_waves.emitter.source.entries, 0, "a wet spawn is not an entry")
			assert_gt(rig.car.water.state.flooding, 0.0)
			_release(level)
			await get_tree().process_frame


func test_fixed_stopped_car_does_not_feed_its_own_waves_after_packets_expire() -> void:
	for hz: int in [60, 120]:
		Engine.physics_ticks_per_second = hz
		var level := _level(CARS[0], WaterWaveTestGround.Mode.CAR_WAVES)
		var rig: DrivingRig = level.rig
		var waves: WaterWaveTestGround = level.water_waves
		rig.car.freeze = true
		rig.place_car(Transform3D(Basis.IDENTITY, Vector3(105.0, 2.5, 126.0)))
		await wait_physics_frames(2)
		waves.runtime.field.queue_packet(WaterWaveField.Kind.ENTRY, &"test_calm", Vector2(0.0, 96.0), Vector2.ZERO, 0.08)
		await wait_physics_frames(hz * 5)
		assert_eq(waves.runtime.field.active_count(), 0)
		assert_eq(waves.emitter.source.entries, 0)
		assert_eq(waves.emitter.source.wakes, 0)
		for sample: WaterSample in rig.car.water.body_samples:
			assert_almost_eq(sample.surface_y, sample.rest_surface_y, 0.001)
		_release(level)
		await get_tree().process_frame
