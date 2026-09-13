class_name FlipDetector
extends RefCounted
## Decides when a car is stuck flipped: tilted more than TILT_LIMIT_DEG from
## upright and slower than SPEED_LIMIT, continuously for HOLD_SECONDS.
## Wheel contact is deliberately ignored: a car on its side often has a wheel
## touching. These are fixed game rules from the spec (§3.2).

const TILT_LIMIT_DEG := 70.0
const SPEED_LIMIT := 2.0
const HOLD_SECONDS := 2.0

var flipped_time: float = 0.0


## up: the car's global up vector; speed: m/s. Returns true once the car has
## been flipped for HOLD_SECONDS.
func update(delta: float, up: Vector3, speed: float) -> bool:
	var tilt := rad_to_deg(up.angle_to(Vector3.UP))
	if tilt > TILT_LIMIT_DEG and absf(speed) < SPEED_LIMIT:
		flipped_time += delta
	else:
		flipped_time = 0.0
	return flipped_time >= HOLD_SECONDS


func reset() -> void:
	flipped_time = 0.0
