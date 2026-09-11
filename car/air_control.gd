class_name AirControl
extends RefCounted
## Lets the player adjust the car's attitude, but only when it is fully airborne:
## all four wheels off the ground for at least airborne_grace seconds (so small
## bumps don't count). Gas pitches the nose up, brake pitches it down, and
## steering rolls the car (GTA-style).

var stats: CarStats
var airborne_time: float = 0.0
var is_active: bool = false


func _init(car_stats: CarStats) -> void:
	stats = car_stats


func reset() -> void:
	airborne_time = 0.0
	is_active = false


## wheels_in_contact: how many wheels touched the ground this tick.
func update(delta: float, wheels_in_contact: int) -> void:
	if wheels_in_contact > 0:
		airborne_time = 0.0
	else:
		airborne_time += delta
	is_active = airborne_time >= stats.airborne_grace


## Torque in the car's local frame: x = pitch (+ = nose up), z = roll
## (+ = left side down). Zero unless air control is active.
func local_torque(throttle: float, brake: float, steer: float) -> Vector3:
	if not is_active:
		return Vector3.ZERO
	var pitch := (throttle - brake) * stats.air_pitch_torque
	var roll := -steer * stats.air_roll_torque
	return Vector3(pitch, 0.0, roll)
