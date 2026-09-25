extends GutTest


func test_height_specialization_is_bit_exact_to_cpu_reference_at_saturation() -> void:
	var field := WaterWaveField.new()
	var snapshot := WaterWaveSnapshot.new()
	var height := WaterWaveHeight.new()
	for age: float in [0.0, 0.01, 0.12, 0.7, 2.99, 3.99, 4.0, 600.0]:
		for ambient: bool in [false, true]:
			field.reset()
			for index in WaterWaveProfile.PACKET_SLOTS:
				field.queue_packet(WaterWaveField.Kind.ENTRY if index < 4 else WaterWaveField.Kind.WAKE,
					&"pool", Vector2((index % 4) * 0.3, (index / 4) * 0.3),
					Vector2(0.75, 0.0), 0.08, Vector2(0.6, 0.8), float(index) * 0.5 if index < 4 else 0.0)
			field.set_bow(&"pool", Vector2.ZERO, Vector2(-0.6, -0.8), 3.0, 0.09, 1.8)
			field.step(0.0)
			field.step(age)
			field.write_snapshot(&"pool", ambient, snapshot)
			height.prepare(snapshot)
			for index in 400:
				var at := Vector2(index % 20 - 10, index / 20 - 10) * 0.31
				var reference := WaterWaveMath.raw(at, snapshot)
				assert_eq(height.raw(at), reference.x)
				for limit: float in [0.0, 0.006, 0.12]:
					assert_eq(height.bounded(at, limit), WaterWaveMath.bounded(reference, limit).x)


func test_preparation_drops_expired_and_foreign_packets_without_carrying_previous_tick() -> void:
	var field := WaterWaveField.new()
	var snapshot := WaterWaveSnapshot.new()
	var height := WaterWaveHeight.new()
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"pool", Vector2.ZERO, Vector2.ZERO, 0.08)
	field.step(0.0)
	field.write_snapshot(&"pool", false, snapshot)
	height.prepare(snapshot)
	assert_eq(height._active.size(), 1)
	field.step(4.0)
	field.write_snapshot(&"pool", false, snapshot)
	height.prepare(snapshot)
	assert_true(height._active.is_empty())
	assert_eq(height.raw(Vector2.ZERO), 0.0)
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"elsewhere", Vector2.ZERO, Vector2.ZERO, 0.08)
	field.step(0.0)
	field.write_snapshot(&"pool", false, snapshot)
	height.prepare(snapshot)
	assert_true(height._active.is_empty())


func test_support_culling_preserves_values_at_float32_packet_boundaries() -> void:
	var field := WaterWaveField.new()
	var snapshot := WaterWaveSnapshot.new()
	var height := WaterWaveHeight.new()
	for age: float in [0.001, 0.12, 1.0, 2.99, 3.99]:
		field.reset()
		field.queue_packet(WaterWaveField.Kind.ENTRY, &"pool", Vector2(0.4, 96.0), Vector2.ZERO, 0.08, Vector2.UP, 1.5)
		field.step(0.0)
		field.step(age)
		field.write_snapshot(&"pool", true, snapshot)
		height.prepare(snapshot)
		for q: float in [-1.00001, -1.0, -0.99999, 0.0, 0.99999, 1.0, 1.00001]:
			var radius := snapshot.shape.z + 1.5 + snapshot.shape.y * age + q * snapshot.shape.x
			var distance := sqrt(maxf(0.0, radius * radius - snapshot.shape.z * snapshot.shape.z))
			for direction: Vector2 in [Vector2.RIGHT, Vector2.UP, Vector2(0.6, 0.8)]:
				var at := Vector2(0.4, 96.0) + direction * distance
				assert_eq(height.raw(at), WaterWaveMath.raw(at, snapshot).x)
