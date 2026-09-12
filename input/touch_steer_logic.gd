class_name TouchSteerLogic
extends RefCounted
## Pure maths for the two touch steering styles.

enum Mode { ANALOG, BUTTONS }


## Analog: how far the thumb slid sideways from where it touched down (pixels).
## Inside the deadzone -> 0. At full_lock_px or beyond -> +/-1.
static func analog_steer(offset_px: float, full_lock_px: float, deadzone_px: float) -> float:
	var magnitude := absf(offset_px)
	if magnitude <= deadzone_px:
		return 0.0
	return signf(offset_px) * minf((magnitude - deadzone_px) / (full_lock_px - deadzone_px), 1.0)


## Buttons: steer ramps toward the held side and recentres when released.
## Holding both sides (or neither) recentres.
static func button_steer(current: float, left_held: bool, right_held: bool,
		ramp_per_second: float, return_per_second: float, delta: float) -> float:
	var target := 0.0
	if left_held != right_held:
		target = -1.0 if left_held else 1.0
	var rate := ramp_per_second if target != 0.0 else return_per_second
	return move_toward(current, target, rate * delta)
