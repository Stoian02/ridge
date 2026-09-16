extends GutTest

var catalog: LevelCatalog
var first: LevelDef
var second: LevelDef
var progress: Progress


func _level(id: StringName) -> LevelDef:
	var level := LevelDef.new()
	level.id = id
	level.two_star_time = 85.0
	level.three_star_time = 74.0
	return level


func before_each() -> void:
	first = _level(&"first")
	second = _level(&"second")
	catalog = LevelCatalog.new()
	catalog.levels = [first, second]
	progress = Progress.new()


func test_a_fresh_progress_has_nothing_recorded() -> void:
	assert_almost_eq(progress.best_time(&"first"), -1.0, 0.0001)
	assert_eq(progress.stars(&"first"), 0)
	assert_true(progress.best_splits(&"first").is_empty())
	assert_eq(progress.steer_mode, Progress.STEER_ANALOG)


func test_the_first_level_is_open_and_finishing_it_opens_the_next() -> void:
	assert_true(progress.is_unlocked(catalog, first))
	assert_false(progress.is_unlocked(catalog, second))
	progress.record_finish(first, 120.0, {})
	assert_true(progress.is_unlocked(catalog, second))
	assert_false(progress.is_unlocked(catalog, _level(&"elsewhere")), "not in the catalog")


func test_record_finish_reports_stars_and_a_new_best() -> void:
	var result := progress.record_finish(first, 80.0, {1: 20.0})
	assert_eq(result["stars"], 2)
	assert_true(result["new_best"])
	assert_almost_eq(result["best_time"], 80.0, 0.0001)


func test_a_slower_run_keeps_the_best_time_and_its_splits() -> void:
	progress.record_finish(first, 80.0, {1: 20.0, 2: 50.0})
	var result := progress.record_finish(first, 90.0, {1: 19.0, 2: 55.0})
	assert_false(result["new_best"])
	assert_almost_eq(progress.best_time(&"first"), 80.0, 0.0001)
	assert_eq(progress.best_splits(&"first"), {1: 20.0, 2: 50.0}, "splits stay with the best run")


func test_a_faster_run_replaces_the_best_time_and_splits_together() -> void:
	progress.record_finish(first, 80.0, {1: 20.0, 2: 50.0})
	progress.record_finish(first, 72.0, {1: 18.0, 2: 45.0})
	assert_almost_eq(progress.best_time(&"first"), 72.0, 0.0001)
	assert_eq(progress.best_splits(&"first"), {1: 18.0, 2: 45.0})


func test_stars_keep_the_most_ever_earned() -> void:
	progress.record_finish(first, 70.0, {})
	var result := progress.record_finish(first, 100.0, {})
	assert_eq(result["stars"], 1, "this run earned one")
	assert_eq(progress.stars(&"first"), 3, "the record keeps three")


func test_total_stars_counts_catalog_levels() -> void:
	progress.record_finish(first, 70.0, {})
	progress.record_finish(second, 80.0, {})
	assert_eq(progress.total_stars(catalog), 5)


func test_returned_splits_are_a_copy() -> void:
	progress.record_finish(first, 80.0, {1: 20.0})
	progress.best_splits(&"first")[1] = 999.0
	assert_almost_eq(progress.best_splits(&"first")[1], 20.0, 0.0001)


func test_dictionary_round_trip() -> void:
	progress.steer_mode = Progress.STEER_BUTTONS
	progress.record_finish(first, 71.6, {1: 14.8, 2: 26.2})
	var copy := Progress.from_dictionary(progress.to_dictionary())
	assert_eq(copy.steer_mode, Progress.STEER_BUTTONS)
	assert_almost_eq(copy.best_time(&"first"), 71.6, 0.0001)
	assert_eq(copy.best_splits(&"first"), {1: 14.8, 2: 26.2})
	assert_eq(copy.stars(&"first"), 3)


func test_save_format_uses_string_split_keys() -> void:
	progress.record_finish(first, 80.0, {1: 20.0})
	var data := progress.to_dictionary()
	assert_eq(data["version"], Progress.VERSION)
	assert_eq(data["levels"]["first"]["best_splits"], {"1": 20.0})


