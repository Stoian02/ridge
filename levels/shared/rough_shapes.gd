class_name RoughShapes
extends RefCounted
## Shape functions for uneven ground, shared by RoughPatch (the Test Ground's
## strips) and RoadProfile (trails). Each returns a height offset in metres.


## Bowl-shaped pothole: -depth at the centre, rising to 0 at the radius.
static func pothole(distance_from_centre: float, radius: float, depth: float) -> float:
	if distance_from_centre >= radius:
		return 0.0
	var t := distance_from_centre / radius
	return -depth * (1.0 - t * t)


## Speed bump across the road: +height on its centre line, 0 at half its length.
static func bump(distance_from_centre: float, length: float, height: float) -> float:
	var t := absf(distance_from_centre) / (length * 0.5)
	if t >= 1.0:
		return 0.0
	return height * (0.5 + 0.5 * cos(PI * t))


## Washboard ripples along the road.
static func washboard(along: float, amplitude: float, wavelength: float) -> float:
	return amplitude * sin(TAU * along / wavelength)


## Rut: a rounded groove, -depth on its centre line, 0 at half_width.
static func rut(distance_from_centre: float, half_width: float, depth: float) -> float:
	var t := absf(distance_from_centre) / half_width
	if t >= 1.0:
		return 0.0
	return -depth * (0.5 + 0.5 * cos(PI * t))
