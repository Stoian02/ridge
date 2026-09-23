class_name WaterForces
extends RefCounted
## Pure bounded force maths. One accumulator covers EVERY body/wheel drag axis.

var force: Vector3 = Vector3.ZERO
var torque: Vector3 = Vector3.ZERO
var damping_scale: float = 1.0
var _inverse_mass: float = 0.0
var _inverse_inertia: Basis = Basis.IDENTITY
var _mobility_sum: float = 0.0


static func sphere_cap_fraction(plane_y: float, center_y: float, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	var h := clampf(plane_y - center_y + radius, 0.0, 2.0 * radius)
	return h * h * (3.0 * radius - h) / (4.0 * radius * radius * radius)


static func probe_fraction(center_y: float, radius: float, surface_y: float,
		bed_y: float, edge_weight: float = 1.0) -> float:
	if bed_y >= surface_y:
		return 0.0
	return clampf((sphere_cap_fraction(surface_y, center_y, radius) \
			- sphere_cap_fraction(bed_y, center_y, radius)) * edge_weight, 0.0, 1.0)


static func wheel_fraction(center_y: float, extent: float, surface_y: float,
		bed_y: float, edge_weight: float = 1.0) -> float:
	if extent <= 0.0 or bed_y >= surface_y:
		return 0.0
	var submerged := minf(center_y + extent, surface_y) - maxf(center_y - extent, bed_y)
	return clampf(submerged / (2.0 * extent) * edge_weight, 0.0, 1.0)


static func probe_positions(body_size: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	for height: float in [-0.20, 0.40]:
		for side: float in [-0.35, 0.35]:
			for along: float in [-0.32, 0.32]:
				result.append(Vector3(side * body_size.x, height * body_size.y, along * body_size.z))
	return result


## X = horizontal right, Y = world up, Z = horizontal forward (not body up).
static func drag_axes(car_basis: Basis) -> Basis:
	var forward := -car_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		var right := car_basis.x
		right.y = 0.0
		forward = Vector3.UP.cross(right)
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	return Basis(forward.cross(Vector3.UP), Vector3.UP, forward)


func begin(inverse_mass: float, inverse_inertia: Basis) -> void:
	force = Vector3.ZERO
	torque = Vector3.ZERO
	damping_scale = 1.0
	_mobility_sum = 0.0
	_inverse_mass = inverse_mass
	_inverse_inertia = inverse_inertia


func add_axis(direction: Vector3, speed: float, arm: Vector3,
		linear: float, quadratic: float, wetness: float) -> void:
	var damping := maxf(0.0, wetness) * (maxf(0.0, linear) + maxf(0.0, quadratic) * absf(speed))
	var axis_torque := arm.cross(direction)
	var axis_force := direction * (-damping * speed)
	force += axis_force
	torque += arm.cross(axis_force)
	_mobility_sum += damping * (_inverse_mass + axis_torque.dot(_inverse_inertia * axis_torque))


## M^-1/2 D M^-1/2 is positive semidefinite; its trace bounds its largest
## eigenvalue. Scaling by this GLOBAL bound keeps all damping eigenvalues in
## [0, 1] per tick: no combined-probe overshoot or still-water energy creation.
## Current is the relative-velocity source; there is no extra current shove.
func finish(delta: float) -> void:
	damping_scale = 1.0 / maxf(1.0, delta * _mobility_sum)
	force *= damping_scale
	torque *= damping_scale