func test_values_read_back_from_json_are_accepted() -> void:
	# JSON gives floats for whole numbers and strings for dictionary keys.
	var data := {"settings": {"steer_mode": "buttons"},
			"levels": {"first": {"best_time": 71.6, "best_splits": {"1": 14.8}, "stars": 3.0}}}
	var loaded := Progress.from_dictionary(data)
	assert_eq(loaded.stars(&"first"), 3)
	assert_eq(loaded.best_splits(&"first"), {1: 14.8})


func test_unknown_missing_and_wrongly_typed_values_fall_back_to_defaults() -> void:
	var data := {"future_field": true, "settings": {"steer_mode": "joystick"},
			"levels": {
				"first": {"best_time": "fast", "stars": 9, "best_splits": {"x": 1.0}},
				"second": "not a record",
			}}
	var loaded := Progress.from_dictionary(data)
	assert_eq(loaded.steer_mode, Progress.STEER_ANALOG)
	assert_almost_eq(loaded.best_time(&"first"), -1.0, 0.0001)
	assert_eq(loaded.stars(&"first"), 3, "stars clamp to 3")
	assert_true(loaded.best_splits(&"first").is_empty())
	assert_eq(loaded.stars(&"second"), 0)
	assert_eq(Progress.from_dictionary({}).steer_mode, Progress.STEER_ANALOG)


func test_the_selected_car_is_saved_and_defaults_to_the_rally_car() -> void:
	assert_eq(progress.selected_car, Progress.DEFAULT_CAR)
	progress.selected_car = "offroad_4x4"
	assert_eq(Progress.from_dictionary(progress.to_dictionary()).selected_car, "offroad_4x4")
	assert_eq(Progress.from_dictionary({"settings": {"steer_mode": "analog"}}).selected_car, "rally", "an older save")
	assert_eq(Progress.from_dictionary({"settings": {"selected_car": 7}}).selected_car, "rally", "a wrongly typed value")


func test_the_sound_setting_is_saved_and_only_takes_its_steps() -> void:
	assert_eq(progress.sound_volume, 1.0)
	progress.sound_volume = 0.25
	assert_eq(Progress.from_dictionary(progress.to_dictionary()).sound_volume, 0.25)
	assert_eq(Progress.from_dictionary({"settings": {"sound_volume": 0}}).sound_volume, 0.0, "JSON may give an int")
	assert_eq(Progress.from_dictionary({"settings": {"sound_volume": 0.3}}).sound_volume, 1.0, "not a step")
	assert_eq(Progress.from_dictionary({"settings": {"sound_volume": "loud"}}).sound_volume, 1.0)
	assert_eq(Progress.from_dictionary({"settings": {"steer_mode": "analog"}}).sound_volume, 1.0, "an older save")


func test_traction_strength_round_trips_with_full_as_the_old_save_default() -> void:
	assert_eq(progress.traction_control_strength, 1.0)
	for strength: float in [0.0, 0.37, 0.5, 1.0]:
		progress.traction_control_strength = strength
		assert_eq(Progress.from_dictionary(progress.to_dictionary()).traction_control_strength, strength)
	assert_eq(Progress.from_dictionary({}).traction_control_strength, 1.0)
	assert_eq(Progress.from_dictionary({"settings": {"sound_volume": 0.5}}).traction_control_strength, 1.0)


func test_traction_strength_rejects_invalid_values_and_clamps_numbers() -> void:
	for invalid: Variant in [null, "off", true, [], {}, NAN, INF, -INF]:
		var loaded := Progress.from_dictionary({"settings": {"traction_control_strength": invalid}})
		assert_eq(loaded.traction_control_strength, 1.0)
	for pair: Vector2 in [Vector2(-1, 0), Vector2(2, 1), Vector2(0, 0)]:
		var loaded := Progress.from_dictionary({"settings": {"traction_control_strength": pair.x}})
		assert_eq(loaded.traction_control_strength, pair.y)
