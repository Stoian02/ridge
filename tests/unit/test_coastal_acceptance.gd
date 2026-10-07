extends GutTest
## Parsing and frame schema are deterministic; render/phone gates are not unit tests.

const HARNESS := preload("res://debug/coastal_acceptance.gd")
const FLAG := "user://coastal_acceptance_options_test"


func after_each() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(FLAG)


func test_options_are_bounded_consumed_once_and_do_not_write_progress() -> void:
	var before := GameState.progress.to_dictionary().duplicate(true)
	var file := FileAccess.open(FLAG, FileAccess.WRITE)
	file.store_string('{"mode":"drive","tc":0.15,"car":"rally"}')
	file.close()
	var options: Dictionary = HARNESS.read_options(["tc=0.2"], FLAG)
	assert_eq(options, {"mode": "drive", "tc": 0.2, "car": "rally", "seconds": 10.0})
	assert_false(FileAccess.file_exists(FLAG))
	for invalid: String in ["nan", "inf", "-1", "90", "junk"]:
		assert_eq(HARNESS.read_options(["tc=" + invalid]).tc, 0.2)
		assert_eq(HARNESS.read_options(["seconds=" + invalid]).seconds, 10.0)
	assert_eq(HARNESS.read_options(["mode=unknown", "car=unknown"]).mode, "loads")
	assert_eq(HARNESS.read_options(["mode=soak"]).mode, "soak")
	assert_eq(GameState.progress.to_dictionary(), before)


func test_summary_keeps_tails_counts_ticks_and_uses_wall_time_not_mean_fps() -> void:
	var rows: Array[PackedFloat64Array] = [
		PackedFloat64Array([16000, 16000, 2, 80, 100, 200000, 180, 16000]),
		PackedFloat64Array([66000, 50000, 6, 200, 145, 299000, 181, 66000]),
		PackedFloat64Array([220000, 34000, 4, 120, 110, 210000, 182, 220000])]
	var result := CoastalFrameMeasurement.summarize(rows)
	assert_eq(result.frames, 3)
	assert_almost_eq(result.fps, 30.0, 0.00001)
	assert_eq(result.p95_ms, 50.0)
	assert_eq(result.p99_ms, 50.0)
	assert_eq(result.max_ms, 50.0)
	assert_eq(result.empty_water_upper_p95_ms, 0.2)
	assert_eq(result.draw_peak, 145)
	assert_eq(result.primitive_peak, 299000)
	assert_eq(result.tails.size(), 2)
	assert_eq(result.tails[0].classification, "start")
	assert_eq(result.tails[1].classification, "warmed")
	assert_eq(CoastalFrameMeasurement.summarize([]).fps, 0.0)
