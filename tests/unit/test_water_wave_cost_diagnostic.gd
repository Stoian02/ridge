extends GutTest


func test_split_diagnostic_matches_production_raw_exactly() -> void:
	var sampler := WaterWaveCostSampler.new()
	sampler.counters.resize(WaterWaveCostSampler.WIDTH)
	sampler.snapshot = WaterWaveSnapshot.new()
	var field := WaterWaveField.new()
	field.queue_packet(WaterWaveField.Kind.ENTRY, &"pool", Vector2.ZERO, Vector2.ZERO, 0.08)
	field.queue_packet(WaterWaveField.Kind.WAKE, &"pool", Vector2.ONE, Vector2.ZERO, 0.03, Vector2.RIGHT)
	field.set_bow(&"pool", Vector2.ZERO, Vector2(0.6, 0.8), 2.0, 0.08, 1.8)
	field.step(0.0)
	for enabled: bool in [false, true]:
		for tick in 12:
			field.step(0.13)
			field.write_snapshot(&"pool", enabled, sampler.snapshot)
			for index in 40:
				var at := Vector2(index % 8 - 4, index / 8 - 2) * 0.7
				assert_eq(sampler._raw_split(at), WaterWaveMath.raw(at, sampler.snapshot))


func test_diagnostic_cache_and_heights_match_production_at_each_snapshot() -> void:
	var top := WaterWaveMesh.new()
	var vertices := PackedVector3Array([Vector3(-3.0, 1.0, -3.0), Vector3(3.0, 1.0, -3.0), Vector3(-3.0, 1.0, 3.0)])
	var bed := vertices.duplicate()
	for index in bed.size():
		bed[index].y = 0.0
	assert_true(top.build(vertices, bed))
	var snapshot := WaterWaveSnapshot.new()
	var field := WaterWaveField.new()
	var standard := WaterWaveSampler.new()
	var diagnostic := WaterWaveCostSampler.new()
	standard.configure(top, snapshot)
	diagnostic.configure(top, snapshot)
	for split: bool in [false, true]:
		diagnostic.split = split
		for tick in 5:
			field.step(1.0 / 120.0)
			field.write_snapshot(&"pool", true, snapshot)
			for index in 20:
				var point := Vector2(-1.5 + (index % 4) * 0.4, -1.5 + (index / 4) * 0.4)
				assert_eq(diagnostic.height_at(point), standard.height_at(point))
				assert_eq(diagnostic.evaluated_vertices, standard.evaluated_vertices)
	assert_gt(diagnostic.counters[2], 0)
	assert_gt(diagnostic.counters[3], 0, "records cross-tick repeats, never reuses stale heights")
	assert_eq(diagnostic.height_at(Vector2(99.0, 99.0)), -INF)
