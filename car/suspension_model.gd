class_name SuspensionModel
extends RefCounted
## Pure suspension math. "Compression" is how far the spring is squeezed from
## fully extended, in metres (0 = wheel hanging at full droop).


## Spring + damper force pushing the car up. Never negative: a suspension can push
## the car away from the ground but can't pull it down onto it.
## compression_speed: m/s, + while compressing.
static func spring_damper_force(compression: float, compression_speed: float, stiffness: float,
		compress_damping: float, rebound_damping: float) -> float:
	var damping := compress_damping if compression_speed > 0.0 else rebound_damping
	return maxf(0.0, compression * stiffness + compression_speed * damping)


## A very stiff extra spring over the last 15% of travel, so a hard landing can't
## drive the wheel up through the body.
static func bump_stop_force(compression: float, travel: float, stiffness: float) -> float:
	var start := travel * 0.85
	return maxf(0.0, compression - start) * stiffness


## Anti-roll bar: pushes the more compressed side up and the other side down by the
## same amount. Returns the force for the LEFT wheel; the right wheel gets the negative.
static func anti_roll_force(left_compression: float, right_compression: float, stiffness: float) -> float:
	return (left_compression - right_compression) * stiffness
