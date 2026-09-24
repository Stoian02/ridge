extends GutTest

const GROUND := preload("res://levels/test_ground/test_ground.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/offroad_4x4.tres"),
	preload("res://car/cars/rally.tres"), preload("res://car/cars/rally_tuned.tres")]


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	get_tree().paused = false
	SaveSandbox.leave()


func test_modes_reset_pause_rebuild_and_exit_are_safe_for_each_car() -> void:
	for car_def in CARS:
		var level: Node3D = GROUND.instantiate()
		var rig: DrivingRig = level.get_node("DrivingRig")
		rig.car_override = car_def
		add_child(level)
		rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
		var waves: WaterWaveTestGround = level.water_waves
		var world: WaterWorld = level.water_course.water_world
		assert_eq(waves.mode, WaterWaveTestGround.Mode.OFF)
		assert_null(waves.runtime, "Off does not prepare/load optional resources")
		assert_eq(world.wave_binding_count(), 0)
		assert_true(waves.set_mode(WaterWaveTestGround.Mode.FULL), waves.error)
		assert_eq(world.wave_binding_count(), 6)
		assert_eq(rig.car.global_transform, level._spawn)
		assert_false(level.water_course.get_node("CalmWater").visible)
		assert_eq(waves._tops.size(), 6)
		var runtime := waves.runtime
		rig.place_car(Transform3D(Basis.IDENTITY, Vector3(105.0, 2.5, 126.0)))
		await wait_physics_frames(20)
		assert_eq(waves.emitter.source.entries, 0, "reset into water seeds without entry")
		assert_gt(rig.car.water.state.body_immersion, 0.0)
		var clock := runtime.field.clock_seconds
		level.pause_menu.open()
		level.pause_menu.interaction_locked = true
		level.pause_menu.handle_back()
		assert_true(level.pause_menu.is_open(), "Escape cannot unpause during covered preparation")
		level.pause_menu.interaction_locked = false
		for frame in 8:
			await get_tree().process_frame
		assert_eq(runtime.field.clock_seconds, clock)
		level.pause_menu.close()
		level._on_reset_requested()
		assert_eq(runtime.field.active_count(), 0)
		assert_eq(rig.car.water.state.flooding, 0.0)
		assert_true(waves.set_mode(WaterWaveTestGround.Mode.CAR_WAVES))
		assert_same(waves.runtime, runtime, "mode changes retain prepared mesh/runtime")
		for view in runtime.views:
			assert_eq(view.snapshot.ambient[0].z, 0.0)
		assert_true(waves.set_mode(WaterWaveTestGround.Mode.OFF))
		assert_eq(world.wave_binding_count(), 0)
		assert_true(level.water_course.get_node("CalmWater").visible)
		assert_false(runtime.is_physics_processing())
		assert_false(waves.emitter.is_physics_processing())
		assert_true(waves.set_mode(WaterWaveTestGround.Mode.FULL))
		level.water_course.build()
		await wait_physics_frames(2)
		assert_eq(waves.mode, WaterWaveTestGround.Mode.OFF)
		assert_eq(world.wave_binding_count(), 0)
		assert_true(level.water_course.get_node("CalmWater").visible)
		assert_true(waves.set_mode(WaterWaveTestGround.Mode.FULL), waves.error)
		remove_child(level)
		level.free()
		assert_true(world.bodies.is_empty())
		assert_eq(world.wave_binding_count(), 0)
		await get_tree().process_frame
