class_name TouchControls
extends CanvasLayer
## On-screen driving controls for phones (also usable with a mouse on desktop,
## because the project emulates touch from the mouse).
##   Left side:  steering - an analog drag zone, or two buttons.
##   Right side: brake and gas pedals.
##   Top strip:  steering-style toggle, reset, telemetry and recording.
## Writes into the car's CarInput virtual_* values.
## Coordinates are in the 1920x1080 canvas (the project stretches it to the screen).

signal telemetry_toggled
signal recording_toggled

## Touches above this line belong to the top-strip buttons, not the driving controls.
const TOP_STRIP_HEIGHT := 150.0
## Fraction of the screen width, from the left, used for analog steering.
const STEER_ZONE_WIDTH := 0.45
const FULL_LOCK_PX := 140.0
const DEADZONE_PX := 12.0
## Button steering: how fast the value ramps in and recentres (units per second).
const BUTTON_RAMP := 3.0
const BUTTON_RETURN := 5.0

@export var car_input: CarInput
var steer_mode: TouchSteerLogic.Mode = TouchSteerLogic.Mode.ANALOG
## Tests set this so the layout doesn't depend on the real window size.
var screen_size_override := Vector2.ZERO

var _touches := {}             # touch index -> current position
var _steer_touch := -1         # finger doing analog steering, or -1
var _steer_origin := Vector2.ZERO
var _button_steer := 0.0
var _canvas: Control
var _mode_button: Button


func _ready() -> void:
	_build_ui()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		handle_touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		handle_drag(event.index, event.position)


func _process(delta: float) -> void:
	update_outputs(delta)
	_canvas.queue_redraw()


func handle_touch(index: int, point: Vector2, pressed: bool) -> void:
	if not pressed:
		_touches.erase(index)
		if index == _steer_touch:
			_steer_touch = -1
		return
	if point.y < TOP_STRIP_HEIGHT:
		return
	_touches[index] = point
	var in_steer_zone := point.x < screen_size().x * STEER_ZONE_WIDTH
	if steer_mode == TouchSteerLogic.Mode.ANALOG and _steer_touch == -1 and in_steer_zone:
		_steer_touch = index
		_steer_origin = point


func handle_drag(index: int, point: Vector2) -> void:
	if _touches.has(index):
		_touches[index] = point


## Recomputes pedal and steer values from the current touches.
func update_outputs(delta: float) -> void:
	if car_input == null:
		return
	car_input.virtual_throttle = 1.0 if _any_touch_in(gas_rect()) else 0.0
	car_input.virtual_brake = 1.0 if _any_touch_in(brake_rect()) else 0.0
	car_input.virtual_steer = _current_steer(delta)


func screen_size() -> Vector2:
	if screen_size_override != Vector2.ZERO:
		return screen_size_override
	return _canvas.get_viewport_rect().size


func gas_rect() -> Rect2:
	var size := screen_size()
	return Rect2(size.x - 290.0, size.y - 380.0, 250.0, 340.0)


func brake_rect() -> Rect2:
	var size := screen_size()
	return Rect2(size.x - 570.0, size.y - 300.0, 250.0, 260.0)


func left_button_rect() -> Rect2:
	return Rect2(40.0, screen_size().y - 300.0, 230.0, 260.0)


func right_button_rect() -> Rect2:
	return Rect2(300.0, screen_size().y - 300.0, 230.0, 260.0)


func _current_steer(delta: float) -> float:
	if steer_mode == TouchSteerLogic.Mode.ANALOG:
		if _steer_touch == -1:
			return 0.0
		var offset: float = _touches[_steer_touch].x - _steer_origin.x
		return TouchSteerLogic.analog_steer(offset, FULL_LOCK_PX, DEADZONE_PX)
	_button_steer = TouchSteerLogic.button_steer(_button_steer,
			_any_touch_in(left_button_rect()), _any_touch_in(right_button_rect()),
			BUTTON_RAMP, BUTTON_RETURN, delta)
	return _button_steer


func _any_touch_in(rect: Rect2) -> bool:
	for point in _touches.values():
		if rect.has_point(point):
			return true
	return false


func _toggle_steer_mode() -> void:
	if steer_mode == TouchSteerLogic.Mode.ANALOG:
		steer_mode = TouchSteerLogic.Mode.BUTTONS
	else:
		steer_mode = TouchSteerLogic.Mode.ANALOG
	_steer_touch = -1
	_button_steer = 0.0
	_update_mode_label()


func _update_mode_label() -> void:
	var label := "Analog" if steer_mode == TouchSteerLogic.Mode.ANALOG else "Buttons"
	_mode_button.text = "Steer: %s" % label


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)

	var bar := HBoxContainer.new()
	bar.position = Vector2(20.0, 20.0)
	bar.add_theme_constant_override("separation", 16)
	add_child(bar)
	_mode_button = _add_button(bar, "", _toggle_steer_mode)
	_add_button(bar, "Reset", _on_reset_pressed)
	_add_button(bar, "Telemetry", telemetry_toggled.emit)
	_add_button(bar, "Rec", recording_toggled.emit)
	_update_mode_label()


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(230.0, 100.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 34)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_reset_pressed() -> void:
	if car_input != null:
		car_input.request_reset()


func _draw_controls() -> void:
	var throttle_on := car_input != null and car_input.virtual_throttle > 0.0
	var brake_on := car_input != null and car_input.virtual_brake > 0.0
	_draw_pad(gas_rect(), "GAS", throttle_on)
	_draw_pad(brake_rect(), "BRAKE", brake_on)
	if steer_mode == TouchSteerLogic.Mode.BUTTONS:
		_draw_pad(left_button_rect(), "<", _any_touch_in(left_button_rect()))
		_draw_pad(right_button_rect(), ">", _any_touch_in(right_button_rect()))
	elif _steer_touch != -1:
		var thumb: Vector2 = _touches[_steer_touch]
		_canvas.draw_circle(_steer_origin, FULL_LOCK_PX, Color(1.0, 1.0, 1.0, 0.08))
		_canvas.draw_circle(Vector2(thumb.x, _steer_origin.y), 40.0, Color(1.0, 1.0, 1.0, 0.35))


func _draw_pad(rect: Rect2, label: String, pressed: bool) -> void:
	_canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.3 if pressed else 0.12))
	_canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(24.0, 64.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 44)
