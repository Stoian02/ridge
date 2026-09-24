extends GutTest

const QUERIES := preload("res://tests/unit/test_water_queries.gd")


func test_bound_queries_follow_drawn_triangle_and_unbinding_restores_exact_baseline() -> void:
	var world := WaterWorld.new()
	var offset := Vector3(10.0, 3.0, -20.0)
	var top := QUERIES.quad(2.0, Vector2(-6.0, -6.0), Vector2(6.0, 6.0))
	var bed := QUERIES.quad(0.0, Vector2(-6.0, -6.0), Vector2(6.0, 6.0))
	var def := QUERIES.definition()
	def.current_velocity = Vector3(0.75, 0.0, 0.0)
	var body := world.add_body(def, top, bed, Transform3D(Basis.IDENTITY, offset))
	var mesh := WaterWaveMesh.new()
	assert_true(mesh.build(top, bed))
	var field := WaterWaveField.new()
	var snapshot := WaterWaveSnapshot.new()
	field.write_snapshot(def.id, true, snapshot)
	var sampler := WaterWaveSampler.new()
	sampler.configure(mesh, snapshot)
	var at := offset + Vector3(0.2, 1.0, 0.3)
	var baseline := WaterSample.new()
	world.sample(at, baseline)
	assert_eq(baseline.rest_surface_y, baseline.surface_y)
	assert_true(world.bind_wave(body, sampler, offset))
	var result := WaterSample.new()
	world.sample(at, result)
	assert_almost_eq(result.surface_y, sampler.height_at(Vector2(0.2, 0.3)) + offset.y, 0.000001)
	assert_gt(absf(result.surface_y - baseline.surface_y), 0.001)
	assert_eq(result.rest_surface_y, baseline.surface_y)
	assert_eq(result.bed_y, baseline.bed_y)
	assert_eq(result.current, baseline.current)
	assert_eq(result.edge_weight, baseline.edge_weight)
	field.step(0.5)
	field.write_snapshot(def.id, true, snapshot)
	world.sample(at, result)
	assert_almost_eq(result.surface_y, sampler.height_at(Vector2(0.2, 0.3)) + offset.y, 0.000001)
	world.sample(offset + Vector3(6.1, 2.0, 0.0), result)
	assert_false(result.valid, "waves never enlarge a footprint")
	assert_eq(result.rest_surface_y, 0.0)
	world.clear_waves()
	world.sample(at, result)
	assert_eq(result.surface_y, baseline.surface_y)
	assert_eq(result.body_id, baseline.body_id)
	assert_eq(result.color, baseline.color)


func test_registry_changes_drop_bindings_and_reject_stale_body_handles() -> void:
	var world := WaterWorld.new()
	var faces := QUERIES.quad(2.0)
	var bed := QUERIES.quad(0.0)
	var body := world.add_body(QUERIES.definition(), faces, bed)
	var top := WaterWaveMesh.new()
	assert_true(top.build(faces, bed))
	var sampler := WaterWaveSampler.new()
	sampler.configure(top, WaterWaveSnapshot.new())
	assert_true(world.bind_wave(body, sampler, Vector3.ZERO))
	assert_eq(world.wave_binding_count(), 1)
	world.add_body(QUERIES.definition(), faces, bed)
	assert_eq(world.wave_binding_count(), 0)
	assert_false(world.bind_wave(body, sampler, Vector3.ZERO))
	world.clear()
	assert_eq(world.wave_binding_count(), 0)


func test_wave_height_drives_intake_timer_and_trough_clearance_at_60_and_120_hz() -> void:
	var world := WaterWorld.new()
	var top := QUERIES.quad(2.0, Vector2(-6.0, -6.0), Vector2(6.0, 6.0))
	var bed := QUERIES.quad(0.0, Vector2(-6.0, -6.0), Vector2(6.0, 6.0))
	var body := world.add_body(QUERIES.definition(), top, bed)
	var mesh := WaterWaveMesh.new()
	assert_true(mesh.build(top, bed))
	var field := WaterWaveField.new()
	var snapshot := WaterWaveSnapshot.new()
	var sampler := WaterWaveSampler.new()
	sampler.configure(mesh, snapshot)
	assert_true(world.bind_wave(body, sampler, Vector3.ZERO))
	var sample := WaterSample.new()
	for path: String in ["res://car/rally_car.tres", "res://car/rally_car_tuned.tres", "res://car/offroad_4x4.tres"]:
		var stats: CarStats = load(path)
		for hz: int in [60, 120]:
			var state := VehicleWaterState.new()
			field.reset()
			for tick in hz * 3:
				field.step(1.0 / hz)
				field.write_snapshot(body.id, true, snapshot)
				world.sample(Vector3(0.2, 1.8, 0.3), sample)
				state.step(1.0 / hz, stats.water_profile, 0.0, sample.valid, 1.8 - sample.surface_y)
				assert_eq(state.stalled, tick == hz * 3 - 1)
			assert_eq(state.flooding, 0.0, "intake timer is not body flooding")
			state.reset()
			state.step(2.9, stats.water_profile, 0.8, true, -0.01)
			# Find a real ambient trough below a fixed mean-height intake. It
			# must reset the timer even though the static mean is not above it.
			var found_trough := false
			for tick in hz * 4:
				field.step(1.0 / hz)
				field.write_snapshot(body.id, true, snapshot)
				world.sample(Vector3(0.2, 2.0, 0.3), sample)
				if sample.surface_y < 1.999:
					state.step(1.0 / hz, stats.water_profile, 0.8, sample.valid, 2.0 - sample.surface_y)
					found_trough = true
					break
			assert_true(found_trough)
			assert_eq(state.intake_seconds, 0.0)
			assert_false(state.stalled)
			assert_gt(state.deep_seconds, 2.9, "body flooding grace continues independently")
