extends GutTest
## Rock Canyon's intended car completes the trail; the low cars' limitations
## are recorded. Isolated obstacle checks exercise controlled throttle, deep
## mud, the grounded ford crossing, rock crawl, fallen tree and eroded S-bend.

const ROCK_CANYON := preload("res://levels/rock_canyon/rock_canyon.tscn")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")
const RALLY_CARS: Array[CarDef] = [preload("res://car/cars/rally.tres"), preload("res://car/cars/rally_tuned.tres")]
const DIRT := preload("res://surfaces/dirt.tres")
const STALL_SECONDS := 8.0
const RALLY_DISTANCE_CAP := 1250.0


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _load(car_def: CarDef = OFFROAD) -> RunLevel:
	var level: RunLevel = ROCK_CANYON.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
	add_child(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _free(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await get_tree().process_frame


func _surface_under(car: Car) -> StringName:
	for wheel in car.wheels:
		if wheel.in_contact and wheel.surface != null:
			return wheel.surface.id
	return &"air"


func _wheels_in_contact(car: Car) -> int:
	var count := 0
	for wheel in car.wheels:
		if wheel.in_contact:
			count += 1
	return count


func _diagnostics(level: RunLevel) -> String:
	var car := level.rig.car
	var sampler := level.trail.sampler
	return "distance %.2f m, lateral %+.2f m, surface %s, speed %.2f m/s, position %s" % [
			sampler.closest_distance(car.global_position), sampler.lateral_offset(car.global_position),
			_surface_under(car), car.forward_speed(), car.global_position]


func test_the_4x4_finishes_without_automatic_resets() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	gut.p("Rock Canyon built in %.2f s (%s)" % [level.trail.build_seconds, level.trail.phase_summary()])
	assert_lt(level.trail.build_seconds, 3.0, "desktop level build")
	watch_signals(level.resets)
	await TrailScenarios.wait_for_go(level)
	var lowest_up := 1.0
	var furthest := level.trail.sampler.closest_distance(car.global_position)
	var stalled_ticks := 0
	var stop_reason := "420 s time limit"
	var next_shelf_trace := 1450.0
	var shelf_trace: Array[String] = []
	for tick in ScenarioHelper.ticks(420.0):
		if level.tracker.is_finished():
			stop_reason = "finished"
			break
		driver.drive()
		await get_tree().physics_frame
		lowest_up = minf(lowest_up, car.global_basis.y.y)
		var distance := level.trail.sampler.closest_distance(car.global_position)
		if distance >= next_shelf_trace and next_shelf_trace <= 1620.0:
			shelf_trace.append("shelf trace %.1f m: speed %.2f, target %.2f, lateral %+.2f, steer %+.3f, upright %.3f, surface %s" % [
					distance, car.forward_speed(), driver.target_speed(distance),
					level.trail.sampler.lateral_offset(car.global_position), car.input.virtual_steer,
					car.global_basis.y.y, _surface_under(car)])
			next_shelf_trace += 10.0
		if distance > furthest + 0.05:
			furthest = distance
			stalled_ticks = 0
		else:
			stalled_ticks += 1
		if get_signal_emit_count(level.resets, "car_reset") > 0:
			stop_reason = "automatic reset"
			break
		if stalled_ticks >= ScenarioHelper.ticks(STALL_SECONDS):
			stop_reason = "stalled for %.0f s" % STALL_SECONDS
			break
	var distance := level.trail.sampler.closest_distance(car.global_position)
	var time := level.run.clock.elapsed
	if not level.tracker.is_finished():
		for line: String in shelf_trace:
			gut.p(line)
	gut.p("Off-road 4x4 Rock Canyon: %s, %s, average %.1f km/h, lowest upright %.3f; %s" % [
			RunHud.format_time(time), stop_reason, distance / maxf(time, 0.1) * 3.6,
			lowest_up, _diagnostics(level)])
	assert_true(level.tracker.is_finished(), "the 4x4 finishes: " + stop_reason)
	assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0, "no automatic resets")
	assert_gt(lowest_up, 0.5, "stays upright throughout the run")
	assert_true(level.results.is_showing())
	await _free(level)


func test_the_rally_cars_runs_are_recorded_not_required() -> void:
	for car_def: CarDef in RALLY_CARS:
		var level := _load(car_def)
		var car := level.rig.car
		var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
		watch_signals(level.resets)
		await TrailScenarios.wait_for_go(level)
		var furthest := level.trail.sampler.closest_distance(car.global_position)
		var stalled_ticks := 0
		var stop_reason := "240 s safety timeout"
		for tick in ScenarioHelper.ticks(240.0):
			if furthest >= RALLY_DISTANCE_CAP:
				stop_reason = "1250 m distance cap"
				break
			driver.drive()
			await get_tree().physics_frame
			var distance := level.trail.sampler.closest_distance(car.global_position)
			if distance > furthest + 0.05:
				furthest = distance
				stalled_ticks = 0
			else:
				stalled_ticks += 1
			if get_signal_emit_count(level.resets, "car_reset") > 0:
				stop_reason = "automatic reset"
				break
			if stalled_ticks >= ScenarioHelper.ticks(STALL_SECONDS):
				stop_reason = "beached for %.0f s" % STALL_SECONDS
				break
		gut.p("%s Rock Canyon: %s at %.2f s, furthest %.2f m; %s" % [car_def.display_name,
				stop_reason, level.run.clock.elapsed, furthest, _diagnostics(level)])
		assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0, "%s: no automatic reset" % car_def.display_name)
		await _free(level)


