class_name Drivetrain
extends RefCounted
## Engine, automatic gearbox, reverse logic, traction control and torque split.
## Knows nothing about nodes: each tick the car feeds it pedal inputs and wheel
## state, then reads back drive_torque, brake_input, gear and rpm.

const RPM_PER_RAD_PER_SEC := 60.0 / TAU

var stats: CarStats
## -1 = reverse, 1..N = forward gears.
var gear: int = 1
var rpm: float = 0.0
## Total torque at the driven wheels this tick (Nm, + = forward).
var drive_torque: float = 0.0
## Brake demand 0..1 after reverse handling and auto-hold.
var brake_input: float = 0.0

var _shift_timer: float = 0.0


func _init(car_stats: CarStats) -> void:
	stats = car_stats
	reset()


func reset() -> void:
	gear = 1
	rpm = stats.idle_rpm
	drive_torque = 0.0
	brake_input = 0.0
	_shift_timer = 0.0


func is_shifting() -> bool:
	return _shift_timer > 0.0


## Engine torque (Nm) at an rpm: linear between curve points, flat beyond the ends.
static func torque_at(engine_rpm: float, rpm_points: PackedFloat32Array, torque_points: PackedFloat32Array) -> float:
	if engine_rpm <= rpm_points[0]:
		return torque_points[0]
	for i in range(1, rpm_points.size()):
		if engine_rpm <= rpm_points[i]:
			var t := inverse_lerp(rpm_points[i - 1], rpm_points[i], engine_rpm)
			return lerpf(torque_points[i - 1], torque_points[i], t)
	return torque_points[torque_points.size() - 1]


## Traction control: the share of engine torque to keep when the driven wheels
## slip by driven_slip. Full torque up to target_slip, then fading to a 20%
## floor at twice the target.
static func traction_factor(driven_slip: float, target_slip: float, enabled: bool) -> float:
	if not enabled or driven_slip <= target_slip:
		return 1.0
	return clampf(1.0 - (driven_slip - target_slip) / target_slip, 0.2, 1.0)


## Ratio from engine to wheels in the current gear, including the final drive.
## Negative in reverse.
func overall_ratio() -> float:
	if gear < 0:
		return -stats.reverse_ratio * stats.final_drive
	return stats.gear_ratios[gear - 1] * stats.final_drive


## Advance one tick.
## throttle, brake: raw pedals 0..1.
## driven_wheel_speed: average spin of the driven wheels (rad/s, + = forward).
## forward_speed: car speed along its heading (m/s, + = forward).
## driven_slip: largest slip ratio (absolute) among the driven wheels.
func update(delta: float, throttle: float, brake: float, driven_wheel_speed: float,
		forward_speed: float, driven_slip: float) -> void:
	_choose_direction(throttle, brake, forward_speed)
	# In reverse the pedals swap roles: brake drives backwards, gas brakes.
	var gas := throttle if gear > 0 else brake
	brake_input = brake if gear > 0 else throttle
	if throttle == 0.0 and brake == 0.0 and absf(forward_speed) < stats.auto_hold_speed:
		brake_input = 1.0

	var ratio := overall_ratio()
	var wheel_rpm := absf(driven_wheel_speed * ratio) * RPM_PER_RAD_PER_SEC
	# Simulated clutch slip: at low speed the engine can rev above what the wheels
	# allow, so the car pulls away with useful torque.
	var clutch_rpm := lerpf(stats.idle_rpm, stats.launch_rpm, gas)
	rpm = clampf(maxf(wheel_rpm, clutch_rpm), stats.idle_rpm, stats.redline_rpm)

	if gear > 0:
		# Shift on road speed, not wheel spin, so wheelspin can't make the box hunt.
		var road_rpm := absf(forward_speed) / stats.wheel_radius * absf(ratio) * RPM_PER_RAD_PER_SEC
		_auto_shift(road_rpm)
	if _shift_timer > 0.0:
		_shift_timer -= delta
		drive_torque = 0.0
		return

	var engine_torque := 0.0
	if gas > 0.0:
		if wheel_rpm < stats.redline_rpm:  # rev limiter
			engine_torque = gas * torque_at(rpm, stats.torque_curve_rpm, stats.torque_curve_nm) \
					* traction_factor(driven_slip, stats.traction_slip_target, stats.traction_control)
	else:
		# Engine braking resists the direction the wheels are turning.
		engine_torque = -stats.engine_braking_nm * (rpm / stats.redline_rpm) \
				* signf(driven_wheel_speed) * signf(ratio)
	drive_torque = engine_torque * ratio * stats.drivetrain_efficiency


## Splits total drive torque over the wheels, ordered [FL, FR, RL, RR].
## Each axle shares its torque equally left/right (a simple open differential).
static func split_torque(total: float, drive_type: CarStats.DriveType, front_split: float) -> PackedFloat32Array:
	var front := 0.0
	match drive_type:
		CarStats.DriveType.FWD:
			front = total
		CarStats.DriveType.RWD:
			front = 0.0
		CarStats.DriveType.AWD:
			front = total * front_split
	var rear := total - front
	return PackedFloat32Array([front * 0.5, front * 0.5, rear * 0.5, rear * 0.5])


## Splits total brake torque over the wheels, ordered [FL, FR, RL, RR].
static func split_brake(total: float, front_bias: float) -> PackedFloat32Array:
	var front := total * front_bias
	var rear := total - front
	return PackedFloat32Array([front * 0.5, front * 0.5, rear * 0.5, rear * 0.5])


func _choose_direction(throttle: float, brake: float, forward_speed: float) -> void:
	if absf(forward_speed) > stats.direction_change_speed:
		return
	if gear > 0 and brake > 0.0 and throttle == 0.0:
		gear = -1
	elif gear < 0 and throttle > 0.0 and brake == 0.0:
		gear = 1


func _auto_shift(road_rpm: float) -> void:
	if _shift_timer > 0.0:
		return
	if road_rpm > stats.upshift_rpm and gear < stats.gear_ratios.size():
		gear += 1
		_shift_timer = stats.shift_time
	elif road_rpm < stats.downshift_rpm and gear > 1:
		gear -= 1
		_shift_timer = stats.shift_time
