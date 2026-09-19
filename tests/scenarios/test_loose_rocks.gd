extends GutTest
## Real Test Ground driving: actual tyre/stone contacts, motion and stalled-load
## diagnostics. A passing scripted line does not replace the owner's playtest.

const GROUND := preload("res://levels/test_ground/test_ground.tscn")
const GROUND_SCRIPT := preload("res://levels/test_ground/test_ground.gd")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _load() -> Node3D:
	var level: Node3D = GROUND.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = OFFROAD
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _place(level: Node3D, along: float, offset: float = 0.0) -> void:
	var car: Car = level.rig.car
	var origin := Vector3(GROUND_SCRIPT.LOOSE_ROCKS_X + offset,
			LooseRockCourse.floor_height(offset, -along) + 1.0, GROUND_SCRIPT.STRIP_ENTRY_Z - along)
	level.rig.place_car(Transform3D(Basis.IDENTITY, origin))
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 0.0
	await wait_physics_frames(ScenarioHelper.ticks(1.0))


func _drive(level: Node3D, end: float, offset: float = 0.0, full_throttle: bool = false) -> Dictionary:
	var car: Car = level.rig.car
	var stones: TalusBuilder = level.loose_rocks.talus
	var furthest: float = GROUND_SCRIPT.STRIP_ENTRY_Z - car.global_position.z
	var stalled := 0.0
	var minimum_up := 1.0
	var contacts := 0
	var max_awake := 0
	var max_stone_speed := 0.0
	var lowest_stone := 0.0
	var max_lateral := 0.0
	var elapsed := 0.0
	var max_lateral_at := 0.0
	var trace: Array[String] = []
	var next_trace := 30.0
	for tick in ScenarioHelper.ticks(75.0):
		# This narrow bank needs a nearer look-ahead and correction for sideways
		# motion. The general off-road driver permits too much downhill drift.
		var bank := RoughPatch.loose_rock_angle_deg(GROUND_SCRIPT.STRIP_ENTRY_Z - car.global_position.z)
		# At crawl speed on scree, hold an uphill heading before drift develops,
		# as a human does on a cross-slope. No extra force or car tuning is used.
		var uphill := 3.0 * tan(deg_to_rad(bank)) * minf(1.0, 2.0 / maxf(absf(car.forward_speed()), 0.1))
		var aim_x: float = GROUND_SCRIPT.LOOSE_ROCKS_X + offset - uphill - clampf(car.linear_velocity.x * 0.8, -0.8, 0.8)
		TrailScenarios.drive_toward(car, Vector3(aim_x, car.global_position.y, car.global_position.z - 3.0), 2.0)
		if full_throttle:
			car.input.virtual_throttle = 1.0
			car.input.virtual_brake = 0.0
		await get_tree().physics_frame
		elapsed = (tick + 1.0) / Engine.physics_ticks_per_second
		minimum_up = minf(minimum_up, car.global_basis.y.y)
		max_awake = maxi(max_awake, stones.awake_count())
		for stone in stones.stones:
			max_stone_speed = maxf(max_stone_speed, stone.linear_velocity.length())
			lowest_stone = minf(lowest_stone, stone.global_position.y)
		if absf(car.global_position.x - GROUND_SCRIPT.LOOSE_ROCKS_X) > max_lateral:
			max_lateral = absf(car.global_position.x - GROUND_SCRIPT.LOOSE_ROCKS_X)
			max_lateral_at = GROUND_SCRIPT.STRIP_ENTRY_Z - car.global_position.z
		for wheel in car.wheels:
			if is_instance_valid(wheel.contact_body):
				contacts += 1
		var along: float = GROUND_SCRIPT.STRIP_ENTRY_Z - car.global_position.z
		if along >= next_trace:
			trace.append("%.1f m: x %.2f, vx %.2f, speed %.2f, steer %.2f, yaw %.1f" % [along,
				car.global_position.x - GROUND_SCRIPT.LOOSE_ROCKS_X, car.linear_velocity.x,
				car.forward_speed(), car.input.virtual_steer, car.rotation_degrees.y])
			next_trace += 10.0
		if along >= end:
			break
		if along >= furthest + 0.03:
			furthest = along
			stalled = 0.0
		else:
			stalled += 1.0 / Engine.physics_ticks_per_second
		if stalled >= 8.0 or minimum_up < 0.5:
			break
	var moved := 0
	for i in stones.stones.size():
		if stones.stones[i].position.distance_to(stones._rest_transforms[i].origin) > 0.10:
			moved += 1
	var load := 0.0
	for wheel in car.wheels:
		load += wheel.tire_load
	var result := {"along": GROUND_SCRIPT.STRIP_ENTRY_Z - car.global_position.z,
		"upright": minimum_up, "contacts": contacts, "awake": max_awake, "moved": moved,
		"lateral": max_lateral, "lateral_at": max_lateral_at, "seconds": elapsed, "stalled": stalled,
		"load": load, "stone_speed": max_stone_speed, "stone_y": lowest_stone}
	gut.p("Loose rocks: %s" % result)
	if max_lateral > 1.25:
		gut.p("\n".join(trace))
	return result


