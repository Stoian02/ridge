extends GutTest

var tracker: CheckpointTracker


func before_each() -> void:
	tracker = CheckpointTracker.new()
	add_child_autofree(tracker)
	var transforms: Array[Transform3D] = []
	for i in 4:  # start, checkpoint 1, checkpoint 2, finish
		transforms.append(Transform3D(Basis(), Vector3(0.0, 0.0, -100.0 * i)))
	tracker.setup(transforms)


func test_starts_at_the_start_gate() -> void:
	assert_eq(tracker.last_passed, 0)
	assert_eq(tracker.next_index, 1)
	assert_eq(tracker.reset_transform().origin, Vector3.ZERO)


func test_gates_in_order_count() -> void:
	watch_signals(tracker)
	tracker.enter_gate(1)
	assert_signal_emitted_with_parameters(tracker, "checkpoint_passed", [1])
	assert_eq(tracker.reset_transform().origin, Vector3(0.0, 0.0, -100.0))


func test_skipping_a_gate_does_nothing() -> void:
	watch_signals(tracker)
	tracker.enter_gate(2)
	assert_signal_not_emitted(tracker, "checkpoint_passed")
	assert_eq(tracker.last_passed, 0)


func test_passing_the_same_gate_twice_counts_once() -> void:
	watch_signals(tracker)
	tracker.enter_gate(1)
	tracker.enter_gate(1)
	assert_signal_emit_count(tracker, "checkpoint_passed", 1)


func test_the_last_gate_finishes() -> void:
	watch_signals(tracker)
	for i in [1, 2, 3]:
		tracker.enter_gate(i)
	assert_signal_emitted(tracker, "finished")
	assert_signal_emit_count(tracker, "checkpoint_passed", 2)
	assert_true(tracker.is_finished())
	assert_eq(tracker.reset_transform().origin, Vector3(0.0, 0.0, -300.0))


func test_gates_after_the_finish_are_ignored() -> void:
	for i in [1, 2, 3]:
		tracker.enter_gate(i)
	watch_signals(tracker)
	tracker.enter_gate(0)
	tracker.enter_gate(1)
	assert_signal_not_emitted(tracker, "checkpoint_passed")
	assert_signal_not_emitted(tracker, "finished")


func test_restart_returns_to_the_start() -> void:
	tracker.enter_gate(1)
	tracker.enter_gate(2)
	tracker.restart()
	assert_eq(tracker.last_passed, 0)
	assert_eq(tracker.next_index, 1)
	assert_false(tracker.is_finished())
