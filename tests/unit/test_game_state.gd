extends GutTest

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()


func after_each() -> void:
	SaveSandbox.leave()


func test_the_sandbox_starts_with_empty_progress() -> void:
	assert_eq(state.save_path, SaveSandbox.PATH)
	assert_eq(state.progress.total_stars(state.catalog), 0)


func test_finds_rally_road_by_its_scene() -> void:
	var rally: LevelDef = state.level_for_scene("res://levels/rally_road/rally_road.tscn")
	assert_not_null(rally)
	assert_eq(rally.id, &"rally_road")
	assert_null(state.level_for_scene(state.FREE_DRIVE), "Free Drive is not a catalog level")


func test_record_finish_saves_to_the_file() -> void:
	var rally: LevelDef = state.catalog.levels[0]
	var result: Dictionary = state.record_finish(rally, 75.0, {1: 15.0})
	assert_eq(result["stars"], 2)
	var saved := SaveSystem.read(SaveSandbox.PATH)
	assert_almost_eq(float(saved["levels"]["rally_road"]["best_time"]), 75.0, 0.0001)


func test_progress_survives_a_reload() -> void:
	var rally: LevelDef = state.catalog.levels[0]
	state.record_finish(rally, 72.0, {1: 14.0})
	state.set_steer_mode(Progress.STEER_BUTTONS)
	state.reload()
	assert_almost_eq(state.progress.best_time(&"rally_road"), 72.0, 0.0001)
	assert_eq(state.progress.best_splits(&"rally_road"), {1: 14.0})
	assert_eq(state.progress.steer_mode, Progress.STEER_BUTTONS)


func test_change_scene_unpauses_and_goes_through_the_scene_changer() -> void:
	get_tree().paused = true
	state.change_scene(state.LEVEL_SELECT)
	assert_false(get_tree().paused)
	assert_eq(SaveSandbox.requested_scenes, [state.LEVEL_SELECT])


func test_leaving_the_sandbox_restores_the_real_settings() -> void:
	SaveSandbox.leave()
	assert_eq(state.save_path, state.DEFAULT_SAVE_PATH)
	assert_true(state.scene_changer.get_object() is SceneTree)
	SaveSandbox.enter()


func test_the_selected_car_falls_back_to_the_rally_car_while_locked_or_unknown() -> void:
	assert_eq(state.selected_car().id, &"rally")
	state.set_selected_car(&"offroad_4x4")
	assert_eq(state.selected_car().id, &"rally", "the 4x4 needs 3 stars")
	state.record_finish(state.catalog.levels[0], 60.0, {})
	assert_eq(state.selected_car().id, &"offroad_4x4")
	state.progress.selected_car = "no_such_car"
	assert_eq(state.selected_car().id, &"rally")


func test_choosing_a_car_is_saved() -> void:
	state.set_selected_car(&"rally_tuned")
	var saved := SaveSystem.read(SaveSandbox.PATH)
	assert_eq(saved["settings"]["selected_car"], "rally_tuned")


func test_choose_car_for_remembers_the_scene_and_opens_car_select() -> void:
	state.choose_car_for("res://levels/rally_road/rally_road.tscn")
	assert_eq(state.pending_scene, "res://levels/rally_road/rally_road.tscn")
	assert_eq(SaveSandbox.requested_scenes, [state.CAR_SELECT])


func test_a_finish_reports_the_cars_it_unlocks() -> void:
	var result: Dictionary = state.record_finish(state.catalog.levels[0], 60.0, {})
	assert_eq(result["new_cars"].map(func(car: CarDef) -> StringName: return car.id), [&"offroad_4x4"])
	var again: Dictionary = state.record_finish(state.catalog.levels[0], 59.0, {})
	assert_true(again["new_cars"].is_empty(), "the 4x4 was already unlocked")
