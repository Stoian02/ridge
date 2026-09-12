extends GutTest

const DRIVING_ACTIONS := [
	InputActions.THROTTLE, InputActions.BRAKE, InputActions.STEER_LEFT, InputActions.STEER_RIGHT,
]

var input: CarInput


func before_each() -> void:
	input = CarInput.new()
	add_child_autofree(input)  # _ready() registers the actions


func after_each() -> void:
	for action in DRIVING_ACTIONS:
		Input.action_release(action)


func test_all_actions_are_registered() -> void:
	for action in DRIVING_ACTIONS + [InputActions.RESET_CAR, InputActions.TOGGLE_TELEMETRY, InputActions.TOGGLE_RECORDING]:
		assert_true(InputMap.has_action(action), str(action))


func test_register_is_safe_to_call_twice() -> void:
	InputActions.register()
	assert_eq(InputMap.action_get_events(InputActions.THROTTLE).size(), 3)


func test_keyboard_throttle() -> void:
	Input.action_press(InputActions.THROTTLE)
	input.refresh()
	assert_almost_eq(input.throttle, 1.0, 0.0001)


func test_steer_left_is_negative() -> void:
	Input.action_press(InputActions.STEER_LEFT)
	input.refresh()
	assert_almost_eq(input.steer, -1.0, 0.0001)


func test_virtual_inputs_are_used() -> void:
	input.virtual_throttle = 0.6
	input.virtual_brake = 0.3
	input.virtual_steer = 0.5
	input.refresh()
	assert_almost_eq(input.throttle, 0.6, 0.0001)
	assert_almost_eq(input.brake, 0.3, 0.0001)
	assert_almost_eq(input.steer, 0.5, 0.0001)


func test_combined_steer_is_clamped() -> void:
	Input.action_press(InputActions.STEER_RIGHT)
	input.virtual_steer = 1.0
	input.refresh()
	assert_almost_eq(input.steer, 1.0, 0.0001)


func test_request_reset_emits_signal() -> void:
	watch_signals(input)
	input.request_reset()
	assert_signal_emitted(input, "reset_requested")
