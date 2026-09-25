extends GutTest


func test_recorder_groups_complete_frames_and_bounds_water_feedback_by_whole_callbacks() -> void:
	SaveSandbox.enter()
	var level: Node3D = load("res://levels/test_ground/test_ground.tscn").instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = load("res://car/cars/offroad_4x4.tres")
	add_child(level)
	var rig: DrivingRig = level.rig
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	rig.car.freeze = true
	assert_true(level.water_waves.set_mode(WaterWaveTestGround.Mode.FULL))
	rig.place_car(Transform3D(Basis.IDENTITY, Vector3(105.0, 2.5, 126.0)))
	var recorder := WaterTotalMeasurement.new()
	add_child(recorder)
	recorder.begin(rig, level.water_waves)
	await wait_physics_frames(40)
	var result := recorder.finish("user://total_measurement_test")
	assert_gt(result.frames, 0)
	assert_false(result.gpu_valid, "headless renderer is never a GPU acceptance pass")
	var count := 0
	var previous_end := 0.0
	for frame: PackedFloat64Array in recorder.frames:
		assert_gt(frame[20], previous_end, "trace timestamps advance")
		if previous_end > 0.0:
			assert_eq(frame[20] - previous_end, frame[1], "timestamps preserve raw elapsed intervals")
		previous_end = frame[20]
		assert_lte(frame[7], frame[17], "wet/shared effects are a subset of the complete callback")
		assert_lte(frame[8], frame[18], "water/shared tyre audio is a subset of the complete callback")
		assert_lte(frame[11], frame[19])
		var total := 0.0
		for index in range(3, 11):
			total += frame[index]
		assert_eq(frame[11], total, "nested queries are not added twice")
		var associated := 0
		for tick: PackedFloat64Array in recorder.ticks:
			associated += int(tick[0] == frame[0])
		assert_eq(float(associated), frame[2])
		count += associated
	assert_eq(count, recorder.ticks.size(), "no orphan/partial-frame ticks")
	recorder.free()
	level.free()
	# The audio mixer releases stopped playbacks on its own wall-clock thread.
	# Fixed-FPS headless tests can otherwise quit before its next mix block.
	var audio_deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_deadline:
		await get_tree().process_frame
	SaveSandbox.leave()
