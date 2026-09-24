extends GutTest


func test_profile_limits_and_resource_defaults() -> void:
	var profile: WaterWaveProfile = load("res://water/waves/prototype.tres")
	assert_true(profile.is_valid())
	assert_eq(WaterWaveProfile.PACKET_SLOTS, 16)
	assert_eq(profile.maximum_offset, 0.12)
	var copy := profile.duplicate() as WaterWaveProfile
	copy.front_width = 0.0
	assert_false(copy.is_valid())
	copy.front_width = NAN
	assert_false(copy.is_valid())


func test_empty_field_and_body_isolation_have_no_car_waves() -> void:
	var field := WaterWaveField.new()
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", false, snap)
	assert_eq(WaterWaveMath.raw(Vector2.ZERO, snap), Vector3.ZERO)
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08)
	field.step(0.0)
	field.step(0.5)
	field.write_snapshot(&"b", false, snap)
	assert_eq(WaterWaveMath.raw(Vector2(1.4, 0.0), snap), Vector3.ZERO)
	field.write_snapshot(&"a", false, snap)
	assert_gt(absf(WaterWaveMath.raw(Vector2(1.4, 0.0), snap).x), 0.01)


func test_budget_is_global_and_pending_packets_reserve_slots() -> void:
	var field := WaterWaveField.new()
	for index in 4:
		assert_true(field.queue_packet(WaterWaveField.Kind.ENTRY, StringName(str(index)), Vector2.ZERO, Vector2.ZERO, 0.08))
	assert_false(field.queue_packet(WaterWaveField.Kind.ENTRY, &"other", Vector2.ZERO, Vector2.ZERO, 0.08))
	for index in 12:
		assert_true(field.queue_packet(WaterWaveField.Kind.WAKE, &"a", Vector2.ZERO, Vector2.ZERO, 0.03))
	assert_false(field.queue_packet(WaterWaveField.Kind.WAKE, &"b", Vector2.ZERO, Vector2.ZERO, 0.03))
	assert_eq(field.active_count(), 0, "pending input must not mutate the previous snapshot")
	field.step(0.0)
	assert_eq(field.active_count(), 16)
	assert_eq(field.skipped_packets, 2)
	field.step(3.0)
	assert_eq(field.active_count(), 4)
	field.step(1.0)
	assert_eq(field.active_count(), 0)
	assert_eq(field._slots.size(), 16)


func test_reset_invalidates_snapshot_serial_and_clears_pending_and_bow() -> void:
	var field := WaterWaveField.new()
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08)
	field.set_bow(&"a", Vector2.ZERO, Vector2.UP, 2.0, 0.05)
	var serial := field.serial
	field.reset()
	field.step(1.0)
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", false, snap)
	assert_gt(snap.serial, serial)
	assert_eq(field.active_count(), 0)
	assert_eq(WaterWaveMath.raw(Vector2.ZERO, snap), Vector3.ZERO)


func test_fixed_time_vs_split_steps_match_and_float32_snapshot_is_bounded() -> void:
	var a := WaterWaveField.new()
	var b := WaterWaveField.new()
	for field: WaterWaveField in [a, b]:
		field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2(0.75, 0.0), 0.08)
		field.step(0.0)
	a.step(1.0)
	for index in 120:
		b.step(1.0 / 120.0)
	var sa := WaterWaveSnapshot.new()
	var sb := WaterWaveSnapshot.new()
	a.write_snapshot(&"a", true, sa)
	b.write_snapshot(&"a", true, sb)
	assert_eq(sa.packets, sb.packets)
	assert_almost_eq(sa.packets[0].x, 0.75, 0.000001)
	assert_eq(sa.ambient, sb.ambient)
	assert_eq(sa.packets.size(), 16)


func test_invalid_inputs_are_rejected_and_profile_is_copied() -> void:
	var profile := WaterWaveProfile.new()
	var field := WaterWaveField.new(profile)
	profile.entry_amplitude = 99.0
	assert_false(field.queue_packet(WaterWaveField.Kind.ENTRY, &"", Vector2.ZERO, Vector2.ZERO, 0.08))
	assert_false(field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2(NAN, 0.0), Vector2.ZERO, 0.08))
	assert_false(field.queue_packet(WaterWaveField.Kind.WAKE, &"a", Vector2.ZERO, Vector2.ZERO, 0.03, Vector2.ZERO))
	field.step(NAN)
	field.step(-1.0)
	assert_eq(field.clock_seconds, 0.0)
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 99.0)
	field.step(0.0)
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", false, snap)
	assert_almost_eq(snap.packets[0].w, 0.08, 0.000001)


