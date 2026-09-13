extends GutTest

var clock: RunClock


func before_each() -> void:
	clock = RunClock.new()


func _run_to_go() -> void:
	clock.start_countdown()
	clock.tick(RunClock.COUNTDOWN_SECONDS + 0.01)


func test_starts_ready() -> void:
	assert_eq(clock.stage, RunClock.Stage.READY)


func test_countdown_lasts_three_seconds_then_reports_go() -> void:
	clock.start_countdown()
	assert_false(clock.tick(2.9), "still counting down at 2.9 s")
	assert_eq(clock.stage, RunClock.Stage.COUNTDOWN)
	assert_true(clock.tick(0.2), "GO on the tick that passes 3 s")
	assert_eq(clock.stage, RunClock.Stage.RUNNING)


func test_time_only_runs_after_go() -> void:
	clock.start_countdown()
	clock.tick(2.0)
	assert_almost_eq(clock.elapsed, 0.0, 0.0001)
	clock.tick(1.5)
	clock.tick(0.5)
	assert_almost_eq(clock.elapsed, 0.5, 0.0001)


func test_checkpoint_records_a_split() -> void:
	_run_to_go()
	clock.tick(12.5)
	clock.pass_checkpoint(1)
	assert_almost_eq(clock.splits[1], 12.5, 0.0001)


func test_first_finish_sets_the_session_best() -> void:
	_run_to_go()
	clock.tick(90.0)
	clock.finish()
	assert_eq(clock.stage, RunClock.Stage.FINISHED)
	assert_almost_eq(clock.session_best_time, 90.0, 0.0001)


func test_a_slower_run_keeps_the_session_best() -> void:
	_run_to_go()
	clock.tick(90.0)
	clock.finish()
	clock.restart()
	_run_to_go()
	clock.tick(95.0)
	clock.finish()
	assert_almost_eq(clock.session_best_time, 90.0, 0.0001)


func test_split_delta_compares_with_the_session_best_run() -> void:
	_run_to_go()
	clock.tick(20.0)
	clock.pass_checkpoint(1)
	assert_true(is_nan(clock.split_delta(1)), "nothing to compare on the first run")
	clock.tick(70.0)
	clock.finish()
	clock.restart()
	_run_to_go()
	clock.tick(18.5)
	clock.pass_checkpoint(1)
	assert_almost_eq(clock.split_delta(1), -1.5, 0.0001)


func test_finish_is_ignored_unless_running() -> void:
	clock.finish()
	assert_eq(clock.stage, RunClock.Stage.READY)
	assert_almost_eq(clock.session_best_time, -1.0, 0.0001)


func test_restart_clears_the_run_but_keeps_the_best() -> void:
	_run_to_go()
	clock.tick(80.0)
	clock.finish()
	clock.restart()
	assert_eq(clock.stage, RunClock.Stage.READY)
	assert_almost_eq(clock.elapsed, 0.0, 0.0001)
	assert_true(clock.splits.is_empty())
	assert_almost_eq(clock.session_best_time, 80.0, 0.0001)
