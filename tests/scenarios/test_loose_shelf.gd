extends GutTest
## Drive the real shelf; count real wheel/body contacts and visible displacement.

const LEVEL := preload("res://levels/rock_canyon/rock_canyon.tscn")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _load() -> RunLevel:
	var level: RunLevel = LEVEL.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = OFFROAD
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _drive(level: RunLevel, finish: float, limit: float) -> Dictionary:
	var car := level.rig.car
	var stones := level.trail.talus_builder
	var sampler := level.trail.sampler
	var driver := TrailDriver.new(car, sampler, level.trail.profile)
	gut.p("Shelf start: along %.2f, lateral %.2f, upright %.3f, velocity %s" % [
		sampler.closest_distance(car.global_position), sampler.lateral_offset(car.global_position), car.global_basis.y.y, car.linear_velocity])
	var contacts := 0
	var peak_awake := 0
	var peak_speed := 0.0
	var fastest := ""
	var upright := 1.0
	var lateral := 0.0
	var furthest := sampler.closest_distance(car.global_position)
	var stalled := 0.0
	var elapsed := 0.0
	var reached := false
	var touched: Dictionary = {}
	var penetrated := false
	for tick in ScenarioHelper.ticks(limit):
		driver.drive()
		await get_tree().physics_frame
		elapsed = (tick + 1.0) / Engine.physics_ticks_per_second
		var at := sampler.closest_distance(car.global_position)
		upright = minf(upright, car.global_basis.y.y)
		lateral = maxf(lateral, absf(sampler.lateral_offset(car.global_position)))
		peak_awake = maxi(peak_awake, stones._active.size())
		for i: int in stones._active:
			touched[i] = true
			var stone := stones.stones[i]
			if stone.position.y < level.trail.field.height_at(stone.position.x, stone.position.z) - 1.0:
				penetrated = true
			if stone.linear_velocity.length() > peak_speed:
				peak_speed = stone.linear_velocity.length()
				fastest = "%s: position %s, rest %s, terrain %.2f, velocity %s" % [stone.name,
					stone.position, stones._rest_transforms[i].origin,
					level.trail.field.height_at(stone.position.x, stone.position.z), stone.linear_velocity]
		for wheel in car.wheels:
			if is_instance_valid(wheel.contact_body):
				contacts += 1
		if at >= finish:
			reached = true
			break
		if at > furthest + 0.03:
			furthest = at
			stalled = 0.0
		else:
			stalled += 1.0 / Engine.physics_ticks_per_second
		if stalled >= 8.0 or upright < 0.5:
			break
	var moved := 0
	for i: int in touched:
		if stones.stones[i].position.distance_to(stones._rest_transforms[i].origin) > 0.10:
			moved += 1
	var result := {"reached": reached, "along": sampler.closest_distance(car.global_position),
		"seconds": elapsed, "contacts": contacts, "moved": moved, "awake": peak_awake,
		"stone_speed": peak_speed, "upright": upright, "lateral": lateral, "stalled": stalled,
		"penetrated": penetrated}
	gut.p("Loose shelf: %s" % result)
	if peak_speed >= 35.0:
		gut.p("Fastest stone: " + fastest)
	if not reached:
		gut.p("Shelf stopped: lateral %.2f, speed %.3f, gear %d, wheels %s" % [
			sampler.lateral_offset(car.global_position), car.forward_speed(), car.drivetrain.gear,
			car.wheels.map(func(wheel: Wheel) -> String: return "%s load %.0f slip %.2f" % [wheel.surface.id if wheel.surface != null else &"air", wheel.tire_load, wheel.slip_ratio])])
	return result


func test_4x4_crosses_the_whole_dense_shelf_and_disturbs_real_stones() -> void:
	var level := _load()
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 1497.0)
	watch_signals(level.resets)
	var result := await _drive(level, 1905.0, 150.0)
	assert_true(result.reached, "CP4 through CP5 without a chassis wedge")
	assert_gt(result.contacts, 1000)
	assert_gt(result.moved, 120, "clearly more than a handful of stones move")
	assert_lt(result.awake, 150, "only local disturbances, not a whole-shelf avalanche")
	assert_lt(result.stone_speed, 35.0)
	assert_false(result.penetrated, "small stones stay above the terrain")
	assert_gt(result.upright, 0.8)
	assert_lt(result.lateral, 1.3, "crosses the stones without escaping to the verge")
	assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0)


func test_relaunch_on_steep_bank_and_second_pass_over_disturbed_rocks() -> void:
	var level := _load()
	await TrailScenarios.wait_for_go(level)
	for pass_index in 2:
		await TrailScenarios.place_on_road(level, 1678.0)
		level.rig.car.input.virtual_throttle = 0.0
		level.rig.car.input.virtual_brake = 0.0
		await wait_physics_frames(120)
		var result := await _drive(level, 1710.0, 25.0)
		assert_true(result.reached, "starts on disturbed rocks, pass %d" % pass_index)
		assert_gt(result.contacts, 50)
		assert_gt(result.moved, 10)
		assert_lt(result.lateral, 1.3)
		assert_gt(result.upright, 0.8)