func test_4x4_crawls_flat_and_banked_rocks_on_three_lines_without_wedging() -> void:
	var level := _load()
	for offset: float in [0.0, -0.55, 0.55]:
		await _place(level, 3.0, offset)
		level.loose_rocks.talus.reset_stones()
		var result := await _drive(level, 87.0, offset)
		assert_gte(result.along, 87.0, "clears lane without an 8-second chassis wedge")
		assert_gt(result.upright, 0.8)
		assert_lt(result.lateral, 1.25, "does not bypass rocks off the strip")
		assert_gt(result.contacts, 20, "wheels actually touch movable rocks")
		assert_gt(result.moved, 4, "real stones moved, not just visual particles")
		assert_lt(result.stone_speed, 35.0, "no unstable speed during the crossing")
		assert_gt(result.stone_y, -0.1, "stones cannot tunnel through the ground")


func test_full_throttle_moves_rocks_without_a_physics_explosion() -> void:
	var level := _load()
	await _place(level, 3.0)
	level.rig.car.drivetrain.traction_control_strength = 0.0
	var result := await _drive(level, 87.0, 0.0, true)
	assert_gte(result.along, 87.0)
	assert_gt(result.upright, 0.75)
	assert_gt(result.contacts, 5)
	assert_gt(result.moved, 4)
	assert_lt(result.stone_speed, 35.0, "peak velocity, not just the finish frame")
	assert_gt(result.stone_y, -0.1)
	for stone in level.loose_rocks.talus.stones:
		assert_true(stone.global_position.is_finite())
		assert_lt(stone.linear_velocity.length(), 35.0, "no unstable launch of a light stone")


func test_stop_on_rocks_reverse_then_pull_away_and_reset() -> void:
	var level := _load()
	await _place(level, 3.0)
	var first := await _drive(level, 21.0)
	assert_gte(first.along, 21.0)
	var car: Car = level.rig.car
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 0.0
	for tick in ScenarioHelper.ticks(8.0):
		if absf(car.forward_speed()) < 0.15:
			break
		# Release before the brake pedal switches the drivetrain into reverse.
		car.input.virtual_brake = 1.0 if car.forward_speed() > 1.1 else 0.0
		await get_tree().physics_frame
	car.input.virtual_brake = 0.0
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	assert_lt(absf(car.forward_speed()), 0.5, "stops inside the stone patch")
	var stop_z := car.global_position.z
	car.input.virtual_brake = 0.35
	car.input.virtual_steer = 0.0
	for tick in ScenarioHelper.ticks(8.0):
		await get_tree().physics_frame
		if car.global_position.z > stop_z + 4.0:
			break
	assert_gt(car.global_position.z, stop_z + 3.0, "can reverse out through disturbed stones")
	car.input.virtual_brake = 0.0
	car.input.virtual_throttle = 0.5
	var again := await _drive(level, 32.0)
	assert_gte(again.along, 32.0, "can drive forward again without a run-up")
	car.input.request_reset()
	await wait_physics_frames(4)
	assert_lt(car.global_position.x, 1.0, "normal Test Ground reset still returns to spawn")
	assert_eq(level.loose_rocks.talus.awake_count(), 0, "reset restores sleeping stones")


func test_can_pull_away_from_rest_in_the_banked_rock_patch() -> void:
	var level := _load()
	await _place(level, 48.0, -0.4)
	var result := await _drive(level, 87.0, -0.4)
	assert_gte(result.along, 87.0, "no run-up needed on the 12-degree bank")
	assert_gt(result.upright, 0.8)
	assert_lt(result.lateral, 1.25)
	assert_gt(result.contacts, 20)


func test_repeat_pass_over_disturbed_stones_without_resetting_them() -> void:
	var level := _load()
	await _place(level, 3.0)
	var first := await _drive(level, 87.0)
	assert_gte(first.along, 87.0)
	# Only relocate the car. Stones retain the positions left by the first pass.
	await _place(level, 3.0)
	var second := await _drive(level, 87.0)
	assert_gte(second.along, 87.0, "disturbed stones do not trap the second pass")
	assert_gt(second.contacts, 20)
	assert_lt(second.lateral, 1.25)
	assert_gt(second.upright, 0.8)
