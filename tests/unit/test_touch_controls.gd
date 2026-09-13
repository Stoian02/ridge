extends GutTest

var input: CarInput
var controls: TouchControls


func before_each() -> void:
	input = CarInput.new()
	add_child_autofree(input)
	controls = TouchControls.new()
	controls.car_input = input
	controls.screen_size_override = Vector2(1920.0, 1080.0)
	add_child_autofree(controls)


func _strip_buttons() -> Array:
	return controls.find_children("*", "Button", true, false)


func test_gas_pad_sets_throttle() -> void:
	controls.handle_touch(0, controls.gas_rect().get_center(), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 1.0, 0.0001)
	assert_almost_eq(input.virtual_brake, 0.0, 0.0001)


func test_releasing_gas_clears_throttle() -> void:
	controls.handle_touch(0, controls.gas_rect().get_center(), true)
	controls.handle_touch(0, controls.gas_rect().get_center(), false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)


func test_sliding_from_brake_to_gas_switches_pedal() -> void:
	controls.handle_touch(0, controls.brake_rect().get_center(), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_brake, 1.0, 0.0001)
	controls.handle_drag(0, controls.gas_rect().get_center())
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_brake, 0.0, 0.0001)
	assert_almost_eq(input.virtual_throttle, 1.0, 0.0001)


func test_analog_steer_follows_the_thumb() -> void:
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(TouchControls.FULL_LOCK_PX, 0.0))
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, 1.0, 0.0001)


func test_analog_steer_recentres_on_release() -> void:
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(-200.0, 0.0))
	controls.handle_touch(1, start, false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, 0.0, 0.0001)


func test_touches_in_the_top_strip_are_ignored() -> void:
	controls.handle_touch(1, Vector2(300.0, 50.0), true)
	controls.handle_drag(1, Vector2(600.0, 50.0))
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, 0.0, 0.0001)


func test_button_mode_ramps_steer() -> void:
	controls.set_steer_mode(TouchSteerLogic.Mode.BUTTONS)
	controls.handle_touch(2, controls.right_button_rect().get_center(), true)
	controls.update_outputs(0.1)
	assert_almost_eq(input.virtual_steer, 0.3, 0.0001)


func test_gas_and_steer_together() -> void:
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(-TouchControls.FULL_LOCK_PX, 0.0))
	controls.handle_touch(2, controls.gas_rect().get_center(), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_steer, -1.0, 0.0001)
	assert_almost_eq(input.virtual_throttle, 1.0, 0.0001)


func test_the_top_strip_has_reset_and_pause_only() -> void:
	var texts := _strip_buttons().map(func(b: Button) -> String: return b.text)
	assert_eq(texts, ["Reset", "Pause"])


func test_pause_button_requests_pause() -> void:
	watch_signals(controls)
	var pause: Button = _strip_buttons().filter(func(b: Button) -> bool: return b.text == "Pause")[0]
	pause.pressed.emit()
	assert_signal_emitted(controls, "pause_requested")


func test_release_all_touches_zeroes_pedals_and_steering() -> void:
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(TouchControls.FULL_LOCK_PX, 0.0))
	controls.handle_touch(2, controls.gas_rect().get_center(), true)
	controls.update_outputs(0.016)
	controls.release_all_touches()
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)
	assert_almost_eq(input.virtual_steer, 0.0, 0.0001)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001, "the old touches are gone, not just zeroed once")


func test_steer_mode_names_match_the_save_file() -> void:
	assert_eq(TouchControls.mode_from_name(Progress.STEER_BUTTONS), TouchSteerLogic.Mode.BUTTONS)
	assert_eq(TouchControls.mode_from_name(Progress.STEER_ANALOG), TouchSteerLogic.Mode.ANALOG)
	assert_eq(TouchControls.mode_from_name("anything else"), TouchSteerLogic.Mode.ANALOG)
	assert_eq(TouchControls.mode_name(TouchSteerLogic.Mode.BUTTONS), Progress.STEER_BUTTONS)
