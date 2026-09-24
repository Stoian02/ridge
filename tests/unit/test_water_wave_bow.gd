extends GutTest


func test_curved_crest_wraps_both_shoulders_and_has_compact_support() -> void:
	var data := Vector4(0.0, 0.0, 0.05, 1.5)
	var direction := Vector4(1.0, 0.0, 2.0, 1.5)
	assert_almost_eq(WaterWaveMath.bow(Vector2.ZERO, data, direction).x, 0.05, 0.000001)
	var retreat := -direction.w * pow(1.2 / direction.z, 2.0)
	for side: float in [-1.0, 1.0]:
		var at := Vector2(retreat, side * 1.2)
		assert_gt(WaterWaveMath.bow(at, data, direction).x, 0.035,
			"shoulder crest remains strong beside the hull, not just at the centre")
		assert_lt(WaterWaveMath.bow(Vector2(0.0, side * 1.2), data, direction).x,
			WaterWaveMath.bow(at, data, direction).x, "crest sweeps backward toward the sides")
	for at: Vector2 in [Vector2(2.0, 0.0), Vector2(-4.0, 0.0), Vector2(0.0, 2.0)]:
		assert_eq(WaterWaveMath.bow(at, data, direction), Vector3.ZERO)


func test_curved_normals_match_finite_differences_for_turns_and_reverse() -> void:
	var data := Vector4(0.3, -0.7, 0.05, 1.5)
	for forward: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2(0.6, 0.8)]:
		for sweep: float in [0.6, 2.0]:
			var direction := Vector4(forward.x, forward.y, 2.5, sweep)
			for x in range(-15, 16):
				for z in range(-15, 16):
					var at := Vector2(x, z) * 0.23
					var result := WaterWaveMath.bow(at, data, direction)
					assert_true(result.is_finite())
					for axis in 2:
						var delta := Vector2.ZERO
						delta[axis] = 0.0005
						var difference := (WaterWaveMath.bow(at + delta, data, direction).x \
							- WaterWaveMath.bow(at - delta, data, direction).x) / 0.001
						assert_almost_eq(result[axis + 1], difference, 0.00003)


func test_bow_shape_is_snapshot_committed_and_invalid_sweep_cannot_replace_it() -> void:
	var field := WaterWaveField.new()
	field.set_bow(&"pool", Vector2.ZERO, Vector2.RIGHT, 4.0, 0.05, 0.8)
	field.step(0.5)
	var snapshot := WaterWaveSnapshot.new()
	field.write_snapshot(&"pool", false, snapshot)
	assert_almost_eq(snapshot.bow_direction.z, 3.0, 0.000001)
	assert_almost_eq(snapshot.bow_direction.w, 0.8, 0.000001)
	var before := snapshot.bow_direction
	field.set_bow(&"pool", Vector2.ONE, Vector2.UP, 2.0, 0.05, 1.8)
	field.write_snapshot(&"pool", false, snapshot)
	assert_eq(snapshot.bow_direction, before)
	field.step(1.0 / 120.0)
	field.write_snapshot(&"pool", false, snapshot)
	assert_ne(snapshot.bow_direction, before)
	before = snapshot.bow_direction
	for invalid: float in [NAN, INF, -0.1, 2.1]:
		field.set_bow(&"pool", Vector2.ZERO, Vector2.RIGHT, 9.0, 0.05, invalid)
		field.step(1.0 / 120.0)
		field.write_snapshot(&"pool", false, snapshot)
		assert_eq(snapshot.bow_direction, before)
	field.write_snapshot(&"other", false, snapshot)
	assert_eq(snapshot.bow.z, 0.0)
	field.reset()
	field.write_snapshot(&"pool", false, snapshot)
	assert_eq(snapshot.bow.z, 0.0)
	assert_eq(field.active_count(), 0, "one attached bow, no new travelling packets")


func test_bow_shape_changes_do_not_change_entry_wake_or_ambient_snapshots() -> void:
	var sources: Array[WaterWaveSource] = [WaterWaveSource.new(), WaterWaveSource.new()]
	var fields: Array[WaterWaveField] = [WaterWaveField.new(), WaterWaveField.new()]
	var a := WaterWaveSnapshot.new()
	var b := WaterWaveSnapshot.new()
	for tick in 180:
		for index in 2:
			var observation := WaterWaveSource.Observation.new()
			observation.body_id = &"pool"
			observation.body_immersion = 0.0 if tick < 65 else 0.4
			observation.upper_clearance = 0.1
			observation.velocity = Vector3(0.0, -0.1, 8.0)
			observation.bow_width = 1.8 if index == 0 else 3.9
			observation.bow_sweep = 0.6 if index == 0 else 2.0
			sources[index].step(1.0 / 120.0, observation, fields[index])
			fields[index].step(1.0 / 120.0)
		fields[0].write_snapshot(&"pool", true, a)
		fields[1].write_snapshot(&"pool", true, b)
		assert_eq(a.packets, b.packets)
		assert_eq(a.directions, b.directions)
		assert_eq(a.ambient, b.ambient)
	assert_eq(sources[0].entries, 1)
	assert_eq(sources[0].wakes, sources[1].wakes)
	assert_ne(a.bow_direction, b.bow_direction)
