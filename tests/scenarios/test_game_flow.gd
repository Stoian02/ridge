extends GutTest
## Part B1's flow in running scenes: pausing, results after the finish, Free Drive's
## pause menu, and keeping the player's real save file out of tests.

const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _seconds(seconds: float) -> void:
	await wait_physics_frames(ScenarioHelper.ticks(seconds))


func _straight_level() -> RunLevel:
	return RunLevelBuilder.straight(self, 400.0, PackedFloat32Array([150.0]))


func _drive_to_finish(level: RunLevel) -> void:
	level.rig.car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(60.0):
		await get_tree().physics_frame
		if level.tracker.is_finished():
			return


func _pause_button(menu: PauseMenu, text: String) -> Button:
	return menu.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == text)[0]


func test_pausing_freezes_the_run_and_lets_go_of_the_gas() -> void:
	var level := _straight_level()
	level.rig.car.input.virtual_throttle = 1.0
	await _seconds(5.0)
	level.rig.pause_requested.emit()
	assert_true(get_tree().paused)
	assert_true(level.pause_menu.is_open())
	assert_almost_eq(level.rig.car.input.virtual_throttle, 0.0, 0.0001, "the gas is released")
	var elapsed := level.run.clock.elapsed
	var position := level.rig.car.global_position
	await _seconds(2.0)
	assert_almost_eq(level.run.clock.elapsed, elapsed, 0.0001, "the clock is frozen")
	assert_lt(level.rig.car.global_position.distance_to(position), 0.01, "the car is frozen")
	_pause_button(level.pause_menu, "Resume").pressed.emit()
	assert_false(get_tree().paused)
	await _seconds(0.5)
	assert_gt(level.run.clock.elapsed, elapsed, "the clock runs again")


func test_the_back_gesture_opens_the_pause_menu_during_a_run() -> void:
	var level := _straight_level()
	await _seconds(1.0)
	level.pause_menu.handle_back()
	assert_true(level.pause_menu.is_open())
	level.pause_menu.handle_back()
	assert_false(level.pause_menu.is_open())


func test_results_appear_a_moment_after_the_finish_and_block_pausing() -> void:
	var level := _straight_level()
	await _drive_to_finish(level)
	assert_true(level.tracker.is_finished())
	assert_true(level.rig.car.input.locked, "the pedals lock at the finish")
	assert_false(level.results.is_showing(), "not straight away")
	var ticks := 0
	while not level.results.is_showing() and ticks < ScenarioHelper.ticks(3.0):
		await get_tree().physics_frame
		ticks += 1
	assert_true(level.results.is_showing())
	assert_almost_eq(ticks / float(Engine.physics_ticks_per_second), RunLevel.RESULTS_DELAY, 0.1)
	level.rig.pause_requested.emit()
	assert_false(get_tree().paused, "no pausing over the results")
	level.pause_menu.handle_back()
	assert_eq(SaveSandbox.requested_scenes, [SaveSandbox.game_state().LEVEL_SELECT])


func test_a_restart_during_the_delay_does_not_show_old_results() -> void:
	var level := _straight_level()
	await _drive_to_finish(level)
	level.run.restart()
	await _seconds(RunLevel.RESULTS_DELAY + 0.5)
	assert_false(level.results.is_showing())
	assert_eq(level.run.clock.stage, RunClock.Stage.COUNTDOWN)


func test_free_drive_pause_menu_has_no_restart_and_leads_to_the_main_menu() -> void:
	var ground: Node3D = TEST_GROUND.instantiate()
	add_child_autofree(ground)
	await _seconds(0.2)
	var rig: DrivingRig = ground.get_node("DrivingRig")
	var menu: PauseMenu = ground.get_node("PauseMenu")
	assert_false(menu.show_restart)
	rig.pause_requested.emit()
	assert_true(get_tree().paused)
	_pause_button(menu, "Main menu").pressed.emit()
	assert_false(get_tree().paused)
	assert_eq(SaveSandbox.requested_scenes, [SaveSandbox.game_state().MAIN_MENU])


func test_the_players_real_save_file_is_never_touched() -> void:
	var real: String = SaveSandbox.game_state().DEFAULT_SAVE_PATH
	var existed := FileAccess.file_exists(real)
	var content := FileAccess.get_file_as_string(real) if existed else ""
	var modified := FileAccess.get_modified_time(real) if existed else 0
	var state := SaveSandbox.game_state()
	state.record_finish(state.catalog.levels[0], 99.0, {1: 20.0})
	state.set_steer_mode(Progress.STEER_BUTTONS)
	assert_true(FileAccess.file_exists(SaveSandbox.PATH), "the sandbox file was written")
	assert_eq(FileAccess.file_exists(real), existed)
	if existed:
		assert_eq(FileAccess.get_file_as_string(real), content)
		assert_eq(FileAccess.get_modified_time(real), modified)
