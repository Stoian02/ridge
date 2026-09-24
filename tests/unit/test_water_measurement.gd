extends GutTest
## Test the measurement math separately from the physics it observes.


func test_nearest_rank_percentile_keeps_outliers_and_does_not_mutate_input() -> void:
	var samples := PackedFloat64Array([1000.0, 20.0, 10.0, 30.0])
	assert_eq(WaterMeasurement.percentile(samples, 0.95), 1000.0)
	assert_eq(WaterMeasurement.percentile(samples, 1.0), 1000.0)
	assert_eq(WaterMeasurement.percentile(samples, 0.5), 20.0)
	assert_eq(samples[0], 1000.0)
	assert_eq(WaterMeasurement.percentile(PackedFloat64Array(), 0.95), 0.0)


func test_recorder_runs_after_car_and_records_each_completed_tick_once() -> void:
	var car: Car = load("res://car/car.tscn").instantiate()
	add_child_autofree(car)
	var meter: WaterMeasurement = add_child_autofree(WaterMeasurement.new())
	assert_gt(meter.process_physics_priority, car.process_physics_priority)
	meter.begin(car)
	await wait_physics_frames(5)
	meter.active = false
	assert_gt(meter.rows.size(), 0)
	for index in range(1, meter.rows.size()):
		assert_eq(meter.rows[index][0], meter.rows[index - 1][0] + 1.0)
	for row in meter.rows:
		assert_eq(row[1], 0.0, "unbound dry car has zero water timing")
		assert_eq(row[6], 0.0)
		assert_eq(row[7], 0.0)
		assert_eq(row[8], 0.0)
	var result := meter.finish("user://water_measurement_test.csv")
	assert_eq(result.queries, 0.0)
	assert_eq(result.triangle_tests, 0.0)
	assert_eq(result.water_frame_p95_ms, 0.0)
	var frame_ticks := 0
	for row in meter.frames:
		assert_gte(row[1], 0.0)
		frame_ticks += int(row[2])
	assert_lte(frame_ticks, meter.rows.size(), "partial first/last frames are not counted twice")
	DirAccess.remove_absolute("user://water_measurement_test.csv")
	DirAccess.remove_absolute("user://water_measurement_test_frames.csv")