func test_pulse_support_onset_expiry_and_finite_centre() -> void:
	for q: float in [-2.0, -1.0, 1.0, 2.0]:
		assert_eq(WaterWaveMath.pulse(q), Vector2.ZERO)
	assert_eq(WaterWaveMath.pulse(0.0), Vector2(1.0, 0.0))
	var shape := Vector4(1.5, 2.0, 0.5, 0.15)
	var direction := Vector4(1.0, 0.0, 4.0, 1.0)
	for age: float in [0.0, 0.00001, 0.1, 0.5, 3.9999, 4.0]:
		var value := WaterWaveMath.packet(Vector2.ZERO, Vector4(0.0, 0.0, age, 0.08), direction, shape, Vector2(0.12, 0.75))
		assert_true(value.is_finite())
		if age == 0.0 or age == 4.0:
			assert_eq(value, Vector3.ZERO)


func test_wake_strongest_behind_and_bow_respects_travel_direction() -> void:
	var shape := Vector4(1.5, 2.0, 0.5, 0.15)
	var data := Vector4(0.0, 0.0, 0.5, 0.03)
	var direction := Vector4(1.0, 0.0, 3.0, 1.0)
	assert_gt(WaterWaveMath.packet(Vector2(-1.4, 0.0), data, direction, shape, Vector2(0.12, 0.75)).x, 0.01)
	assert_eq(WaterWaveMath.packet(Vector2(1.4, 0.0), data, direction, shape, Vector2(0.12, 0.75)), Vector3.ZERO)
	assert_almost_eq(WaterWaveMath.bow(Vector2.ZERO, Vector4(0.0, 0.0, 0.05, 1.5), Vector4(1.0, 0.0, 1.0, 0.0)).x, 0.05, 0.000001)


func test_bow_fades_without_packet_generation() -> void:
	var field := WaterWaveField.new()
	field.set_bow(&"a", Vector2.ZERO, Vector2.RIGHT, 2.0, 0.05)
	field.step(1.0)
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", false, snap)
	assert_gt(snap.bow.z, 0.049)
	field.set_bow(&"a", Vector2.ZERO, Vector2.RIGHT, 2.0, 0.0)
	field.step(2.0)
	field.write_snapshot(&"a", false, snap)
	assert_lt(snap.bow.z, 0.001)
	assert_eq(field.active_count(), 0)


func test_bounded_height_and_derivative_including_local_limit_gradient() -> void:
	for raw_value: float in [-1000.0, -0.08, 0.0, 0.08, 1000.0]:
		var raw := Vector3(raw_value, 0.013, -0.021)
		var gradient := Vector2(0.002, -0.003)
		var value := WaterWaveMath.bounded(raw, 0.03, gradient)
		assert_lte(absf(value.x), 0.03)
		for axis in 2:
			var h := 0.001
			var high := WaterWaveMath.bounded(Vector3(raw_value + raw[axis + 1] * h, 0.0, 0.0), 0.03 + gradient[axis] * h)
			var low := WaterWaveMath.bounded(Vector3(raw_value - raw[axis + 1] * h, 0.0, 0.0), 0.03 - gradient[axis] * h)
			assert_almost_eq(value[axis + 1], (high.x - low.x) / (2.0 * h), 0.00002)
	assert_eq(WaterWaveMath.bounded(Vector3.ONE, 0.0), Vector3.ZERO)


func test_analytic_gradients_match_finite_differences_including_soft_core() -> void:
	var field := WaterWaveField.new()
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2(0.0, 1.0), Vector2.ZERO, 0.08)
	field.queue_packet(WaterWaveField.Kind.WAKE, &"a", Vector2.ZERO, Vector2.ZERO, 0.03, Vector2.RIGHT)
	field.set_bow(&"a", Vector2.ZERO, Vector2.RIGHT, 2.0, 0.05)
	field.step(0.0)
	field.step(0.5)
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", true, snap)
	for x in range(-10, 11):
		for z in range(-10, 11):
			var at := Vector2(x, z) * 0.17
			var value := WaterWaveMath.raw(at, snap)
			for axis in 2:
				var step := Vector2.ZERO
				step[axis] = 0.001
				var difference := (WaterWaveMath.raw(at + step, snap).x - WaterWaveMath.raw(at - step, snap).x) / 0.002
				assert_almost_eq(value[axis + 1], difference, 0.0001)


