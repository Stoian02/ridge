class_name WaterWaveHeight
extends RefCounted
## Height-only specialization of WaterWaveMath.raw: identical equations, order
## and float32 intermediate rounding, without derivatives used only by shading.
## Prepared once per immutable snapshot, NEVER reused across physics ticks.
## The full CPU/GPU pair remains the reference; parity tests guard this path too.

var snapshot: WaterWaveSnapshot
var _active := PackedInt32Array()


func prepare(data: WaterWaveSnapshot) -> void:
	snapshot = data
	_active.clear()
	for index in WaterWaveProfile.PACKET_SLOTS:
		var packet := data.packets[index]
		if packet.w != 0.0 and packet.z >= 0.0 and packet.z < data.directions[index].z:
			_active.append(index)


func raw(point: Vector2) -> float:
	# Vector components deliberately preserve the reference's float32 term and
	# accumulation rounding. Scalar GDScript sums would use float64 instead.
	var result := Vector3.ZERO
	for wave: Vector4 in snapshot.ambient:
		var angle := point.dot(Vector2(wave.x, wave.y)) + wave.w
		result += Vector3(wave.z * sin(angle), 0.0, 0.0)
	for index: int in _active:
		result += Vector3(_packet(point, snapshot.packets[index], snapshot.directions[index]), 0.0, 0.0)
	return (result + _bow(point)).x


func _packet(point: Vector2, data: Vector4, direction: Vector4) -> float:
	var shape := snapshot.shape
	var d := point - Vector2(data.x, data.y)
	var core := sqrt(d.length_squared() + shape.z * shape.z)
	var radius := core - shape.z
	var q := (radius - maxf(0.0, -direction.w) - shape.y * data.z) / shape.x
	if absf(q) >= 1.0:
		return 0.0
	var t := 1.0 - q * q
	var profile := Vector2(t * t * cos(PI * q), 0.0)
	var value := profile.x * (1.0 / (1.0 + shape.w * radius))
	if direction.w > 0.5:
		var forward := d.dot(Vector2(direction.x, direction.y))
		var mask := clampf((-forward / core + 0.2) / 0.6, 0.0, 1.0)
		value *= mask * mask * (3.0 - 2.0 * mask)
	var strength := data.w * smoothstep(0.0, snapshot.envelope.x, data.z) \
		* (1.0 - smoothstep(direction.z - snapshot.envelope.y, direction.z, data.z))
	return value * strength


func _bow(point: Vector2) -> Vector3:
	var data := snapshot.bow
	if data.z == 0.0:
		return Vector3.ZERO
	var direction := snapshot.bow_direction
	var forward := Vector2(direction.x, direction.y)
	var right := Vector2(-forward.y, forward.x)
	var d := point - Vector2(data.x, data.y)
	var v := d.dot(right) / direction.z
	if absf(v) >= 1.0:
		return Vector3.ZERO
	var u := (d.dot(forward) + direction.w * v * v) / data.w
	if absf(u) >= 1.0:
		return Vector3.ZERO
	var t := 1.0 - u * u
	var longitudinal := Vector2(t * t * cos(PI * u), 0.0)
	var side := 1.0 - v * v * v * v
	return Vector3(longitudinal.x * side * side, 0.0, 0.0) * data.z


func bounded(point: Vector2, limit: float) -> float:
	if limit <= 0.0:
		return 0.0
	var value := raw(point)
	return Vector3(limit * (value / sqrt(limit * limit + value * value)), 0.0, 0.0).x
