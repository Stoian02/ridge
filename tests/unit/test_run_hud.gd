extends GutTest


func test_time_format() -> void:
	assert_eq(RunHud.format_time(0.0), "0:00.0")
	assert_eq(RunHud.format_time(59.99), "0:59.9")
	assert_eq(RunHud.format_time(92.46), "1:32.4")
	assert_eq(RunHud.format_time(-1.0), "0:00.0")


func test_countdown_text() -> void:
	var clock := RunClock.new()
	clock.start_countdown()
	assert_eq(RunHud.countdown_text(clock), "3")
	clock.tick(1.5)
	assert_eq(RunHud.countdown_text(clock), "2")
	clock.tick(2.0)
	assert_eq(RunHud.countdown_text(clock), "GO")


func test_split_text_with_and_without_a_best_to_compare() -> void:
	assert_eq(RunHud.split_text(2, 41.3, NAN), "CP 2   0:41.3")
	assert_eq(RunHud.split_text(2, 41.3, -1.24), "CP 2   0:41.3   -1.2")
	assert_eq(RunHud.split_text(2, 41.3, 0.5), "CP 2   0:41.3   +0.5")


func test_finish_panel_shows_and_hides() -> void:
	var hud := RunHud.new()
	add_child_autofree(hud)
	assert_false(hud.is_finish_visible())
	hud.show_finish(92.4, 90.9)
	assert_true(hud.is_finish_visible())
	hud.hide_finish()
	assert_false(hud.is_finish_visible())
