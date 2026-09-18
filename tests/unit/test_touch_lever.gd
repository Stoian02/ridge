extends GutTest
## TouchControls in lever mode (M5 spec §11.3).

var input: CarInput
var controls: TouchControls


func before_each() -> void:
	input = CarInput.new()
	add_child_autofree(input)
	controls = TouchControls.new()
	controls.car_input = input
	controls.screen_size_override = Vector2(1920.0, 1080.0)
	add_child_autofree(controls)
	controls.set_throttle_mode(TouchThrottleLogic.Mode.LEVER)


## A point inside the lever's track at `share` of its height (0 = bottom, 1 = top).
func _track_point(share: float) -> Vector2:
	var rect := controls.gas_rect()
	return Vector2(rect.get_center().x, rect.end.y - rect.size.y * share)


func test_the_lever_track_is_taller_than_the_pedal_and_sits_at_the_right_edge() -> void:
	var rect := controls.gas_rect()
	assert_eq(rect.size, TouchControls.LEVER_SIZE)
	assert_almost_eq(rect.end.x, 1920.0 - 40.0, 0.0001)
	assert_almost_eq(rect.end.y, 1080.0 - 40.0, 0.0001, "same bottom edge as the pedal")
	assert_gt(rect.position.y, TouchControls.TOP_STRIP_HEIGHT, "clear of the top strip")
	controls.set_throttle_mode(TouchThrottleLogic.Mode.PEDAL)
	assert_eq(controls.gas_rect().size, Vector2(250.0, 340.0), "the pedal is unchanged")


func test_pressing_in_the_track_sets_the_value_at_once() -> void:
	controls.handle_touch(0, _track_point(0.5), true)
	assert_almost_eq(input.virtual_throttle, 0.5, 0.0001, "press takes effect before the next frame")
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.5, 0.0001)
	assert_almost_eq(input.virtual_brake, 0.0, 0.0001)


func test_the_captured_finger_ignores_horizontal_drift() -> void:
	controls.handle_touch(0, _track_point(0.5), true)
	controls.handle_drag(0, _track_point(0.8) - Vector2(600.0, 0.0))
	assert_almost_eq(input.virtual_throttle, 0.8, 0.0001, "drag takes effect before the next frame")
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.8, 0.0001, "a thumb sliding sideways keeps the throttle")


func test_releasing_drops_to_zero_at_once() -> void:
	controls.handle_touch(0, _track_point(0.9), true)
	controls.update_outputs(0.016)
	controls.handle_touch(0, _track_point(0.9), false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)


func test_a_second_finger_in_the_track_does_not_take_over() -> void:
	controls.handle_touch(0, _track_point(0.5), true)
	controls.handle_touch(1, _track_point(0.9), true)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.5, 0.0001, "the first finger keeps the lever")
	controls.handle_touch(0, _track_point(0.5), false)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001, "the second was never captured")


func test_release_all_touches_zeroes_the_lever() -> void:
	controls.handle_touch(0, _track_point(0.7), true)
	controls.update_outputs(0.016)
	controls.release_all_touches()
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001, "and it stays zero")


func test_switching_mode_clears_the_capture() -> void:
	controls.handle_touch(0, _track_point(0.7), true)
	controls.set_throttle_mode(TouchThrottleLogic.Mode.PEDAL)
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001, "the old touch sits above the pedal")


func test_the_brake_pad_and_steering_work_as_before_in_lever_mode() -> void:
	controls.handle_touch(0, controls.brake_rect().get_center(), true)
	var start := Vector2(300.0, 700.0)
	controls.handle_touch(1, start, true)
	controls.handle_drag(1, start + Vector2(TouchControls.FULL_LOCK_PX, 0.0))
	controls.update_outputs(0.016)
	assert_almost_eq(input.virtual_brake, 1.0, 0.0001)
	assert_almost_eq(input.virtual_steer, 1.0, 0.0001)
	assert_almost_eq(input.virtual_throttle, 0.0, 0.0001)


func test_throttle_mode_names_match_the_save_file() -> void:
	assert_eq(TouchControls.throttle_mode_from_name(Progress.THROTTLE_LEVER), TouchThrottleLogic.Mode.LEVER)
	assert_eq(TouchControls.throttle_mode_from_name(Progress.THROTTLE_PEDAL), TouchThrottleLogic.Mode.PEDAL)
	assert_eq(TouchControls.throttle_mode_from_name("anything else"), TouchThrottleLogic.Mode.PEDAL)
	assert_eq(TouchControls.throttle_mode_name(TouchThrottleLogic.Mode.LEVER), Progress.THROTTLE_LEVER)
	assert_eq(TouchControls.throttle_mode_name(TouchThrottleLogic.Mode.PEDAL), Progress.THROTTLE_PEDAL)


func test_a_captured_throttle_finger_cannot_press_brake_or_steering_buttons() -> void:
	controls.set_steer_mode(TouchSteerLogic.Mode.BUTTONS)
	controls.handle_touch(4, _track_point(0.5), true)
	controls.handle_drag(4, controls.brake_rect().get_center())
	controls.update_outputs(0.2)
	assert_gt(input.virtual_throttle, 0.0)
	assert_eq(input.virtual_brake, 0.0, "horizontal drift must not brake")
	controls.handle_drag(4, controls.left_button_rect().get_center())
	controls.update_outputs(0.2)
	assert_eq(input.virtual_steer, 0.0, "horizontal drift must not steer")
	controls.handle_touch(5, controls.brake_rect().get_center(), true)
	controls.update_outputs(0.016)
	assert_eq(input.virtual_brake, 1.0, "a separate finger still brakes")


func test_release_and_mode_changes_clear_outputs_without_waiting_for_a_frame() -> void:
	controls.handle_touch(4, _track_point(0.25), true)
	controls.update_outputs(0.016)
	assert_gt(input.virtual_throttle, 0.0)
	controls.handle_touch(4, Vector2.ZERO, false)
	assert_eq(input.virtual_throttle, 0.0)
	controls.handle_touch(4, _track_point(0.25), true)
	controls.update_outputs(0.016)
	controls.set_throttle_mode(TouchThrottleLogic.Mode.PEDAL)
	assert_eq(input.virtual_throttle, 0.0)
	controls.update_outputs(0.016)
	assert_eq(input.virtual_throttle, 0.0, "old lever finger cannot become a held pedal")


func test_vertical_drift_clamps_and_an_outside_press_cannot_capture_the_lever() -> void:
	controls.handle_touch(4, _track_point(0.5) - Vector2(400.0, 0.0), true)
	controls.handle_drag(4, _track_point(0.5))
	controls.update_outputs(0.016)
	assert_eq(input.virtual_throttle, 0.0)
	controls.handle_touch(5, _track_point(0.5), true)
	controls.handle_drag(5, _track_point(2.0))
	controls.update_outputs(0.016)
	assert_eq(input.virtual_throttle, 1.0)
	controls.handle_drag(5, _track_point(-1.0))
	controls.update_outputs(0.016)
	assert_eq(input.virtual_throttle, 0.0)
