extends GutTest

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")

var rig: DrivingRig
var menu: PauseMenu


func _add_menu(show_restart: bool = true) -> void:
	menu = PauseMenu.new()
	menu.show_restart = show_restart
	add_child_autofree(menu)
	menu.setup(rig)


func _button_starting(prefix: String) -> Button:
	return menu.find_children("*", "Button", true, false).filter(
			func(b: Button) -> bool: return b.text.begins_with(prefix))[0]


func before_each() -> void:
	SaveSandbox.enter()
	rig = RIG_SCENE.instantiate()
	add_child_autofree(rig)
	rig.touch_controls.screen_size_override = Vector2(1920.0, 1080.0)


func after_each() -> void:
	get_tree().paused = false
	SaveSandbox.leave()


func test_opening_pauses_the_game_and_resume_unpauses_it() -> void:
	_add_menu()
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS, "the menu keeps working while paused")
	assert_false(menu.is_open())
	menu.open()
	assert_true(menu.is_open())
	assert_true(get_tree().paused)
	_button_starting("Resume").pressed.emit()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)


func test_opening_lets_go_of_a_held_pedal() -> void:
	_add_menu()
	rig.touch_controls.handle_touch(0, rig.touch_controls.gas_rect().get_center(), true)
	rig.touch_controls.update_outputs(0.016)
	assert_almost_eq(rig.car.input.virtual_throttle, 1.0, 0.0001)
	menu.open()
	assert_almost_eq(rig.car.input.virtual_throttle, 0.0, 0.0001)


func test_back_closes_an_open_menu_and_otherwise_asks_the_level() -> void:
	_add_menu()
	watch_signals(menu)
	menu.handle_back()
	assert_signal_emit_count(menu, "back_pressed", 1)
	menu.open()
	menu.handle_back()
	assert_false(menu.is_open())
	assert_false(get_tree().paused)
	assert_signal_emit_count(menu, "back_pressed", 1, "closing is not a back request")


func test_free_drive_hides_restart_and_level_select() -> void:
	_add_menu(false)
	assert_false(_button_starting("Restart").visible)
	assert_false(_button_starting("Level select").visible)
	assert_true(_button_starting("Main menu").visible)


func test_restart_closes_the_menu_and_asks_for_a_restart() -> void:
	_add_menu()
	watch_signals(menu)
	menu.open()
	_button_starting("Restart").pressed.emit()
	assert_signal_emitted(menu, "restart_pressed")
	assert_false(get_tree().paused)


func test_steering_switches_style_and_saves_it() -> void:
	_add_menu()
	menu.open()
	var steering := _button_starting("Steering")
	assert_eq(steering.text, "Steering: Analog")
	steering.pressed.emit()
	assert_eq(rig.touch_controls.steer_mode, TouchSteerLogic.Mode.BUTTONS)
	assert_eq(steering.text, "Steering: Buttons")
	var saved := SaveSystem.read(SaveSandbox.PATH)
	assert_eq(saved["settings"]["steer_mode"], Progress.STEER_BUTTONS)


func test_telemetry_and_rec_show_their_state() -> void:
	_add_menu()
	rig.telemetry.visible = false
	menu.open()
	var telemetry := _button_starting("Telemetry")
	assert_eq(telemetry.text, "Telemetry: Off")
	telemetry.pressed.emit()
	assert_true(rig.telemetry.visible)
	assert_eq(telemetry.text, "Telemetry: On")
	var recording := _button_starting("Rec")
	assert_eq(recording.text, "Rec: Off")
	recording.pressed.emit()
	assert_eq(recording.text, "Rec: On")
	recording.pressed.emit()
	assert_eq(recording.text, "Rec: Off")


func test_level_select_and_main_menu_emit_their_signals() -> void:
	_add_menu()
	watch_signals(menu)
	_button_starting("Level select").pressed.emit()
	_button_starting("Main menu").pressed.emit()
	assert_signal_emitted(menu, "level_select_pressed")
	assert_signal_emitted(menu, "main_menu_pressed")


func test_change_car_is_offered_in_levels_and_free_drive() -> void:
	for show_restart: bool in [true, false]:
		_add_menu(show_restart)
		var button := _button_starting("Change car")
		assert_true(button.visible, "shown with show_restart %s" % show_restart)
		watch_signals(menu)
		button.pressed.emit()
		assert_signal_emitted(menu, "car_select_pressed")
		menu.queue_free()
