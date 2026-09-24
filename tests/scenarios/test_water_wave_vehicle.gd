extends GutTest
## Live unfrozen cars; the water-height integration changes no car/force tuning.

const GROUND := preload("res://levels/test_ground/test_ground.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/offroad_4x4.tres"),
	preload("res://car/cars/rally.tres"), preload("res://car/cars/rally_tuned.tres")]
var _rate := 120


func before_each() -> void:
	SaveSandbox.enter()
	_rate = Engine.physics_ticks_per_second


func after_each() -> void:
	Engine.physics_ticks_per_second = _rate
	get_tree().paused = false
	SaveSandbox.leave()


func _level(car_def: CarDef, mode: int) -> Node3D:
	var level: Node3D = GROUND.instantiate()
	var rig: DrivingRig = level.get_node("DrivingRig")
	rig.car_override = car_def
	add_child(level)
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(level.water_waves.set_mode(mode), level.water_waves.error)
	return level


func _release(level: Node3D) -> void:
	remove_child(level)
	level.free()


func test_natural_entries_generate_bounded_sources_for_all_cars_at_both_rates() -> void:
	for hz: int in [60, 120]:
		Engine.physics_ticks_per_second = hz
		for car_def in CARS:
			var level := _level(car_def, WaterWaveTestGround.Mode.CAR_WAVES)
			var rig: DrivingRig = level.rig
			var waves: WaterWaveTestGround = level.water_waves
			var start := Vector3(105.0, WaterCourse.pool_floor_height(0.0, 29.0) + 1.0, 59.0)
			rig.place_car(Transform3D(Basis(Vector3.UP, PI), start))
			await wait_physics_frames(hz)
			assert_eq(waves.emitter.source.entries, 0)
			rig.car.linear_velocity = Vector3(0.0, 0.0, 8.0)
			for wheel in rig.car.wheels:
				wheel.spin_speed = 8.0 / rig.car.stats.wheel_radius
			rig.car.input.virtual_throttle = 1.0
			var largest_offset := 0.0
			var entry_tick := -1
			var exposed_crest_checked := false
			for tick in hz * 5:
				await get_tree().physics_frame
				if entry_tick < 0 and waves.emitter.source.entries > 0:
					entry_tick = tick
				if entry_tick >= 0 and tick - entry_tick == hz / 4:
					assert_gte(_exposed_entry_vertices(waves, rig.car), 8,
						"a real entry crest must emerge outside the hull within a quarter-second")
					exposed_crest_checked = true
				assert_true(rig.car.linear_velocity.is_finite())
				assert_true(rig.car.angular_velocity.is_finite())
				assert_lte(waves.runtime.field.active_count(), 16)
				for sample in rig.car.water.body_samples:
					if sample.valid:
						largest_offset = maxf(largest_offset, absf(sample.surface_y - sample.rest_surface_y))
			gut.p("%s %d Hz live entry: entries=%d wakes=%d offset=%.6f z=%.2f" % [car_def.id, hz,
				waves.emitter.source.entries, waves.emitter.source.wakes, largest_offset, rig.car.position.z])
			assert_eq(waves.emitter.source.entries, 1, "one actual hull entry, no self-triggering")
			assert_gt(waves.emitter.source.wakes, 0)
			assert_gt(largest_offset, 0.0001, "car waves actually reach physical samples")
			assert_lt(largest_offset, 0.12)
			assert_true(exposed_crest_checked)
			_release(level)
			await get_tree().process_frame


func _exposed_entry_vertices(waves: WaterWaveTestGround, car: Car) -> int:
	var view := waves.runtime.views[0]
	var entry := WaterWaveSnapshot.new()
	waves.runtime.field.write_snapshot(view.body_id, false, entry)
	entry.bow.z = 0.0
	for index in range(WaterWaveProfile.ENTRY_SLOTS, WaterWaveProfile.PACKET_SLOTS):
		entry.packets[index] = Vector4.ZERO
	var top := view.sampler.topology
	var sampler := WaterWaveSampler.new()
	sampler.configure(top, entry)
	var count := 0
	for index in top.vertices.size():
		var height := sampler.vertex_offset(index)
		assert_lte(absf(height), top.limits[index] + 0.000001, "original depth/shore cap retained")
		var local := car.to_local(top.vertices[index] + view.origin)
		if height >= 0.015 and (absf(local.x) > car.stats.body_size.x * 0.5 + 0.3 \
				or absf(local.z) > car.stats.body_size.z * 0.5 + 0.3):
			count += 1
	gut.p("Exposed entry vertices above 15 mm: %d" % count)
	return count


func _equilibrium(stats: CarStats) -> float:
	var lower := WaterCourse.POOL_LEVEL - 2.0
	var upper := WaterCourse.POOL_LEVEL + 2.0
	var points := WaterForces.probe_positions(stats.body_size)
	var ratio := VehicleWaterState.new().buoyancy_ratio(stats.water_profile)
	for step in 40:
		var y := (lower + upper) * 0.5
		var fraction := 0.0
		for point in points:
			fraction += WaterForces.probe_fraction(y + point.y, stats.body_size.y * 0.30,
				WaterCourse.POOL_LEVEL, WaterCourse.BASE) / 8.0
		if fraction * ratio > 1.0:
			lower = y
		else:
			upper = y
	return (lower + upper) * 0.5


func test_early_flotation_is_measurable_but_gentle_without_self_propulsion() -> void:
	for hz: int in [60, 120]:
		Engine.physics_ticks_per_second = hz
		for car_def in CARS:
			var excursions: Array[float] = []
			var tilts: Array[float] = []
			for mode: int in [WaterWaveTestGround.Mode.OFF, WaterWaveTestGround.Mode.FULL]:
				var level := _level(car_def, mode)
				var rig: DrivingRig = level.rig
				var y := _equilibrium(rig.car.stats)
				rig.place_car(Transform3D(Basis.IDENTITY, Vector3(105.0, y, 126.0)))
				var excursion := 0.0
				var tilt := 0.0
				for tick in hz * 2:
					await get_tree().physics_frame
					excursion = maxf(excursion, absf(rig.car.global_position.y - y))
					tilt = maxf(tilt, rad_to_deg(rig.car.global_basis.y.angle_to(Vector3.UP)))
				assert_lt(Vector2(rig.car.global_position.x - 105.0, rig.car.global_position.z - 126.0).length(), 0.01)
				assert_eq(rig.car.water.state.flooding, 0.0)
				if mode != WaterWaveTestGround.Mode.OFF:
					assert_eq(level.water_waves.emitter.source.entries, 0)
					assert_eq(level.water_waves.emitter.source.wakes, 0)
				excursions.append(excursion)
				tilts.append(tilt)
				_release(level)
				await get_tree().process_frame
			gut.p("%s %d Hz early afloat Off/Full: y=%s tilt=%s" % [car_def.id, hz, excursions, tilts])
			assert_gt(absf(excursions[1] - excursions[0]), 0.00001, "response exceeds numerical noise")
			assert_lt(excursions[1] - excursions[0], 0.15)
			assert_lt(tilts[1] - tilts[0], 5.0)
