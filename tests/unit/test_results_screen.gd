extends GutTest

var screen: ResultsScreen
var level: LevelDef


func before_each() -> void:
	screen = ResultsScreen.new()
	add_child_autofree(screen)
	level = LevelDef.new()
	level.two_star_time = 85.0
	level.three_star_time = 74.0


func _button(text: String) -> Button:
	return screen.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == text)[0]


func _label_texts() -> Array:
	return screen.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)


func test_hidden_until_shown() -> void:
	assert_false(screen.is_showing())
	screen.show_results(80.0, 2, level, 80.0, true, false)
	assert_true(screen.is_showing())
	screen.hide_results()
	assert_false(screen.is_showing())


func test_shows_time_stars_targets_and_new_best() -> void:
	screen.show_results(71.64, 3, level, 71.64, true, false)
	var texts := _label_texts()
	assert_has(texts, "1:11.6")
	assert_eq(screen.stars.earned, 3)
	assert_has(texts, "1 star: finish · 2 stars: under 1:25.0 · 3 stars: under 1:14.0")
	assert_has(texts, "New best!")


func test_a_run_that_is_not_a_record_shows_the_best_time() -> void:
	screen.show_results(90.0, 1, level, 71.6, false, false)
	assert_has(_label_texts(), "Best  1:11.6")
	assert_eq(screen.stars.earned, 1)


func test_a_level_without_star_times_shows_only_the_time_and_best() -> void:
	screen.show_results(15.7, 0, null, 15.7, true, false)
	assert_has(_label_texts(), "0:15.7")
	assert_false(screen.stars.visible)
	assert_does_not_have(_label_texts(), ResultsScreen.targets_text(level))


func test_next_level_only_shows_when_there_is_one() -> void:
	screen.show_results(90.0, 1, level, 90.0, true, false)
	assert_false(_button("Next level").visible)
	screen.show_results(90.0, 1, level, 90.0, true, true)
	assert_true(_button("Next level").visible)


func test_buttons_emit_their_signals() -> void:
	watch_signals(screen)
	_button("Retry").pressed.emit()
	_button("Next level").pressed.emit()
	_button("Level select").pressed.emit()
	assert_signal_emitted(screen, "retry_pressed")
	assert_signal_emitted(screen, "next_pressed")
	assert_signal_emitted(screen, "level_select_pressed")


func test_the_font_has_every_character_the_screen_uses() -> void:
	var font := ThemeDB.fallback_font
	for character in ResultsScreen.targets_text(level) + "New best!Best Finish":
		assert_true(font.has_char(character.unicode_at(0)), "font has '%s'" % character)
