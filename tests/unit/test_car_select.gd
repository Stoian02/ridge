extends GutTest
## Car select (spec §5.2), with GameState in the save sandbox.

const CAR_SELECT := preload("res://ui/car_select.tscn")
const RALLY_ROAD := "res://levels/rally_road/rally_road.tscn"

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()
	state.pending_scene = RALLY_ROAD


func after_each() -> void:
	SaveSandbox.leave()


func _screen() -> Control:
	var screen: Control = CAR_SELECT.instantiate()
	add_child_autofree(screen)
	return screen


func _card(screen: Node, id: StringName) -> Button:
	return screen.find_child(String(id), true, false)


func _labels(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func _earn_three_stars() -> void:
	state.record_finish(state.catalog.levels[0], 60.0, {})


func test_one_card_per_car_each_with_a_preview_under_the_destination() -> void:
	var screen := _screen()
	assert_has(_labels(screen), "Rally Road · Asphalt")
	for car in state.car_catalog.cars:
		var card := _card(screen, car.id)
		assert_not_null(card, "a card for %s" % car.id)
		var previews := card.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node is CarPreview)
		assert_eq(previews.size(), 1, "%s has a preview" % car.id)


func test_unlocked_cars_describe_themselves_and_locked_cars_say_what_they_need() -> void:
	var screen := _screen()
	var rally := _card(screen, &"rally")
	assert_false(rally.disabled)
	assert_has(_labels(rally), state.car_catalog.cars[0].description)
	assert_has(_labels(rally), "Best on: Asphalt, dirt")
	var offroad := _card(screen, &"offroad_4x4")
	assert_true(offroad.disabled)
	assert_has(_labels(offroad), "Earn 3 stars to unlock (you have 0)")


func test_the_selected_car_is_highlighted() -> void:
	_earn_three_stars()
	state.set_selected_car(&"offroad_4x4")
	var screen := _screen()
	assert_true(_card(screen, &"offroad_4x4").has_theme_stylebox_override("normal"))
	assert_false(_card(screen, &"rally").has_theme_stylebox_override("normal"))


func test_tapping_a_car_saves_it_and_starts_the_pending_scene() -> void:
	_earn_three_stars()
	var screen := _screen()
	_card(screen, &"offroad_4x4").pressed.emit()
	assert_eq(state.progress.selected_car, "offroad_4x4")
	assert_eq(SaveSandbox.requested_scenes, [RALLY_ROAD])


func test_back_returns_to_level_select_or_to_the_main_menu_from_free_drive() -> void:
	var level_screen := _screen()
	level_screen.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Back")[0].pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [state.LEVEL_SELECT])
	level_screen.queue_free()
	state.pending_scene = state.FREE_DRIVE
	var free_screen := _screen()
	assert_has(_labels(free_screen), "Free Drive")
	free_screen.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Back")[0].pressed.emit()
	assert_eq(SaveSandbox.requested_scenes[-1], state.MAIN_MENU)


func test_car_select_only_uses_characters_the_font_has() -> void:
	var font := ThemeDB.fallback_font
	state.pending_scene = "res://levels/muddy_valley/muddy_valley.tscn"
	var screen := _screen()
	var texts := _labels(screen)
	texts.append("Earn 5 stars to unlock (you have 3)")
	for car in state.car_catalog.cars:
		texts.append_array([car.display_name, car.description, "Best on: %s" % car.best_on])
	for text: String in texts:
		for character in text:
			assert_true(font.has_char(character.unicode_at(0)), "font has '%s' (in \"%s\")" % [character, text])
