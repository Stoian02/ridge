extends GutTest
## Real start-to-finish crossings, followed by lifecycle checks in a save sandbox.

const LEVEL := preload("res://levels/coastal_highway/coastal_highway.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/rally.tres"),
	preload("res://car/cars/rally_tuned.tres"), preload("res://car/cars/offroad_4x4.tres")]


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func test_all_cars_finish_via_every_real_gate_without_reset_or_progress_writes() -> void:
	for car_def: CarDef in CARS:
		var level: RunLevel = LEVEL.instantiate()
		(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
		add_child(level)
		var before := GameState.progress.to_dictionary().duplicate(true)
		var result := await CoastalRouteProbe.new().attempt(level)
		assert_true(result.reached, String(car_def.id))
		assert_true(result.upright)
		assert_eq(result.resets, 0)
		assert_eq(result.last_gate, result.expected_last_gate)
		assert_eq(result.gates, range(1, result.expected_last_gate))
		assert_eq(result.splits.size(), result.expected_last_gate - 1)
		assert_gt(result.air_seconds, 0.2)
		assert_gte(result.touchdown, level.trail.trail.road_gaps[0].landing_start)
		assert_lt(result.start_speed, 0.5)
		assert_almost_eq(result.start_distance, 10.0, 0.2)
		assert_true(level.results.is_showing())
		assert_true(level.rig.car.input.locked)
		assert_eq(GameState.progress.to_dictionary(), before, "uncatalogued finish never saves")
		assert_true(level.trail.water_world.bodies.is_empty())
		assert_eq(level.trail.water_world.wave_binding_count(), 0)
		level.run.restart()
		assert_eq(level.tracker.last_passed, 0)
		assert_false(level.results.is_showing())
		await wait_physics_frames(370)
		level.rig.car.input.reset_requested.emit()
		assert_almost_eq(level.trail.sampler.closest_distance(level.rig.car.position), 10.0, 0.1)
		level.rig.car.position.y = level.resets.kill_height - 2.0
		await wait_physics_frames(2)
		assert_almost_eq(level.trail.sampler.closest_distance(level.rig.car.position), 10.0, 0.1)
		level.pause_menu.open()
		assert_true(get_tree().paused)
		level.pause_menu.close()
		assert_false(get_tree().paused)
		level._change_car()
		assert_eq(GameState.pending_scene, level.scene_file_path)
		assert_eq(SaveSandbox.requested_scenes[-1], GameState.CAR_SELECT)
		level.pause_menu.main_menu_pressed.emit()
		assert_eq(SaveSandbox.requested_scenes[-1], GameState.MAIN_MENU)
		var audio: WeakRef = weakref(level.rig.audio)
		level.queue_free()
		await wait_process_frames(3)
		assert_null(audio.get_ref())
