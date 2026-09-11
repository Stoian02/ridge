class_name TireModel
extends RefCounted
## Pure tire math: no nodes and no state, so every function is easy to test.
##
## A tire only grips when it slips a little. Slip is measured two ways:
##   slip ratio - how much faster (or slower) the tread moves than the ground,
##                along the wheel's heading. + = spinning faster (accelerating).
##   slip angle - the angle between where the wheel points and where it moves.
##                + = the wheel is sliding to its right.
## Each is divided by its "peak" value (the slip where grip is highest), then the
## two are combined into one vector and fed through a single grip curve. Doing it
## this way makes braking/accelerating and cornering share one grip budget (the
## "friction circle"), which is where weight transfer and catchable slides come from.


## Grip as a fraction of the maximum, for a normalised slip (1.0 = at the peak).
## Rises smoothly to 1.0 at the peak, then fades to slide_grip at 3x the peak and
## stays there. The sign of the slip is ignored.
static func grip_curve(normalized_slip: float, slide_grip: float) -> float:
	var s := absf(normalized_slip)
	if s <= 1.0:
		return s * (2.0 - s)
	var fade := clampf((s - 1.0) / 2.0, 0.0, 1.0)
	return lerpf(1.0, slide_grip, fade)


## Longitudinal slip ratio. The ground speed is floored at min_reference_speed so
## the ratio stays finite when the car is nearly stopped.
static func slip_ratio(tread_speed: float, ground_speed: float, min_reference_speed: float) -> float:
	var reference := maxf(absf(ground_speed), min_reference_speed)
	return (tread_speed - ground_speed) / reference


## Slip angle in radians, from the contact patch velocity split into the part
## along the wheel heading and the part across it (+ = moving to the right).
static func slip_angle(forward_speed: float, sideways_speed: float, min_reference_speed: float) -> float:
	return atan2(sideways_speed, maxf(absf(forward_speed), min_reference_speed))


## Tire force in the contact patch frame:
##   x = along the wheel heading (+ = forward), y = across it (+ = right).
## grip_force: the most force this tire can make right now (friction x load).
static func contact_force(ratio: float, angle: float, grip_force: float,
		peak_ratio: float, peak_angle: float, slide_grip: float) -> Vector2:
	var slip := Vector2(ratio / peak_ratio, angle / peak_angle)
	var amount := slip.length()
	if amount < 0.000001:
		return Vector2.ZERO
	var direction := slip / amount
	var force := grip_curve(amount, slide_grip) * grip_force
	# Longitudinal force pushes along the slip; lateral force pushes against it.
	return Vector2(direction.x * force, -direction.y * force)


## Largest longitudinal force that will not overshoot within one tick, i.e. will
## not flip the sign of the slip speed (tread speed - ground speed). Without this
## limit the explicit integration jitters violently at low speed.
## wheel_held: true when the brake holds the wheel still, so the tire force can
## only change the car's speed, not the wheel's.
static func max_longitudinal_force(slip_speed: float, wheel_radius: float, wheel_inertia: float,
		corner_mass: float, wheel_held: bool, delta: float) -> float:
	var compliance := 1.0 / corner_mass
	if not wheel_held:
		compliance += wheel_radius * wheel_radius / wheel_inertia
	return absf(slip_speed) / (compliance * delta)


## Largest lateral force that will not overshoot within one tick: the force that
## would exactly cancel this corner's sideways speed.
static func max_lateral_force(sideways_speed: float, corner_mass: float, delta: float) -> float:
	return absf(sideways_speed) * corner_mass / delta
