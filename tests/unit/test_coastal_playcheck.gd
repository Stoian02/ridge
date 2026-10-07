extends GutTest
## Preview options must not become save overrides or survive the one-shot flag.

const PREVIEW := preload("res://debug/coastal_playcheck.gd")
const FLAG := "user://coastal_options_test"


func after_each() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(FLAG)


func test_cli_options_are_validated_without_writing_progress() -> void:
	var saved := GameState.progress.traction_control_strength
	var options: Dictionary = PREVIEW.read_options(["tc=0.15", "car=offroad_4x4", "start=course"])
	assert_eq(options.tc, 0.15)
	assert_eq(options.car, "offroad_4x4")
	assert_eq(options.start, "course")
	assert_eq(GameState.progress.traction_control_strength, saved)
	for value: String in ["nonsense", "1.1", "-0.1", "nan", "inf"]:
		assert_false(PREVIEW.read_options(["tc=" + value, "car=invalid"]).has("tc"))
	assert_false(PREVIEW.read_options(["car=invalid"]).has("car"))
	assert_true(PREVIEW.read_options(["balance=true"]).balance)
	assert_false(PREVIEW.read_options(["held=true", "balance=true"]).balance,
		"held throttle and pitch correction are distinct strategies")


func test_flag_is_consumed_and_cli_overrides_optional_phone_json() -> void:
	var file := FileAccess.open(FLAG, FileAccess.WRITE)
	file.store_string('{"car":"rally_tuned","tc":0.2,"mode":"smoke"}')
	file.close()
	var options: Dictionary = PREVIEW.read_options(["tc=0.15"], FLAG)
	assert_eq(options.car, "rally_tuned")
	assert_eq(options.tc, 0.15)
	assert_eq(options.mode, "smoke")
	assert_false(FileAccess.file_exists(FLAG))
	assert_eq(PREVIEW.read_options([], FLAG).mode, "manual")
	for content: String in ["", "not json", "[]"]:
		file = FileAccess.open(FLAG, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		assert_eq(PREVIEW.read_options([], FLAG).start, "jump")
		assert_false(FileAccess.file_exists(FLAG))
