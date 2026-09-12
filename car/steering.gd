class_name Steering
extends RefCounted
## Turns steering input into a front-wheel angle. The lock shrinks with speed and
## the wheels turn at a limited rate, so the car can't snap sideways.

var stats: CarStats
## Current front-wheel angle in radians. + = right.
var angle: float = 0.0


func _init(car_stats: CarStats) -> void:
	stats = car_stats


## Largest wheel angle (radians) worth using at a given speed (m/s): the angle
## that turns the car on its tightest grip-limited arc, plus the slip angle the
## tire needs to make that turn. More lock than this only ploughs the front
## tires, which is why full-lock touch steering felt understeery.
static func max_angle_for_speed(speed: float, car_stats: CarStats) -> float:
	var grip_accel := car_stats.tire_grip * 9.8
	var geometric := atan(car_stats.wheelbase * grip_accel / maxf(speed * speed, 1.0))
	var useful := geometric + deg_to_rad(car_stats.peak_slip_angle_deg) * car_stats.steer_assist_slip
	return minf(deg_to_rad(car_stats.max_steer_deg), useful)


## steer_input: -1 (full left) .. 1 (full right). Returns the new angle.
func update(delta: float, steer_input: float, speed: float) -> float:
	var target := clampf(steer_input, -1.0, 1.0) * max_angle_for_speed(speed, stats)
	angle = move_toward(angle, target, deg_to_rad(stats.steer_rate_deg) * delta)
	return angle
