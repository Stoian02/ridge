extends GutTest

const TEST_DIR := "user://test_runs"
const TEST_PATH := "user://test_runs/test_run.csv"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_header_has_car_and_wheel_columns() -> void:
	var header := RunRecorder.csv_header()
	assert_string_starts_with(header, "time,speed_kmh,rpm,gear")
	assert_string_contains(header, "fl_slip_ratio")
	assert_string_contains(header, "rr_surface")


func test_row_has_as_many_columns_as_the_header() -> void:
	var row := RunRecorder.csv_row(TelemetrySample.make(), 1.0)
	assert_eq(row.split(",").size(), RunRecorder.csv_header().split(",").size())


func test_row_values() -> void:
	var row := RunRecorder.csv_row(TelemetrySample.make(), 1.5)
	assert_string_starts_with(row, "1.5000,42.50,4100,-1,")
	assert_string_contains(row, ",mud,")


func test_start_record_stop_writes_a_file() -> void:
	var recorder: RunRecorder = add_child_autofree(RunRecorder.new())
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	assert_eq(recorder.start(TEST_PATH), TEST_PATH)
	assert_true(recorder.is_recording())
	recorder.record(TelemetrySample.make(), 0.0)
	recorder.record(TelemetrySample.make(), 0.01)
	recorder.stop()
	assert_false(recorder.is_recording())
	var lines := FileAccess.get_file_as_string(TEST_PATH).strip_edges().split("\n")
	assert_eq(lines.size(), 3, "header + 2 rows")
