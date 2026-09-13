extends GutTest
## The countdown, clock, checkpoints and resets on a small straight trail.

var level: RunLevel


func before_each() -> void:
	level = RunLevelBuilder.straight(self, 400.0, PackedFloat32Array([150.0]))


func _seconds(seconds: float) -> void:
	await wait_physics_frames(ScenarioHelper.ticks(seconds))


func test_the_countdown_holds_the_car_then_releases_it() -> void:
	level.rig.car.input.virtual_throttle = 1.0
	var start := level.rig.car.global_position
	await _seconds(2.0)
	assert_eq(level.run.clock.stage, RunClock.Stage.COUNTDOWN)
	var moved := Vector2(level.rig.car.global_position.x - start.x, level.rig.car.global_position.z - start.z).length()
	assert_lt(moved, 0.2, "throttle does nothing during the countdown (settling onto the springs is fine)")
	await _seconds(3.0)
	assert_eq(level.run.clock.stage, RunClock.Stage.RUNNING)
	assert_gt(level.rig.car.global_position.distance_to(start), 2.0, "the car drives after GO")


func test_driving_through_every_gate_finishes_the_run() -> void:
	watch_signals(level.run)
	level.rig.car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(60.0):
		await get_tree().physics_frame
		if level.tracker.is_finished():
			break
	assert_signal_emit_count(level.run, "checkpoint_reached", 1)
	assert_signal_emitted(level.run, "run_finished")
	assert_eq(level.run.clock.stage, RunClock.Stage.FINISHED)
	gut.p("400 m straight finished in %s" % RunHud.format_time(level.run.clock.elapsed))
	assert_between(level.run.clock.elapsed, 10.0, 40.0)
	assert_true(level.hud.is_finish_visible())


func test_reset_button_returns_to_the_last_checkpoint_with_the_clock_running() -> void:
	level.rig.car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(40.0):
		await get_tree().physics_frame
		if level.tracker.last_passed == 1:
			break
	await _seconds(1.0)
	var before := level.run.clock.elapsed
	level.rig.car.input.virtual_throttle = 0.0
	level.rig.car.input.request_reset()
	assert_almost_eq(level.rig.car.global_position.distance_to(level.tracker.reset_transform().origin), 0.0, 0.01)
	await _seconds(0.5)
	assert_gt(level.run.clock.elapsed, before, "the clock keeps running through a reset")


func test_a_flipped_car_is_reset_after_two_seconds() -> void:
	await _seconds(3.5)
	watch_signals(level.resets)
	var upside_down := level.tracker.reset_transform()
	upside_down.basis = upside_down.basis.rotated(upside_down.basis.z, PI)
	level.rig.car.reset_to(upside_down)
	await _seconds(1.5)
	assert_signal_not_emitted(level.resets, "car_reset")
	await _seconds(1.5)
	assert_signal_emitted_with_parameters(level.resets, "car_reset", [&"flipped"])
	assert_true(ScenarioHelper.is_upright(level.rig.car))


func test_falling_off_the_map_resets() -> void:
	await _seconds(3.5)
	watch_signals(level.resets)
	level.rig.car.reset_to(Transform3D(Basis(), Vector3(0.0, level.trail.kill_height() - 5.0, -50.0)))
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(level.resets, "car_reset", [&"fell"])
	assert_gt(level.rig.car.global_position.y, level.trail.kill_height())


func test_reset_during_the_countdown_restarts_it() -> void:
	await _seconds(2.0)
	level.rig.car.input.request_reset()
	assert_eq(level.run.clock.stage, RunClock.Stage.COUNTDOWN)
	assert_almost_eq(level.run.clock.countdown_remaining, RunClock.COUNTDOWN_SECONDS, 0.01)


func test_restart_after_the_finish_starts_a_new_countdown() -> void:
	level.rig.car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(60.0):
		await get_tree().physics_frame
		if level.tracker.is_finished():
			break
	level.run.restart()
	assert_eq(level.run.clock.stage, RunClock.Stage.COUNTDOWN)
	assert_false(level.hud.is_finish_visible())
	assert_eq(level.tracker.last_passed, 0)
	assert_gt(level.run.clock.session_best_time, 0.0, "the session best survives a restart")
