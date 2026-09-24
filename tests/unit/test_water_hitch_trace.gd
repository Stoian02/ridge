extends GutTest


func test_trace_flag_accepts_both_android_json_numbers_and_desktop_strings() -> void:
	var runner: GDScript = load("res://debug/water_acceptance.gd")
	assert_true(runner.wants_hitch_trace(JSON.parse_string('{"trace":1}')))
	assert_true(runner.wants_hitch_trace({"trace": "1"}))
	assert_false(runner.wants_hitch_trace({}))
	assert_false(runner.wants_hitch_trace({"trace": 0.0}))


func test_bounded_trace_records_completed_ticks_and_turns_instrumentation_off() -> void:
	var level: Node3D = load("res://levels/test_ground/test_ground.tscn").instantiate()
	add_child_autofree(level)
	var rig: DrivingRig = level.get_node("DrivingRig")
	var trace := WaterHitchTrace.new()
	add_child_autofree(trace)
	assert_gt(trace.process_physics_priority, rig.car.process_physics_priority)
	assert_gt(trace.process_priority, rig.audio.process_priority)
	trace.begin(rig, 32)
	await wait_physics_frames(8)
	trace.stop()
	var count := trace.tick_count
	await wait_physics_frames(2)
	assert_eq(trace.tick_count, count, "export/screenshot waits cannot become apparent hitches")
	assert_gt(count, 0)
	assert_false(rig.car.water.trace_enabled)
	assert_false(rig.effects.trace_enabled)
	assert_false(rig.audio.trace_enabled)
	assert_false(rig.water_status.trace_enabled)
	for index in range(1, count):
		assert_eq(trace._ticks[index * WaterHitchTrace.TW], trace._ticks[(index - 1) * WaterHitchTrace.TW] + 1.0)
	assert_eq(trace._ticks.size(), 32 * WaterHitchTrace.TW)
	assert_false(trace.overflow)
	var result := trace.finish("user://water_hitch_test")
	assert_eq(result.ticks, count)
	assert_null(trace.rig)
	DirAccess.remove_absolute("user://water_hitch_test_hitch_ticks.csv")
	DirAccess.remove_absolute("user://water_hitch_test_hitch_frames.csv")