## Both throttle comparisons approach at the same restrained speed. The
## measured obstacle window starts just before the front wheels reach the face.
func _approach_ledge(level: RunLevel, distance: float) -> bool:
	var car := level.rig.car
	for tick in ScenarioHelper.ticks(20.0):
		if level.trail.sampler.closest_distance(car.global_position) >= distance:
			return true
		var speed := car.forward_speed()
		car.input.virtual_steer = 0.0
		car.input.virtual_throttle = clampf((3.0 - speed) * 0.8, 0.0, 0.4)
		car.input.virtual_brake = clampf((speed - 3.5) * 0.5, 0.0, 1.0)
		await get_tree().physics_frame
	return false


func test_the_4x4_crawls_a_ledge_with_less_wheelspin_at_part_throttle() -> void:
	var trail := TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.base_surface = DIRT
	trail.painted_lines = false
	var step := RockStepDef.new()
	step.distance = 60.0
	step.height = 0.4
	step.lateral_from = -6.5
	step.lateral_to = 6.5
	trail.rock_steps = [step]
	var means: Array[float] = []
	var approaches: Array[float] = []
	for throttle: float in [0.4, 1.0]:
		var level := RunLevelBuilder.straight(self, 200.0, PackedFloat32Array([150.0]), trail, OFFROAD)
		var car := level.rig.car
		car.drivetrain.traction_control_strength = 0.0  # compare throttle, not the assist
		await TrailScenarios.wait_for_go(level)
		await TrailScenarios.place_on_road(level, 45.0)
		var axle_reach := car.stats.wheelbase * 0.5 + car.stats.wheel_radius
		var window_start := step.distance - axle_reach - 0.25
		var window_end := step.distance + step.face_length + axle_reach + 0.5
		var approached := await _approach_ledge(level, window_start)
		assert_true(approached, "reached the ledge on the common controlled approach")
		var approach_speed := car.forward_speed()
		approaches.append(approach_speed)
		assert_between(approach_speed, 0.1, 4.5, "the ledge is approached at crawling speed")
		var slip_sum := 0.0
		var contact_samples := 0
		var elapsed := 0.0
		var lowest_up := 1.0
		var cleared := false
		watch_signals(level.resets)
		for tick in ScenarioHelper.ticks(20.0):
			if level.trail.sampler.closest_distance(car.global_position) >= window_end:
				cleared = true
				break
			car.input.virtual_steer = 0.0
			car.input.virtual_throttle = throttle
			car.input.virtual_brake = 0.0
			await get_tree().physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
			lowest_up = minf(lowest_up, car.global_basis.y.y)
			for wheel in car.wheels:
				if wheel.in_contact:
					slip_sum += absf(wheel.slip_ratio)
					contact_samples += 1
		var mean_slip := slip_sum / maxi(contact_samples, 1)
		means.append(mean_slip)
		gut.p("0.4 m ledge at %.0f%% throttle: approach %.3f m/s, cleared=%s, obstacle %.3f s, mean contact slip %.4f (%d samples), upright %.3f" % [
				throttle * 100.0, approach_speed, cleared, elapsed, mean_slip, contact_samples, lowest_up])
		assert_true(cleared, "the 4x4 clears the 0.4 m ledge at %.0f%% throttle" % (throttle * 100.0))
		assert_gt(contact_samples, 0)
		assert_gt(lowest_up, 0.5, "stays upright on the ledge")
		assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0)
		await _free(level)
	assert_almost_eq(approaches[0], approaches[1], 0.1, "both throttle tests have the same approach speed")
	assert_lt(means[0], means[1], "part throttle has less mean contact slip in the same obstacle window")


