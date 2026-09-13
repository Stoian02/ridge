extends GutTest
## Rally Road as a whole: it builds, and a scripted driver can complete it.

const RALLY_ROAD := preload("res://levels/rally_road/rally_road.tscn")


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
	gut.p("scripted driver: finished %s after %s, %d checkpoints, %d wheel-ticks without contact away from jumps" % [
		level.tracker.is_finished(), RunHud.format_time(level.run.clock.elapsed),
		get_signal_emit_count(level.run, "checkpoint_reached"), lost_contact])
	assert_true(level.tracker.is_finished(), "reached the finish")
	assert_signal_not_emitted(level.resets, "car_reset")
	assert_signal_emit_count(level.run, "checkpoint_reached", 4)
	assert_between(level.run.clock.elapsed, 60.0, 150.0)
	assert_lt(lost_contact, 24, "no seams or potholes throw the wheels off the ground")
