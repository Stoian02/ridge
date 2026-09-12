class_name InputActions
extends RefCounted
## The game's input actions, registered in code so project.godot stays readable.
## Desktop: WASD / arrow keys, R reset, F1 telemetry, F2 record.
## Gamepad: triggers for gas/brake, left stick to steer, Y reset, Back telemetry.

const THROTTLE := &"throttle"
const BRAKE := &"brake"
const STEER_LEFT := &"steer_left"
const STEER_RIGHT := &"steer_right"
const RESET_CAR := &"reset_car"
const TOGGLE_TELEMETRY := &"toggle_telemetry"
const TOGGLE_RECORDING := &"toggle_recording"

const DEADZONE := 0.15


## Adds any missing actions. Safe to call more than once.
static func register() -> void:
	_add(THROTTLE, [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_add(BRAKE, [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add(STEER_LEFT, [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add(STEER_RIGHT, [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add(RESET_CAR, [_key(KEY_R), _joy_button(JOY_BUTTON_Y)])
	_add(TOGGLE_TELEMETRY, [_key(KEY_F1), _joy_button(JOY_BUTTON_BACK)])
	_add(TOGGLE_RECORDING, [_key(KEY_F2)])


static func _add(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, DEADZONE)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _joy_axis(axis: JoyAxis, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	return event


static func _joy_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
