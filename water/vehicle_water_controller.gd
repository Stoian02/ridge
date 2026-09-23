class_name VehicleWaterController
extends RefCounted
## Car-owned, explicitly stepped water layer. No node processing or global lookup.

var state := VehicleWaterState.new()
var world: WaterWorld
var profile: VehicleWaterProfile
var body_samples: Array[WaterSample] = []
var wheel_samples: Array[WaterSample] = []
var intake_sample := WaterSample.new()
var body_wetness := PackedFloat32Array()
var wheel_wetness := PackedFloat32Array()
var body_positions := PackedVector3Array()
var wheel_positions := PackedVector3Array()
var wheel_extents := PackedFloat32Array()
var intake_world_position: Vector3 = Vector3.ZERO
var probe_radius: float = 0.0
var wet_body: bool = false
var current_velocity: Vector3 = Vector3.ZERO
var relative_speed: float = 0.0
var drag_force: Vector3 = Vector3.ZERO
var drag_torque: Vector3 = Vector3.ZERO
var buoyancy_force: Vector3 = Vector3.ZERO
var buoyancy_torque: Vector3 = Vector3.ZERO
var water_time_usec: int = 0
var reset_serial: int = 0

var _car: Car
var _local_probes := PackedVector3Array()
var _drag := WaterForces.new()
var _gravity: float = 9.8
var _current_sum: Vector3 = Vector3.ZERO
var _current_weight: float = 0.0


func _init(car: Car) -> void:
	_car = car
	profile = car.stats.water_profile
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_local_probes = WaterForces.probe_positions(car.stats.body_size)
	probe_radius = car.stats.body_size.y * 0.30
	for index in 8:
		body_samples.append(WaterSample.new())
	for index in 4:
		wheel_samples.append(WaterSample.new())
	body_wetness.resize(8)
	wheel_wetness.resize(4)
	body_positions.resize(8)
	wheel_positions.resize(4)
	wheel_extents.resize(4)


func set_world(value: WaterWorld) -> void:
	world = value
	reset()


func enabled() -> bool:
	return world != null and profile != null


func reset() -> void:
	state.reset()
	for sample in body_samples:
		sample.clear()
	for sample in wheel_samples:
		sample.clear()
	intake_sample.clear()
	body_wetness.fill(0.0)
	wheel_wetness.fill(0.0)
	wet_body = false
	current_velocity = Vector3.ZERO
	relative_speed = 0.0
	drag_force = Vector3.ZERO
	drag_torque = Vector3.ZERO
	buoyancy_force = Vector3.ZERO
	buoyancy_torque = Vector3.ZERO
	water_time_usec = 0
	reset_serial += 1


## Before drivetrain: an intake crossing cannot leave one tick of engine drive.
func sample_body(delta: float) -> void:
	if not enabled():
		return
	var started := Time.get_ticks_usec()
	var immersion := 0.0
	wet_body = false
	_current_sum = Vector3.ZERO
	_current_weight = 0.0
	for index in 8:
		var point := _car.global_transform * _local_probes[index]
		body_positions[index] = point
		var sample := body_samples[index]
		world.sample(point, sample, probe_radius)
		var fraction := 0.0
		if sample.valid:
			fraction = WaterForces.probe_fraction(point.y, probe_radius, sample.surface_y, sample.bed_y, sample.edge_weight)
		body_wetness[index] = fraction
		immersion += fraction / 8.0
		wet_body = wet_body or fraction > 0.01
		_current_sum += sample.current * fraction
		_current_weight += fraction
	intake_world_position = _car.global_transform * profile.intake_local_position
	world.sample(intake_world_position, intake_sample)
	var clearance := intake_world_position.y - intake_sample.surface_y
	state.step(delta, profile, immersion, intake_sample.valid, clearance)
	water_time_usec = Time.get_ticks_usec() - started


## Contacts have been refreshed this tick, so suspension extension is current.
## All force contributions are applied together once, before air-control gating.
func sample_wheels_and_apply(delta: float) -> void:
	if not enabled():
		return
	var started := Time.get_ticks_usec()
	var stats := _car.stats
	for index in 4:
		var wheel := _car.wheels[index]
		var point := wheel.global_position - _car.global_basis.y * (stats.suspension_length - wheel.compression)
		wheel_positions[index] = point
		var axle := _car.global_basis.x.rotated(_car.global_basis.y, -wheel.steer_angle)
		var extent := stats.wheel_radius * sqrt(maxf(0.0, 1.0 - axle.y * axle.y)) \
				+ stats.wheel_width * 0.5 * absf(axle.y)
		wheel_extents[index] = extent
		var sample := wheel_samples[index]
		world.sample(point, sample, extent)
		var fraction := 0.0
		if sample.valid:
			fraction = WaterForces.wheel_fraction(point.y, extent, sample.surface_y, sample.bed_y, sample.edge_weight)
		wheel_wetness[index] = fraction
		_current_sum += sample.current * fraction
		_current_weight += fraction
	current_velocity = _current_sum / _current_weight if _current_weight > 0.0 else Vector3.ZERO
	relative_speed = (_car.linear_velocity - current_velocity).length() if _current_weight > 0.0 else 0.0
	_apply_forces(delta)
	water_time_usec += Time.get_ticks_usec() - started


func _apply_forces(delta: float) -> void:
	drag_force = Vector3.ZERO
	drag_torque = Vector3.ZERO
	buoyancy_force = Vector3.ZERO
	buoyancy_torque = Vector3.ZERO
	if _current_weight <= 0.0:
		return
	var physics := PhysicsServer3D.body_get_direct_state(_car.get_rid())
	if physics == null:
		return
	var com := _car.global_position + physics.center_of_mass
	_drag.begin(physics.inverse_mass, physics.inverse_inertia_tensor)
	var axes := WaterForces.drag_axes(_car.global_basis)
	var lift := _car.mass * _gravity * _car.gravity_scale * state.buoyancy_ratio(profile) / 8.0
	for index in 8:
		var fraction := body_wetness[index]
		if fraction <= 0.0:
			continue
		var arm := body_positions[index] - com
		var velocity := _car.linear_velocity + _car.angular_velocity.cross(arm) - body_samples[index].current
		_drag.add_axis(axes.x, velocity.dot(axes.x), arm, profile.body_linear_drag.x, profile.body_quadratic_drag.x, fraction / 8.0)
		_drag.add_axis(Vector3.UP, velocity.y, arm, profile.body_linear_drag.y, profile.body_quadratic_drag.y, fraction / 8.0)
		_drag.add_axis(axes.z, velocity.dot(axes.z), arm, profile.body_linear_drag.z, profile.body_quadratic_drag.z, fraction / 8.0)
		var force := Vector3.UP * lift * fraction
		buoyancy_force += force
		buoyancy_torque += arm.cross(force)
	for index in 4:
		var fraction := wheel_wetness[index]
		if fraction <= 0.0:
			continue
		var arm := wheel_positions[index] - com
		var velocity := _car.linear_velocity + _car.angular_velocity.cross(arm) - wheel_samples[index].current
		_drag.add_axis(axes.x, velocity.dot(axes.x), arm, 0.0, profile.wheel_quadratic_drag, fraction)
		_drag.add_axis(axes.z, velocity.dot(axes.z), arm, 0.0, profile.wheel_quadratic_drag, fraction)
	_drag.finish(delta)
	drag_force = _drag.force
	drag_torque = _drag.torque
	_car.apply_central_force(buoyancy_force + drag_force)
	_car.apply_torque(buoyancy_torque + drag_torque)
