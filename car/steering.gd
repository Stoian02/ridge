class_name Steering
extends RefCounted
## Turns steering input into a front-wheel angle. The lock shrinks with speed and
## the wheels turn at a limited rate, so the car can't snap sideways.

var stats: CarStats
## Current front-wheel angle in radians. + = right.
var angle: float = 0.0


func _init(car_stats: CarStats) -> void:
	stats = car_stats


## Largest wheel angle (radians) allowed at a given speed (m/s).
static func max_angle_for_speed(speed: float, car_stats: CarStats) -> float:
	var t := clampf(absf(speed) / car_stats.steer_limit_speed, 0.0, 1.0)
	return deg_to_rad(lerpf(car_stats.max_steer_deg, car_stats.min_steer_deg, t))


## steer_input: -1 (full left) .. 1 (full right). Returns the new angle.
func update(delta: float, steer_input: float, speed: float) -> float:
	var target := clampf(steer_input, -1.0, 1.0) * max_angle_for_speed(speed, stats)
	angle = move_toward(angle, target, deg_to_rad(stats.steer_rate_deg) * delta)
	return angle