func test_the_4x4_climbs_the_mud_from_a_standstill_and_reaches_the_clearing() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 320.0)
	# Let the car's existing auto-hold settle the suspension without asking the
	# brake/reverse pedal to drive backward below the direction-change speed.
	for tick in ScenarioHelper.ticks(1.0):
		car.input.virtual_throttle = 0.0
		car.input.virtual_brake = 0.0
		await get_tree().physics_frame
	assert_lt(absf(car.forward_speed()), 0.1, "starts at rest inside the deep mud")
	var lowest_speed := INF
	var saw_deep_mud := false
	var seconds := 90.0
	watch_signals(level.resets)
	for tick in ScenarioHelper.ticks(90.0):
		if level.trail.sampler.closest_distance(car.global_position) >= 620.0:
			seconds = tick / float(Engine.physics_ticks_per_second)
			break
		driver.drive()
		car.input.virtual_throttle = 1.0
		car.input.virtual_brake = 0.0
		await get_tree().physics_frame
		if tick > ScenarioHelper.ticks(3.0):
			lowest_speed = minf(lowest_speed, car.forward_speed())
		if _surface_under(car) == &"deep_mud":
			saw_deep_mud = true
	gut.p("mud climb from rest, 320 m to the 620 m clearing: %.2f s, minimum speed after launch %.2f km/h; %s" % [
			seconds, lowest_speed * 3.6, _diagnostics(level)])
	assert_lt(seconds, 90.0, "the 4x4 climbs through the bends into the clearing")
	assert_true(saw_deep_mud, "deep mud was under the wheels")
	assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0)
	await _free(level)


func test_the_ford_is_crossed_on_wet_rock_without_leaving_the_ground() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 1262.0)
	var airborne_ticks := 0
	var maximum_airborne_ticks := 0
	var total_airborne_ticks := 0
	var saw_wet_rock := false
	var reached := false
	watch_signals(level.resets)
	for tick in ScenarioHelper.ticks(40.0):
		if level.trail.sampler.closest_distance(car.global_position) >= 1322.0:
			reached = true
			break
		driver.drive()
		await get_tree().physics_frame
		airborne_ticks = airborne_ticks + 1 if _wheels_in_contact(car) == 0 else 0
		if airborne_ticks > 0:
			total_airborne_ticks += 1
		maximum_airborne_ticks = maxi(maximum_airborne_ticks, airborne_ticks)
		if _surface_under(car) == &"wet_rock":
			saw_wet_rock = true
	gut.p("ford: reached=%s, wet rock=%s, longest airborne interval %.4f s (%d ticks), total %d ticks; %s" % [
			reached, saw_wet_rock, maximum_airborne_ticks / float(Engine.physics_ticks_per_second),
			maximum_airborne_ticks, total_airborne_ticks, _diagnostics(level)])
	assert_true(reached, "crossed the ford")
	assert_true(saw_wet_rock, "wet rock under the wheels")
	assert_lte(maximum_airborne_ticks, ScenarioHelper.ticks(0.1), "no airborne interval longer than a tenth of a second")
	assert_lt(total_airborne_ticks, ScenarioHelper.ticks(0.1), "less than a tenth of a second airborne in total")
	assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0)
	await _free(level)


