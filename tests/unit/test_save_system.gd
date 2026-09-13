extends GutTest

const FOLDER := "user://test_save_system"
const PATH := FOLDER + "/save.json"


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _write_text(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func before_each() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		_remove(PATH + suffix)
	_remove(FOLDER + "/blocked")


func after_each() -> void:
	before_each()


func test_write_then_read_round_trip() -> void:
	var data := {"version": 1, "levels": {"rally_road": {"best_time": 71.6, "stars": 3}}}
	assert_eq(SaveSystem.write(PATH, data), OK)
	var loaded := SaveSystem.read(PATH)
	assert_almost_eq(float(loaded["levels"]["rally_road"]["best_time"]), 71.6, 0.0001)
	assert_eq(int(loaded["levels"]["rally_road"]["stars"]), 3)


func test_a_write_leaves_no_temporary_file() -> void:
	SaveSystem.write(PATH, {"version": 1})
	assert_true(FileAccess.file_exists(PATH))
	assert_false(FileAccess.file_exists(PATH + ".tmp"))


func test_a_write_replaces_the_previous_save() -> void:
	SaveSystem.write(PATH, {"version": 1, "a": 1})
	SaveSystem.write(PATH, {"version": 1, "b": 2})
	var loaded := SaveSystem.read(PATH)
	assert_false(loaded.has("a"))
	assert_true(loaded.has("b"))


func test_a_missing_file_reads_as_empty() -> void:
	assert_eq(SaveSystem.read(PATH), {})


func test_a_damaged_file_reads_as_empty_and_is_kept_as_bad() -> void:
	_write_text(PATH, "{not json")
	assert_eq(SaveSystem.read(PATH), {})
	assert_false(FileAccess.file_exists(PATH), "the damaged file moved aside")
	assert_eq(FileAccess.get_file_as_string(PATH + ".bad"), "{not json")


func test_json_that_is_not_an_object_counts_as_damaged() -> void:
	_write_text(PATH, "[1, 2, 3]")
	assert_eq(SaveSystem.read(PATH), {})
	assert_true(FileAccess.file_exists(PATH + ".bad"))


func test_a_newer_damaged_file_replaces_an_older_bad_copy() -> void:
	_write_text(PATH + ".bad", "old damage")
	_write_text(PATH, "new damage")
	SaveSystem.read(PATH)
	assert_eq(FileAccess.get_file_as_string(PATH + ".bad"), "new damage")


func test_a_write_that_cannot_happen_returns_an_error() -> void:
	# A plain file sits where the save's folder should be, so the save can't be written.
	_write_text(FOLDER + "/blocked", "not a folder")
	var error := SaveSystem.write(FOLDER + "/blocked/save.json", {"version": 1})
	assert_ne(error, OK)
	assert_false(FileAccess.file_exists(FOLDER + "/blocked/save.json.tmp"))
