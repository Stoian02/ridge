class_name WaterWaveMath
extends RefCounted
## Pure analytic value/derivatives: Vector3(height, derivative_x, derivative_z).
## Keep equations in lockstep with water_wave_math.gdshaderinc; verify on GPU.


static func pulse(q: float) -> Vector2:
	if absf(q) >= 1.0:
		return Vector2.ZERO
	var t := 1.0 - q * q
	return Vector2(t * t * cos(PI * q),
		-4.0 * q * t * cos(PI * q) - PI * t * t * sin(PI * q))


static func packet(point: Vector2, data: Vector4, direction: Vector4,
		shape: Vector4, envelope: Vector2) -> Vector3:
	var age := data.z
	if data.w == 0.0 or age < 0.0 or age >= direction.z:
		return Vector3.ZERO
	var d := point - Vector2(data.x, data.y)
	var core := sqrt(d.length_squared() + shape.z * shape.z)
	var radius := core - shape.z
	var q := (radius - shape.y * age) / shape.x
	if absf(q) >= 1.0:
		return Vector3.ZERO
	var profile := pulse(q)
	var attenuation := 1.0 / (1.0 + shape.w * radius)
	var value := profile.x * attenuation
	var gradient := d / core * (profile.y / shape.x * attenuation \
		- profile.x * shape.w * attenuation * attenuation)
	if direction.w > 0.5:
		var heading := Vector2(direction.x, direction.y)
		var forward := d.dot(heading)
		var t := clampf((-forward / core + 0.2) / 0.6, 0.0, 1.0)
		var mask := t * t * (3.0 - 2.0 * t)
		var mask_gradient := (-heading / core + d * (forward / (core * core * core))) \
			* (6.0 * t * (1.0 - t) / 0.6)
		gradient = gradient * mask + value * mask_gradient
		value *= mask
	var strength := data.w * smoothstep(0.0, envelope.x, age) \
		* (1.0 - smoothstep(direction.z - envelope.y, direction.z, age))
	return Vector3(value * strength, gradient.x * strength, gradient.y * strength)


static func bow(point: Vector2, data: Vector4, direction: Vector4) -> Vector3:
	if data.z == 0.0:
		return Vector3.ZERO
	var forward := Vector2(direction.x, direction.y)
	var right := Vector2(-forward.y, forward.x)
	var d := point - Vector2(data.x, data.y)
	var u := d.dot(forward) / data.w
	var v := d.dot(right) / direction.z
	if absf(u) >= 1.0 or absf(v) >= 1.0:
		return Vector3.ZERO
	var longitudinal := pulse(u)
	var side := 1.0 - v * v
	var gradient := forward * (longitudinal.y * side * side / data.w) \
		+ right * (longitudinal.x * -4.0 * v * side / direction.z)
	return Vector3(longitudinal.x * side * side, gradient.x, gradient.y) * data.z


static func raw(point: Vector2, snapshot: WaterWaveSnapshot) -> Vector3:
	var result := Vector3.ZERO
	for wave: Vector4 in snapshot.ambient:
		var angle := point.dot(Vector2(wave.x, wave.y)) + wave.w
		result += Vector3(wave.z * sin(angle), wave.z * cos(angle) * wave.x,
			wave.z * cos(angle) * wave.y)
	for index in WaterWaveProfile.PACKET_SLOTS:
		result += packet(point, snapshot.packets[index], snapshot.directions[index],
			snapshot.shape, snapshot.envelope)
	return result + bow(point, snapshot.bow, snapshot.bow_direction)


## Includes the spatial derivative of the baked depth/shore limit, not only waves.
static func bounded(raw_value: Vector3, limit: float, limit_gradient := Vector2.ZERO) -> Vector3:
	if limit <= 0.0:
		return Vector3.ZERO
	var denominator := sqrt(limit * limit + raw_value.x * raw_value.x)
	var r := raw_value.x / denominator
	var l := limit / denominator
	var gradient := Vector2(raw_value.y, raw_value.z) * (l * l * l) \
		+ limit_gradient * (r * r * r)
	return Vector3(limit * r, gradient.x, gradient.y)