func test_rock_crawl_from_checkpoint_reaches_the_tree_clearing() -> void:
	await _drive_technical_section(705.0, 912.0, 90.0, "narrow rock crawl")


func test_washed_out_s_bend_reaches_the_waterfall_approach() -> void:
	await _drive_technical_section(1140.0, 1262.0, 60.0, "washed-out S-bend")


func _drive_technical_section(start: float, finish: float, limit: float, label: String) -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler, level.trail.profile)
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, start)
	for def: TalusDef in level.trail.trail.talus:
		assert_gte(def.start, 1500.0, "accepted crawl and waterfall approach still use fixed rocks")
	var lowest_up := 1.0
	var reached := false
	var elapsed := limit
	var max_lateral := 0.0
	watch_signals(level.resets)
	for tick in ScenarioHelper.ticks(limit):
		if level.trail.sampler.closest_distance(car.global_position) >= finish:
			reached = true
			elapsed = tick / float(Engine.physics_ticks_per_second)
			break
		driver.drive()
		await get_tree().physics_frame
		lowest_up = minf(lowest_up, car.global_basis.y.y)
		max_lateral = maxf(max_lateral, absf(level.trail.sampler.lateral_offset(car.global_position)))
	gut.p("%s: reached=%s in %.2f s, lowest upright %.3f, max lateral %.2f m; %s" % [
			label, reached, elapsed, lowest_up, max_lateral, _diagnostics(level)])
	assert_true(reached, "the car passes through " + label)
	assert_gt(lowest_up, 0.8, "stays upright throughout the section")
	assert_lt(max_lateral, 2.0, "crosses the obstacles on the road, not the shoulder")
	assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0)
	await _free(level)


func test_fallen_tree_is_crossable_slowly_at_the_centre_and_thin_end() -> void:
	for lateral: float in [0.0, 2.5]:
		var level := _load()
		var car := level.rig.car
		var tree := level.trail.trail.fallen_trees[0]
		var sampler := level.trail.sampler
		await TrailScenarios.wait_for_go(level)
		await TrailScenarios.place_at_offset(level, tree.distance - 8.0, lateral)
		var reached := false
		var saw_logs := false
		var lowest_up := 1.0
		var elapsed := 25.0
		watch_signals(level.resets)
		for tick in ScenarioHelper.ticks(25.0):
			var at := sampler.closest_distance(car.global_position)
			if at > tree.distance + 9.0:
				reached = true
				elapsed = tick / float(Engine.physics_ticks_per_second)
				break
			TrailScenarios.drive_toward(car, sampler.position(at + 7.0) + sampler.right(at + 7.0) * lateral, 2.5)
			car.input.virtual_throttle = minf(car.input.virtual_throttle, 0.6)
			await get_tree().physics_frame
			lowest_up = minf(lowest_up, car.global_basis.y.y)
			for wheel in car.wheels:
				if wheel.in_contact and wheel.surface != null and wheel.surface.id == &"logs":
					saw_logs = true
		gut.p("fallen tree at lateral %+.1f m: crossed=%s, logs=%s, %.2f s, lowest upright %.3f; %s" % [
				lateral, reached, saw_logs, elapsed, lowest_up, _diagnostics(level)])
		assert_true(reached, "crossed the trunk slowly without needing a run-up")
		assert_true(saw_logs, "actually drove over the tree")
		assert_gt(lowest_up, 0.8)
		assert_eq(get_signal_emit_count(level.resets, "car_reset"), 0)
		await _free(level)
