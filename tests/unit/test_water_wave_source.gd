extends GutTest


func _wet() -> WaterWaveSource.Observation:
	var observation := WaterWaveSource.Observation.new()
	observation.body_id = &"pool"
	observation.body_immersion = 0.4
	observation.wheel_immersion = 1.0
	observation.upper_clearance = 0.1
	observation.velocity = Vector3(0.0, 0.0, 8.0)
	observation.size = Vector3(1.8, 1.0, 4.0)
	observation.bow_at = Vector2(0.0, 2.0)
	observation.wake_at = Vector2(0.0, -2.0)
	return observation


func test_spawn_and_bobbing_never_retrigger_entry_but_dry_rearm_does() -> void:
	var source := WaterWaveSource.new()
	var field := WaterWaveField.new()
	var wet := _wet()
	for tick in 120:
		source.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
	assert_eq(source.entries, 0, "underwater spawn seeds history")
	wet.body_immersion = 0.01
	for tick in 60:
		source.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
	wet.body_immersion = 0.1
	source.step(1.0 / 120.0, wet, field)
	assert_eq(source.entries, 1)
	for tick in 240:
		wet.body_immersion = 0.04 if tick % 2 == 0 else 0.06
		source.step(1.0 / 120.0, wet, field)
		field.step(1.0 / 120.0)
	assert_eq(source.entries, 1, "ordinary crossing chatter cannot rearm")
	source.reset()
	source.step(1.0 / 120.0, wet, field)
	assert_eq(source.entries, 0)


func test_prescribed_motion_cadence_matches_60_and_120_and_stops_at_relative_rest() -> void:
	var counts: Array[int] = []
	for hz: int in [60, 120]:
		var source := WaterWaveSource.new()
		var field := WaterWaveField.new()
		var wet := _wet()
		source.step(0.0, wet, field)
		for tick in hz * 3:
			source.step(1.0 / hz, wet, field)
			field.step(1.0 / hz)
		counts.append(source.wakes)
		assert_eq(source.wakes, 10)
		wet.velocity = Vector3.ZERO
		for tick in hz * 5:
			source.step(1.0 / hz, wet, field)
			field.step(1.0 / hz)
		assert_eq(source.wakes, 10, "throttle/wheel spin are not source inputs")
		assert_eq(field.active_count(), 0)
		assert_lt(field._bow_value, 0.000001)
	assert_eq(counts[0], counts[1])


func test_deep_fade_reverse_direction_and_body_isolation() -> void:
	var source := WaterWaveSource.new()
	var field := WaterWaveField.new()
	var wet := _wet()
	wet.velocity = Vector3(-8.0, 0.0, 0.0)
	source.step(0.0, wet, field)
	for tick in 60:
		source.step(1.0 / 60.0, wet, field)
		field.step(1.0 / 60.0)
	assert_eq(field._bow_direction, Vector2.LEFT)
	assert_gt(source.wakes, 0)
	var count := source.wakes
	wet.body_id = &"other"
	wet.upper_clearance = -0.61
	for tick in 60:
		source.step(1.0 / 60.0, wet, field)
		field.step(1.0 / 60.0)
	assert_eq(source.wakes, count, "deeply submerged sources cannot stir distant surface")
	for slot: WaterWaveField.Packet in field._slots:
		if slot.active:
			assert_eq(slot.body_id, &"pool")
