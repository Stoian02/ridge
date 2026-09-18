class_name RoadDamageDef
extends Resource
## Local, progressively broken road. Independent seeds leave the rest of a
## trail unchanged when one section is tuned. All distances and depths are metres.

@export var start: float = 0.0
@export var length: float = 100.0
## Potholes per 100 m at the beginning and end; positions follow this density.
@export var density: Vector2 = Vector2(10.0, 50.0)
@export var radius_range: Vector2 = Vector2(0.45, 1.5)
@export var depth_range: Vector2 = Vector2(0.03, 0.3)
## The upper size/depth limit grows from this fraction to full severity.
@export_range(0.0, 1.0) var initial_severity: float = 0.2
## Optional easing of the depths into the next surface.
@export var end_fade: float = 0.0
@export var seed: int = 1


func end() -> float:
	return start + length


func generate(trail: TrailDef) -> Array[Vector4]:
	var result: Array[Vector4] = []
	if length <= 0.0 or density.x < 0.0 or density.y < 0.0:
		return result
	var count := roundi(length * (density.x + density.y) / 200.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for attempt in count * 12:
		if result.size() >= count:
			break
		# Invert the integral of the linear density: more holes near its busy end.
		var area := rng.randf() * (density.x + density.y) * 0.5
		var denominator := density.x + sqrt(maxf(0.0, density.x * density.x
				+ 2.0 * (density.y - density.x) * area))
		var t := 2.0 * area / maxf(denominator, 0.0001)
		var severity := lerpf(initial_severity, 1.0, t)
		var radius := minf(rng.randf_range(radius_range.x,
				lerpf(radius_range.x, radius_range.y, severity)), length * 0.49)
		var at := clampf(start + t * length, start + radius, end() - radius)
		var limit := maxf(0.0, trail.road_width_at(at) * 0.5 - radius - 0.15)
		var lateral := rng.randf_range(-limit, limit)
		var depth := rng.randf_range(depth_range.x, lerpf(depth_range.x, depth_range.y, severity))
		if end_fade > 0.0:
			depth *= smoothstep(0.0, end_fade, end() - at)
		var hole := Vector4(at, lateral, radius, depth)
		# Allow rims to overlap, but not stacked centres making accidental pits.
		var crowded := false
		for other: Vector4 in result:
			if Vector2(at - other.x, lateral - other.y).length() < (radius + other.z) * 0.7:
				crowded = true
				break
		if not crowded:
			result.append(hole)
	return result
