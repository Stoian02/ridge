class_name WheelMotion
extends RefCounted
## How a wheel moves over the ground, for effects (spec §6.1). It only reads the
## wheel and the car; it never changes them.

## Tyres count as sliding only above this ground speed (m/s).
const SLIDE_MIN_SPEED := 3.0
## Well above traction control's 0.3 target: a full-throttle launch slips 0.2-0.55
## for a couple of seconds, and only clear wheelspin past this counts as a slide.
const SLIDE_SLIP_RATIO := 0.6
const SLIDE_SLIP_ANGLE_DEG := 12.0


## Returns {"in_contact", "ground_speed", "slip_speed", "sliding"} for a wheel of `car`.
static func of(wheel: Wheel, car: Car) -> Dictionary:
	if not wheel.in_contact:
		return motion(false, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, 0.0, 0.0, 0.0)
	var velocity := car.linear_velocity + car.angular_velocity.cross(wheel.contact_point - car.global_position)
	var forward := (-car.global_basis.z).rotated(car.global_basis.y, -wheel.steer_angle)
	return motion(true, velocity, wheel.contact_normal, forward, wheel.spin_speed * wheel.stats.wheel_radius,
			wheel.slip_ratio, wheel.slip_angle)


## The same from plain values. velocity: of the contact point; forward: the wheel's heading;
## tread_speed: spin x radius (m/s); slip_angle in radians.
static func motion(in_contact: bool, velocity: Vector3, normal: Vector3, forward: Vector3, tread_speed: float,
		slip_ratio: float, slip_angle: float) -> Dictionary:
	if not in_contact:
		return {"in_contact": false, "ground_speed": 0.0, "slip_speed": 0.0, "sliding": false}
	var along_ground := velocity - normal * velocity.dot(normal)
	var ground_speed := along_ground.length()
	var heading := (forward - normal * forward.dot(normal)).normalized()
	var slip_speed := absf(tread_speed - along_ground.dot(heading))
	var sliding := ground_speed > SLIDE_MIN_SPEED and (absf(slip_ratio) > SLIDE_SLIP_RATIO
			or absf(slip_angle) > deg_to_rad(SLIDE_SLIP_ANGLE_DEG))
	return {"in_contact": true, "ground_speed": ground_speed, "slip_speed": slip_speed, "sliding": sliding}
