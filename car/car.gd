class_name Car
extends RigidBody3D
## The drivable car: one rigid body with four raycast wheels.
## Every physics tick: read input -> steering and drivetrain -> wheels -> forces.

@export var stats: CarStats
@export var grip_table: GripTable

@onready var input: CarInput = $CarInput
## Always ordered front-left, front-right, rear-left, rear-right.
@onready var wheels: Array[Wheel] = [$WheelFL, $WheelFR, $WheelRL, $WheelRR]

var steering: Steering
var drivetrain: Drivetrain
var air_control: AirControl


func _ready() -> void:
	_apply_stats()
	for wheel in wheels:
		wheel.setup(stats, grip_table, self)
	steering = Steering.new(stats)
	drivetrain = Drivetrain.new(stats)
	air_control = AirControl.new(stats)


func _physics_process(delta: float) -> void:
	input.refresh()
	var speed := forward_speed()

	var angle := steering.update(delta, input.steer, speed)
	wheels[0].steer_angle = angle
	wheels[1].steer_angle = angle

	drivetrain.update(delta, input.throttle, input.brake, _driven_wheel_speed(), speed, _driven_slip())
	var drive := Drivetrain.split_torque(drivetrain.drive_torque, stats.drive_type, stats.front_torque_split)
	drive = _apply_diff_locks(drive, delta)
	var brakes := Drivetrain.split_brake(drivetrain.brake_input * stats.brake_torque, stats.brake_front_bias)

	var wheels_in_contact := 0
	for i in wheels.size():
		wheels[i].drive_torque = drive[i]
		wheels[i].brake_torque = brakes[i]
		wheels[i].update_contact(delta)
		if wheels[i].in_contact:
			wheels_in_contact += 1

	var front_bar := SuspensionModel.anti_roll_force(wheels[0].compression, wheels[1].compression, stats.anti_roll_front)
	var rear_bar := SuspensionModel.anti_roll_force(wheels[2].compression, wheels[3].compression, stats.anti_roll_rear)
	var anti_roll := [front_bar, -front_bar, rear_bar, -rear_bar]
	for i in wheels.size():
		var force := wheels[i].compute_force(delta, anti_roll[i], self)
		if wheels[i].in_contact:
			apply_force(force, wheels[i].contact_point - global_position)
		wheels[i].update_visual(delta)

	air_control.update(delta, wheels_in_contact)
	var air_torque := air_control.local_torque(input.throttle, input.brake, input.steer)
	apply_torque(global_basis * air_torque)

	apply_central_force(-linear_velocity * linear_velocity.length() * stats.aero_drag)


## Speed along the car's heading in m/s (+ = forward).
func forward_speed() -> float:
	return linear_velocity.dot(-global_basis.z)


## Teleports the car, upright and stopped, to a new transform.
func reset_to(target: Transform3D) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = target
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, target)
	for wheel in wheels:
		wheel.reset()
	steering.angle = 0.0
	drivetrain.reset()
	air_control.reset()


## Snapshot for the telemetry overlay and the run recorder.
func get_telemetry() -> Dictionary:
	var wheel_data: Array[Dictionary] = []
	for wheel in wheels:
		wheel_data.append({
			"contact": wheel.in_contact,
			"surface": wheel.surface.id if wheel.surface != null else &"air",
			"load": wheel.tire_load,
			"compression": wheel.compression,
			"slip_ratio": wheel.slip_ratio,
			"slip_angle_deg": rad_to_deg(wheel.slip_angle),
			"spin": wheel.spin_speed,
		})
	return {
		"speed_kmh": forward_speed() * 3.6,
		"rpm": drivetrain.rpm,
		"gear": drivetrain.gear,
		"throttle": input.throttle,
		"brake": input.brake,
		"steer": input.steer,
		"airborne": air_control.is_active,
		"position": global_position,
		"rotation_deg": global_rotation_degrees,
		"wheels": wheel_data,
	}


func _apply_stats() -> void:
	mass = stats.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = stats.center_of_mass
	inertia = stats.inertia

	var body_box := BoxShape3D.new()
	body_box.size = stats.body_size
	$BodyShape.shape = body_box

	var body_mesh := BoxMesh.new()
	body_mesh.size = stats.body_size
	$BodyMesh.mesh = body_mesh

	# Gray-box cabin, set back a little so the front of the car is obvious.
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(stats.body_size.x * 0.85, stats.body_size.y * 0.8, stats.body_size.z * 0.45)
	$CabinMesh.mesh = cabin_mesh
	$CabinMesh.position = Vector3(0.0, (stats.body_size.y + cabin_mesh.size.y) * 0.5, stats.body_size.z * 0.08)


## Moves drive torque between the wheels each differential lock ties together
## (spec §4.1): left and right on a driven axle, and front and rear on AWD. With
## every lock at 0 the torques come back unchanged.
func _apply_diff_locks(drive: PackedFloat32Array, delta: float) -> PackedFloat32Array:
	var limit := stats.diff_lock_max_torque
	var inertia := stats.wheel_inertia
	var axle_locks: Array[float] = [stats.front_diff_lock, stats.rear_diff_lock]
	for axle in 2:
		var left := axle * 2
		if axle_locks[axle] <= 0.0 or not _is_driven(left):
			continue
		var transfer := Drivetrain.lock_transfer(wheels[left].spin_speed, wheels[left + 1].spin_speed,
				axle_locks[axle], limit, inertia, delta)
		drive[left] -= transfer
		drive[left + 1] += transfer
	if stats.drive_type == CarStats.DriveType.AWD and stats.centre_diff_lock > 0.0:
		var front := (wheels[0].spin_speed + wheels[1].spin_speed) * 0.5
		var rear := (wheels[2].spin_speed + wheels[3].spin_speed) * 0.5
		# Each axle is two wheels: twice the inertia, and its torque shared between them.
		var transfer := Drivetrain.lock_transfer(front, rear, stats.centre_diff_lock, limit, inertia * 2.0, delta) * 0.5
		drive[0] -= transfer
		drive[1] -= transfer
		drive[2] += transfer
		drive[3] += transfer
	return drive


func _is_driven(wheel_index: int) -> bool:
	match stats.drive_type:
		CarStats.DriveType.FWD:
			return wheel_index < 2
		CarStats.DriveType.RWD:
			return wheel_index >= 2
		_:
			return true


func _driven_wheel_speed() -> float:
	var total := 0.0
	var count := 0
	for i in wheels.size():
		if _is_driven(i):
			total += wheels[i].spin_speed
			count += 1
	return total / count


## Largest slip among the driven wheels last tick, for traction control.
func _driven_slip() -> float:
	var slip := 0.0
	for i in wheels.size():
		if _is_driven(i):
			slip = maxf(slip, absf(wheels[i].slip_ratio))
	return slip
