extends GutTest


func test_summary_keeps_tail_percentiles_and_missing_gpu_explicit() -> void:
	var rows: Array[PackedFloat64Array] = []
	for index in 100:
		var row := PackedFloat64Array()
		row.resize(17)
		row[1] = 16000.0 if index < 98 else 40000.0
		row[3] = 1000.0
		row[11] = 2000.0 if index < 99 else 7000.0
		row[12] = 500.0
		row[13] = 0.0
		rows.append(row)
	var result := WaterTotalMeasurement.summarize(rows)
	assert_eq(result.frames, 100)
	assert_eq(result.total_upper_p95_ms, 2.0)
	assert_eq(result.total_upper_p99_ms, 2.0)
	assert_eq(result.total_upper_p100_ms, 7.0)
	assert_eq(result.frame_p99_ms, 40.0)
	assert_eq(result.over_33ms, 2)
	assert_false(result.gpu_valid)
	assert_eq(result.wave_query_p95_ms, 0.5, "nested attribution, not a second addition")
	assert_eq(result.controller_p95_ms, 1.0)


func test_empty_summary_is_not_a_gpu_pass() -> void:
	var result := WaterTotalMeasurement.summarize([])
	assert_eq(result.frames, 0)
	assert_eq(result.fps, 0.0)
	assert_false(result.gpu_valid)
