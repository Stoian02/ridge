extends GutTest
## End-to-end winter driving, with real geometry and every shipped car.

const FROZEN := preload("res://levels/frozen_pass/frozen_pass.tscn")
const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/rally.tres"),
		preload("res://car/cars/rally_tuned.tres"), preload("res://car/cars/offroad_4x4.tres")]


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _free(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await get_tree().process_frame


func test_every_car_finishes_and_crosses_the_bridge_upright_without_resets() -> void:
	for car_def: CarDef in CARS:
		var level: RunLevel = FROZEN.instantiate()
		(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
		add_child(level)
		level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
		var car := level.rig.car
		var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
		var bridge_up := 1.0
		var bridge_samples := 0
		var tunnel_samples := 0
		var camera_above_road := 0.0
		var tunnel_lateral := 0.0
		assert_lt(level.trail.build_seconds, 3.0, "desktop level build")
		watch_signals(level.resets)
		for tick in ScenarioHelper.ticks(300.0):
			if level.tracker.is_finished():
				break
			driver.drive()
			await get_tree().physics_frame
			var distance := level.trail.sampler.closest_distance(car.global_position)
			if distance >= 835.0 and distance <= 865.0:
				bridge_up = minf(bridge_up, car.global_basis.y.y)
				bridge_samples += 1
			if distance >= 1165.0 and distance <= 1385.0:
				tunnel_lateral = maxf(tunnel_lateral, absf(level.trail.sampler.lateral_offset(car.global_position)))
				var camera_distance := level.trail.sampler.closest_distance(level.rig.camera.global_position)
				var floor_height := level.trail.sampler.surface_point(camera_distance, 0.0, level.trail.profile).y
				camera_above_road = maxf(camera_above_road, level.rig.camera.global_position.y - floor_height)
				tunnel_samples += 1
		var distance := level.trail.sampler.closest_distance(car.global_position)
		gut.p("%s Frozen Pass: %.2f s, finished=%s, distance=%.1f, speed=%.1f km/h, bridge up=%.3f, camera=%.2f m" % [
				car_def.display_name, level.run.clock.elapsed, level.tracker.is_finished(), distance,
				car.forward_speed() * 3.6, bridge_up, camera_above_road])
		assert_true(level.tracker.is_finished(), "%s finishes" % car_def.display_name)
		assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0, "no resets")
		assert_gt(bridge_samples, 0, "crossed the bridge")
		assert_gt(bridge_up, 0.5, "bridge did not roll the car")
		assert_gt(tunnel_samples, 0, "drove through the tunnel")
		assert_lt(tunnel_lateral + car.stats.body_size.x * 0.5, 5.3, "car stays clear of both tunnel walls")
		assert_lt(camera_above_road, 6.0, "camera stayed beneath the tunnel ceiling")
		await _free(level)


func test_every_car_brakes_from_60_on_asphalt_then_snow_then_ice() -> void:
	for car_def: CarDef in CARS:
		var ground: Node3D = TEST_GROUND.instantiate()
		(ground.get_node("DrivingRig") as DrivingRig).car_override = car_def
		add_child(ground)
		var rig: DrivingRig = ground.get_node("DrivingRig")
		rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
		var car := rig.car
		var distances: Array[float] = []
		for lane: Vector2 in [Vector2(0.0, -140.0), Vector2(45.0, -30.0), Vector2(60.0, -30.0)]:
			rig.place_car(Transform3D(Basis.IDENTITY, Vector3(lane.x, 1.0, lane.y)))
			car.input.virtual_throttle = 0.0
			car.input.virtual_brake = 1.0
			await wait_physics_frames(ScenarioHelper.ticks(1.0))
			var start := car.global_position
			car.linear_velocity = Vector3(0.0, 0.0, -60.0 / 3.6)
			for tick in ScenarioHelper.ticks(20.0):
				await get_tree().physics_frame
				if absf(car.forward_speed()) < 0.2:
					break
			assert_lt(absf(car.forward_speed()), 0.2, "stopped within the strip")
			distances.append(start.z - car.global_position.z)
		gut.p("%s 60 km/h braking: asphalt %.1f m, snow %.1f m, ice %.1f m" % [
				car_def.display_name, distances[0], distances[1], distances[2]])
		assert_gt(distances[0], 5.0)
		assert_gt(distances[1], distances[0] * 1.2, "snow clearly lengthens braking")
		assert_gt(distances[2], distances[1] * 1.2, "ice is slipperier still")
		await _free(ground)


func test_falling_into_the_gorge_waits_for_manual_reset() -> void:
	var level: RunLevel = FROZEN.instantiate()
	add_child(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	await TrailScenarios.wait_for_go(level)
	var sampler := level.trail.sampler
	var point := sampler.position(850.0) + sampler.right(850.0) * 12.0 + Vector3.UP
	level.rig.place_car(Transform3D(Basis.looking_at(sampler.forward(850.0)), point))
	watch_signals(level.resets)
	await wait_physics_frames(ScenarioHelper.ticks(4.0))
	assert_signal_not_emitted(level.resets, "car_reset", "gorge floor does not trigger a special reset")
	assert_lt(level.rig.car.global_position.y, point.y - 4.0, "car fell onto the gorge floor")
	assert_gt(level.rig.car.global_position.y, level.trail.kill_height())
	assert_true(ScenarioHelper.is_upright(level.rig.car))
	level.rig.car.input.reset_requested.emit()
	await wait_physics_frames(2)
	assert_signal_emit_count(level.resets, "car_reset", 1, "manual reset still works")
	assert_lt(sampler.closest_distance(level.rig.car.global_position), 30.0, "returns to the last reached checkpoint")
	await _free(level)
