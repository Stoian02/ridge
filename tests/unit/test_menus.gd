extends GutTest
## The main menu and level select, with GameState in the save sandbox.

const MAIN_MENU := preload("res://ui/main_menu.tscn")
const LEVEL_SELECT := preload("res://ui/level_select.tscn")

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()


func after_each() -> void:
	SaveSandbox.leave()


func _buttons(screen: Node) -> Array:
	return screen.find_children("*", "Button", true, false)


func _button(screen: Node, text: String) -> Button:
	return _buttons(screen).filter(func(b: Button) -> bool: return b.text == text)[0]


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _second_level() -> LevelDef:
	var second := LevelDef.new()
	second.id = &"second"
	second.display_name = "Second"
	second.scene_path = "res://levels/second/second.tscn"
	second.two_star_time = 100.0
	second.three_star_time = 90.0
	return second


func test_main_menu_play_and_free_drive_open_their_scenes() -> void:
	var menu: Control = MAIN_MENU.instantiate()
	add_child_autofree(menu)
	_button(menu, "Play").pressed.emit()
	_button(menu, "Free Drive").pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [state.LEVEL_SELECT, state.CAR_SELECT])
	assert_eq(state.pending_scene, state.FREE_DRIVE, "car select then starts Free Drive")


func test_main_menu_shows_total_stars() -> void:
	state.record_finish(state.catalog.levels[0], 75.0, {})
	var menu: Control = MAIN_MENU.instantiate()
	add_child_autofree(menu)
	assert_has(_labels(menu), "2 / 6 stars")


func test_level_select_opens_car_select_for_an_unlocked_level() -> void:
	var select: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(select)
	var card: Button = select.find_child("rally_road", true, false)
	assert_false(card.disabled)
	assert_has(_labels(card), "Rally Road")
	assert_has(_labels(card), "No time yet")
	card.pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [state.CAR_SELECT])
	assert_eq(state.pending_scene, "res://levels/rally_road/rally_road.tscn")


func test_level_select_shows_best_time_and_stars() -> void:
	state.record_finish(state.catalog.levels[0], 71.64, {})
	var select: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(select)
	var card: Button = select.find_child("rally_road", true, false)
	assert_has(_labels(card), "Best  1:11.6")
	var stars: StarRow = card.find_children("*", "StarRow", true, false)[0]
	assert_eq(stars.earned, 3)


func test_a_level_stays_locked_until_the_previous_one_is_finished() -> void:
	var catalog := LevelCatalog.new()
	catalog.levels = [state.catalog.levels[0], _second_level()]
	state.catalog = catalog
	var select: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(select)
	var locked: Button = select.find_child("second", true, false)
	assert_true(locked.disabled)
	assert_has(_labels(locked), "Finish Rally Road to unlock")
	select.queue_free()
	state.record_finish(catalog.levels[0], 120.0, {})
	var again: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(again)
	assert_false((again.find_child("second", true, false) as Button).disabled)


func test_level_select_back_returns_to_the_main_menu() -> void:
	var select: Control = LEVEL_SELECT.instantiate()
	add_child_autofree(select)
	_button(select, "Back").pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [state.MAIN_MENU])


func test_menus_only_use_characters_the_font_has() -> void:
	var font := ThemeDB.fallback_font
	for text in ["RIDGE", "0 / 3 stars", "Select level", "Finish Rally Road to unlock", "No time yet", "Best  1:11.6"]:
		for character in text:
			assert_true(font.has_char(character.unicode_at(0)), "font has '%s'" % character)


func test_the_benchmark_argument_is_recognised_only_when_given() -> void:
	var main_menu: GDScript = load("res://ui/main_menu.gd")
	assert_true(main_menu.wants_benchmark(PackedStringArray(["--benchmark"])))
	assert_true(main_menu.wants_benchmark(PackedStringArray(["--path", ".", "--benchmark"])))
	assert_false(main_menu.wants_benchmark(PackedStringArray([])))
	assert_false(main_menu.wants_benchmark(PackedStringArray(["res://debug/load_benchmark.tscn"])))