func test_hull_sized_entry_starts_outside_centre_and_keeps_finite_gradients() -> void:
	var field := WaterWaveField.new()
	assert_false(field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08, Vector2.UP, NAN))
	assert_false(field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08, Vector2.UP, -0.1))
	assert_false(field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08, Vector2.UP, 1.51))
	assert_true(field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08, Vector2.UP, 1.1))
	field.step(0.0)
	field.step(0.25)
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", false, snap)
	assert_almost_eq(snap.directions[0].w, -1.1, 0.000001)
	assert_eq(WaterWaveMath.raw(Vector2.ZERO, snap), Vector3.ZERO, "not a hidden centre hump")
	# Soft radial coordinate 1.1 + 2*0.25 corresponds to physical radius 2.04m.
	assert_gt(WaterWaveMath.raw(Vector2(2.04, 0.0), snap).x, 0.05)
	for x in range(-14, 15):
		for z in range(-14, 15):
			var at := Vector2(x, z) * 0.17
			var value := WaterWaveMath.raw(at, snap)
			assert_true(value.is_finite())
			for axis in 2:
				var step := Vector2.ZERO
				step[axis] = 0.001
				var difference := (WaterWaveMath.raw(at + step, snap).x - WaterWaveMath.raw(at - step, snap).x) / 0.002
				assert_almost_eq(value[axis + 1], difference, 0.0001)
	field.step(3.75)
	field.write_snapshot(&"a", false, snap)
	assert_eq(WaterWaveMath.raw(Vector2(4.0, 0.0), snap), Vector3.ZERO)


func test_long_clock_stays_bounded_and_pause_is_no_step() -> void:
	var field := WaterWaveField.new()
	field.step(600.0)
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", true, snap)
	var before := WaterWaveMath.raw(Vector2(5.0, 9.0), snap)
	field.write_snapshot(&"a", true, snap)
	assert_eq(WaterWaveMath.raw(Vector2(5.0, 9.0), snap), before)
	for wave: Vector4 in snap.ambient:
		assert_gte(wave.w, 0.0)
		assert_lte(wave.w, TAU)


func test_queued_bow_and_packets_cannot_change_a_committed_snapshot() -> void:
	var field := WaterWaveField.new()
	field.set_bow(&"a", Vector2.ZERO, Vector2.UP, 2.0, 0.04)
	field.step(0.5)
	var snap := WaterWaveSnapshot.new()
	field.write_snapshot(&"a", false, snap)
	var before := snap.bow
	var serial := snap.serial
	field.set_bow(&"a", Vector2(8.0, 3.0), Vector2.RIGHT, 3.0, 0.05)
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08)
	field.write_snapshot(&"a", false, snap)
	assert_eq(snap.bow, before)
	assert_eq(snap.serial, serial)
	assert_eq(snap.packets[0], Vector4.ZERO)
	field.step(1.0 / 120.0)
	field.write_snapshot(&"a", false, snap)
	assert_ne(snap.bow, before)
	assert_gt(snap.serial, serial)
	assert_gt(snap.packets[0].w, 0.0)


func test_prescribed_sources_decay_identically_at_60_and_120_hz() -> void:
	var first := WaterWaveField.new()
	var second := WaterWaveField.new()
	for field: WaterWaveField in [first, second]:
		field.queue_packet(WaterWaveField.Kind.WAKE, &"a", Vector2.ZERO, Vector2(0.75, 0.0), 0.03)
		field.step(0.0)
	var a := WaterWaveSnapshot.new()
	var b := WaterWaveSnapshot.new()
	for tick in 240:
		first.step(1.0 / 60.0)
		second.step(1.0 / 120.0)
		second.step(1.0 / 120.0)
		first.write_snapshot(&"a", true, a)
		second.write_snapshot(&"a", true, b)
		assert_eq(first.active_count(), second.active_count())
		assert_lt(WaterWaveMath.raw(Vector2(1.0, 0.0), a).distance_to(WaterWaveMath.raw(Vector2(1.0, 0.0), b)), 0.000001)
	assert_eq(first.active_count(), 0)
