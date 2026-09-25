extends GutTest
## Same lifecycle driver as the opt-in phone check; headless is not a GPU gate.


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	get_tree().paused = false
	var audio_deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_deadline:
		await get_tree().process_frame
	SaveSandbox.leave()


func test_phone_lifecycle_driver_checks_all_cars_without_saving() -> void:
	var output := "user://wave_lifecycle_test"
	DirAccess.make_dir_recursive_absolute(output)
	var audit: Node = load("res://debug/water_wave_lifecycle_check.gd").new()
	add_child(audit)
	var passed: bool = await audit.run(output, 1)
	assert_true(passed)
	for check: Dictionary in audit.checks:
		assert_true(bool(check.passed), str(check.case) + ": " + str(check.check))
	assert_eq(audit.rounds.size(), 3)
	remove_child(audit)
	audit.free()


func test_all_timed_levels_keep_waves_unbound_and_controls_absent() -> void:
	for id: String in ["rally_road", "muddy_valley", "frozen_pass", "rock_canyon"]:
		var level: RunLevel = load("res://levels/%s/%s.tscn" % [id, id]).instantiate()
		(level.get_node("DrivingRig") as DrivingRig).car_override = load("res://car/cars/offroad_4x4.tres")
		add_child(level)
		level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
		await wait_physics_frames(3)
		assert_eq(level.trail.water_world.wave_binding_count(), 0, id)
		assert_null(level.pause_menu.level_options, id + " has no Test Ground wave controls")
		for child: Node in level.find_children("*", "", true, false):
			assert_false(child is WaterWaveTestGround or child is WaterWaveRuntime or child is WaterWaveEmitter,
				id + " does not own a live wave node")
		remove_child(level)
		level.free()
		await get_tree().process_frame


func test_phone_exit_fixture_recovers_and_leaves_water_for_each_car_and_mode() -> void:
	for car_id: String in ["offroad_4x4", "rally", "rally_tuned"]:
		for mode in 3:
			var level: Node3D = load("res://levels/test_ground/test_ground.tscn").instantiate()
			(level.get_node("DrivingRig") as DrivingRig).car_override = GameState.car_catalog.find_by_id(StringName(car_id))
			add_child(level)
			var rig: DrivingRig = level.rig
			rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
			assert_true(level.water_waves.set_mode(mode))
			# Do not add the acceptance runner to the tree: its _ready is the
			# rendered batch launcher. Exercise only its explicit live fixture.
			var fixture: Node = load("res://debug/water_wave_acceptance.gd").new()
			fixture.rig = rig
			fixture._camera = Camera3D.new()
			level.add_child(fixture._camera)
			fixture.phase = Engine.physics_ticks_per_second * 72
			fixture._live()
			assert_true(rig.car.water.state.stalled, "declared recovery precondition")
			for tick in Engine.physics_ticks_per_second * 5:
				await get_tree().physics_frame
				fixture.phase += 1
				fixture._live()
			assert_false(rig.car.water.state.stalled, car_id + " recovers using the ordinary intake-clear timer")
			assert_lt(rig.car.global_position.z, 58.0, car_id + " actually exits the wet ramp")
			assert_almost_eq(rig.car.water.state.body_immersion, 0.0, 0.000001)
			fixture.free()
			remove_child(level)
			level.free()
			await get_tree().process_frame
