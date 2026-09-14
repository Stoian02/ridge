extends GutTest
## Rally Road as a whole: it builds, a scripted driver can complete it, and the
## finish is saved (to the sandbox) and shown on the results screen.

const RALLY_ROAD := preload("res://levels/rally_road/rally_road.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _load() -> RunLevel:
	var level: RunLevel = RALLY_ROAD.instantiate()
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func test_rally_road_builds_with_its_gates_and_layout() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var climb := sampler.position(sampler.length).y - sampler.position(0.0).y
	gut.p("Rally Road: %.0f m long, climbs %.0f m, built in %.2f s (%d x %d terrain chunks, %d pines, %d rocks, %d posts)" % [
		sampler.length, climb, level.trail.build_seconds,
		level.trail.field.chunk_count().x, level.trail.field.chunk_count().y,
		level.trail.scatter_builder.pine_count, level.trail.scatter_builder.rock_count, level.trail.scatter_builder.post_count])
	assert_between(sampler.length, 1350.0, 1650.0, "about 1.5 km")
	assert_eq(level.trail.checkpoints.reset_transforms.size(), 6, "start, 4 checkpoints, finish")
	assert_lt(level.trail.build_seconds, 3.0, "desktop build time")
	assert_not_null(level.level, "Rally Road finds its catalog entry")


func test_a_saved_best_run_is_the_split_reference() -> void:
	var state := SaveSandbox.game_state()
	state.record_finish(state.catalog.levels[0], 80.0, {1: 16.0, 2: 28.0})
	var level := _load()
	assert_almost_eq(level.run.clock.best_time, 80.0, 0.0001)
	assert_eq(level.run.clock.best_splits, {1: 16.0, 2: 28.0})


func test_scripted_driver_completes_rally_road() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler)
	watch_signals(level.resets)
	watch_signals(level.run)
	var ticks := 0
	var lost_contact := 0
	var jumps := level.trail.trail.jumps
	while not level.tracker.is_finished() and ticks < ScenarioHelper.ticks(200.0):
		driver.drive()
		await get_tree().physics_frame
		ticks += 1
		# Skip the countdown (the car settles onto its springs) and real air time.
		if level.run.clock.stage != RunClock.Stage.RUNNING or car.air_control.is_active:
			continue
		var distance := level.trail.sampler.closest_distance(car.global_position)
		var near_jump := jumps.any(func(j: Vector3) -> bool: return absf(distance - j.x) < 25.0)
		if not near_jump:
			for wheel in car.wheels:
				if not wheel.in_contact:
					lost_contact += 1
	var time := level.run.clock.elapsed
	gut.p("scripted driver: finished %s after %s, %d checkpoints, %d wheel-ticks without contact away from jumps" % [
		level.tracker.is_finished(), RunHud.format_time(time),
		get_signal_emit_count(level.run, "checkpoint_reached"), lost_contact])
	assert_true(level.tracker.is_finished(), "reached the finish")
	assert_signal_not_emitted(level.resets, "car_reset")
	assert_signal_emit_count(level.run, "checkpoint_reached", 4)
	assert_between(time, 60.0, 150.0)
	assert_lt(lost_contact, 24, "no seams or potholes throw the wheels off the ground")

	var wait := 0
	while not level.results.is_showing() and wait < ScenarioHelper.ticks(3.0):
		await get_tree().physics_frame
		wait += 1
	assert_true(level.results.is_showing(), "results appear after the finish")
	assert_eq(level.results.stars.earned, Stars.for_time(time, level.level))
	var saved: Dictionary = SaveSystem.read(SaveSandbox.PATH)["levels"]["rally_road"]
	assert_almost_eq(float(saved["best_time"]), time, 0.001, "the finish was saved")
	assert_eq(saved["best_splits"].size(), 4, "with its four checkpoint splits")
	level.results.retry_pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [level.scene_file_path], "Retry reloads Rally Road")
	assert_true(level.results._next.visible, "finishing Rally Road unlocks the next level")
	level.results.next_pressed.emit()
	assert_eq(SaveSandbox.requested_scenes[-1], SaveSandbox.game_state().CAR_SELECT, "Next level opens car select")
	assert_eq(SaveSandbox.game_state().pending_scene, "res://levels/muddy_valley/muddy_valley.tscn", "for Muddy Valley")


func test_the_road_carries_on_past_the_finish() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var finish := level.trail.checkpoints.gate_distances[-1]
	await TrailScenarios.place_on_road(level, finish - 150.0)
	await TrailScenarios.full_throttle_until(level, 30.0,
			func() -> bool: return sampler.closest_distance(car.global_position) >= finish)
	var speed := car.forward_speed()
	await TrailScenarios.brake_to_stop(level)
	var stopped_at := sampler.closest_distance(car.global_position)
	gut.p("crossed the finish at %.0f km/h and stopped %.0f m past it (road ends %.0f m past it)" % [
		speed * 3.6, stopped_at - finish, sampler.length - finish])
	assert_lt(stopped_at, sampler.length - 5.0, "stops on the run-off")
	assert_lt(absf(sampler.lateral_offset(car.global_position)), level.trail.trail.half_total_width())
