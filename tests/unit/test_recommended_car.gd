extends GutTest
## LevelDef.recommended_car (M5 spec §3.1): round trip, the text, and the lines
## level select and car select show for it.

const LEVEL_SELECT := preload("res://ui/level_select.tscn")
const CAR_SELECT := preload("res://ui/car_select.tscn")
const CANYON_SCENE := "res://levels/canyon/canyon.tscn"

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()


func after_each() -> void:
	SaveSandbox.leave()


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _canyon() -> LevelDef:
	var level := LevelDef.new()
	level.id = &"canyon"
	level.display_name = "Canyon"
	level.scene_path = CANYON_SCENE
	level.recommended_car = &"offroad_4x4"
	level.two_star_time = 100.0
	level.three_star_time = 90.0
	return level


func _catalog_with_canyon() -> void:
	var catalog := LevelCatalog.new()
	catalog.levels = [state.catalog.levels[0], _canyon()]
	state.catalog = catalog
	state.record_finish(catalog.levels[0], 120.0, {})  # unlocks the canyon


func test_recommended_car_round_trips_and_defaults_to_none() -> void:
	assert_eq(LevelDef.new().recommended_car, &"")
	var path := "user://recommended_test.tres"
	assert_eq(ResourceSaver.save(_canyon(), path), OK)
	var loaded: LevelDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.recommended_car, &"offroad_4x4")
	DirAccess.remove_absolute(path)


func test_recommended_text_names_the_car_or_is_empty() -> void:
	assert_eq(_canyon().recommended_text(state.car_catalog), "Recommended: Off-road 4x4")
	assert_eq(LevelDef.new().recommended_text(state.car_catalog), "")
	var odd := _canyon()
	odd.recommended_car = &"mystery"
	assert_eq(odd.recommended_text(state.car_catalog), "Recommended: mystery", "an unknown id still shows something")


func test_level_select_shows_the_recommendation_on_the_card() -> void:
	_catalog_with_canyon()
	var select: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(select)
	assert_has(_labels(select.find_child("canyon", true, false)), "Recommended: Off-road 4x4")
	for text: String in _labels(select.find_child("rally_road", true, false)):
		assert_false(text.begins_with("Recommended"), "Rally Road recommends nothing")


func test_car_select_shows_it_under_the_destination() -> void:
	_catalog_with_canyon()
	state.pending_scene = CANYON_SCENE
	var screen: Control = CAR_SELECT.instantiate()
	add_child_autofree(screen)
	assert_has(_labels(screen), "Canyon")
	assert_has(_labels(screen), "Recommended: Off-road 4x4")
	screen.queue_free()
	state.pending_scene = "res://levels/rally_road/rally_road.tscn"
	var plain: Control = CAR_SELECT.instantiate()
	add_child_autofree(plain)
	for text: String in _labels(plain):
		assert_false(text.begins_with("Recommended"))


func test_recommending_the_4x4_does_not_lock_the_starter_car() -> void:
	_catalog_with_canyon()
	state.pending_scene = CANYON_SCENE
	var screen: Control = CAR_SELECT.instantiate()
	add_child_autofree(screen)
	var starter: Button = screen.find_child("rally", true, false)
	assert_false(starter.disabled)
	starter.pressed.emit()
	assert_eq(state.progress.selected_car, "rally")
	assert_eq(SaveSandbox.requested_scenes.back(), CANYON_SCENE)


func test_four_level_cards_fit_the_landscape_canvas() -> void:
	var catalog := LevelCatalog.new()
	catalog.levels = state.catalog.levels.slice(0, 3)
	catalog.levels.append(_canyon())
	state.catalog = catalog
	var screen: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(screen)
	await wait_process_frames(2)
	var cards: Control = screen.find_child("LevelCards", true, false)
	assert_not_null(cards)
	if cards == null:
		return
	assert_eq(cards.get_child_count(), 4)
	assert_lt(cards.get_combined_minimum_size().x, 1920.0, "all four cards fit horizontally")
	assert_lt(cards.get_parent().get_combined_minimum_size().y, 1080.0, "title, two rows and Back fit vertically")
