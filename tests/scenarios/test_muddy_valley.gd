extends GutTest
## Muddy Valley as a whole: it builds with its mud, ruts and creek, a scripted
## driver can complete it, mud slows the car without trapping it, a car can drive
## out of the creek, and the road carries on past the finish.

const MUDDY_VALLEY := preload("res://levels/muddy_valley/muddy_valley.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _load() -> RunLevel:
	var level: RunLevel = MUDDY_VALLEY.instantiate()
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _surface_under_road(level: RunLevel, distance: float, lateral: float = 0.0) -> StringName:
	var sampler := level.trail.sampler
	var above := sampler.surface_point(distance, lateral, level.trail.profile) + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(above, above + Vector3.DOWN * 6.0)
	query.exclude = [level.rig.car.get_rid()]
	var hit := level.get_world_3d().direct_space_state.intersect_ray(query)
	return SurfaceLookup.surface_of(hit["collider"]).id if not hit.is_empty() else &""


func test_muddy_valley_builds_with_its_gates_mud_and_creek() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var scatter := level.trail.scatter_builder
	var hedge := level.trail.hedge_builder
	var shortcut := level.trail.shortcut_builder
	var hedge_batches := hedge.get_children().filter(func(child: Node) -> bool: return child is MultiMeshInstance3D).size()
	gut.p("Muddy Valley: %.0f m long, built in %.2f s (%d x %d terrain chunks, %d pines, %d broadleaf, %d rocks, %d posts, %d water points, %d hedge bushes in %d batches, %d shortcut primitives)" % [
		sampler.length, level.trail.build_seconds,
		level.trail.field.chunk_count().x, level.trail.field.chunk_count().y,
		scatter.pine_count, scatter.broadleaf_count, scatter.rock_count, scatter.post_count,
		level.trail.creek_builder.water_points.size(), hedge.bush_count, hedge_batches, shortcut.primitive_count])
	assert_between(sampler.length, 1450.0, 1650.0, "about 1.5 km plus the run-off")
	assert_eq(level.trail.checkpoints.reset_transforms.size(), 6, "start, 4 checkpoints, finish")
	assert_lt(level.trail.build_seconds, 3.0, "desktop build time")
	assert_not_null(level.level, "Muddy Valley finds its catalog entry")
	assert_gt(scatter.broadleaf_count, 0, "broadleaf trees")
	assert_gt(level.trail.creek_builder.water_points.size(), 35, "water along more than 70 m of the creek's 150 m")
	assert_gt(hedge.bush_count, 500, "dense hedges beside the mud")
	assert_lte(hedge.bush_count * 20, 13100, "hedges add at most 13.1k visible primitives")
	assert_lte(hedge_batches, 16, "hedges add at most 16 draw calls even if every batch is visible")
	# The rocky shortcut needs fine rows so its stones keep their shape. Measured
	# with it in view, Muddy Valley peaked at 244,676 primitives and 117 draw
	# calls (1250 m), within the 300k / 150 budget.
	assert_lte(shortcut.primitive_count, 24000, "the rocky shortcut stays within its share of the budget")
	assert_lte(hedge.bush_count * 20 + shortcut.primitive_count, 37000,
			"all new path geometry adds at most 37k primitives")
	await wait_physics_frames(2)
	assert_eq(_surface_under_road(level, 800.0), &"mud", "the mud stretch beside the creek")
	assert_eq(_surface_under_road(level, 1400.0), &"mud", "the final climb")
	assert_eq(_surface_under_road(level, 600.0), &"dirt", "the descent")
	var verge := sampler.surface_point(1000.0, -6.0, level.trail.profile) + Vector3.UP * 3.0
	var verge_hit := level.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(verge, verge + Vector3.DOWN * 6.0))
	assert_eq(SurfaceLookup.surface_of(verge_hit["collider"]).id, &"mud", "mud covers the shoulder too")


func test_mud_stages_in_over_damp_dirt_and_soft_mud() -> void:
	var level := _load()
	for check in [[758.0, &"dirt"], [762.0, &"damp_dirt"], [766.0, &"soft_mud"],
			[770.0, &"mud"], [840.0, &"mud"], [844.0, &"soft_mud"],
			[848.0, &"damp_dirt"], [852.0, &"dirt"]]:
		for lateral: float in [0.0, -6.0]:
			assert_eq(_surface_under_road(level, check[0], lateral), check[1],
					"surface at %.0f m, lateral %.0f m" % [check[0], lateral])


func test_scripted_driver_completes_muddy_valley() -> void:
	var level := _load()
	var car := level.rig.car
	var driver := TrailDriver.new(car, level.trail.sampler)
	watch_signals(level.resets)
	watch_signals(level.run)
	var ticks := 0
	var lost_contact := 0
	var jumps := level.trail.trail.jumps
	while not level.tracker.is_finished() and ticks < ScenarioHelper.ticks(200.0):
		driver.drive()
		await get_tree().physics_frame
		ticks += 1
		if level.run.clock.stage != RunClock.Stage.RUNNING or car.air_control.is_active:
			continue
		var distance := level.trail.sampler.closest_distance(car.global_position)
		if not jumps.any(func(j: Vector3) -> bool: return absf(distance - j.x) < 25.0):
			for wheel in car.wheels:
				if not wheel.in_contact:
					lost_contact += 1
	var time := level.run.clock.elapsed
	gut.p("scripted driver: finished %s after %s at %.0f m, lateral %.1f m, %d checkpoints, %d wheel-ticks without contact away from the jump" % [
		level.tracker.is_finished(), RunHud.format_time(time),
		level.trail.sampler.closest_distance(car.global_position), level.trail.sampler.lateral_offset(car.global_position),
		get_signal_emit_count(level.run, "checkpoint_reached"), lost_contact])
	assert_true(level.tracker.is_finished(), "reached the finish")
	assert_signal_not_emitted(level.resets, "car_reset")
	assert_signal_emit_count(level.run, "checkpoint_reached", 4)
	assert_between(time, 60.0, 150.0)
	assert_lt(lost_contact, 240, "rough ground shakes the wheels but doesn't throw them off")
	assert_true(level.results.is_showing(), "results appear at the finish")
	var saved: Dictionary = SaveSystem.read(SaveSandbox.PATH)["levels"]["muddy_valley"]
	assert_almost_eq(float(saved["best_time"]), time, 0.001, "the finish was saved")


func test_a_car_stopped_in_the_mud_climb_reaches_the_finish() -> void:
	var level := _load()
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_on_road(level, 1400.0)
	var finish := level.trail.checkpoints.gate_distances[-1]
	var car := level.rig.car
	var seconds := await TrailScenarios.full_throttle_until(level, 30.0,
			func() -> bool: return level.trail.sampler.closest_distance(car.global_position) >= finish)
	gut.p("from a standstill at 1400 m (8%% mud climb) to the finish at %.0f m: %.1f s" % [finish, seconds])
	assert_lt(seconds, 30.0, "mud slows the car but never traps it")


func test_mud_is_slower_than_dirt_from_a_standstill() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var covered := {}
	for start: float in [765.0, 860.0]:  # flat mud beside the creek; 1% uphill dirt just after it
		await TrailScenarios.place_on_road(level, start)
		await TrailScenarios.full_throttle_until(level, 3.0, func() -> bool: return false)
		covered[start] = sampler.closest_distance(car.global_position) - start
	gut.p("3 s at full throttle from rest: %.1f m on mud, %.1f m on dirt" % [covered[765.0], covered[860.0]])
	assert_lt(covered[765.0], covered[860.0] * 0.9, "mud is clearly slower")


func test_left_verge_cannot_bypass_the_second_mud_stretch() -> void:
	var level := _load()
	var car := level.rig.car
	var sampler := level.trail.sampler
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place_at_offset(level, 965.0, -10.0)
	var saw_mud := false
	for tick in ScenarioHelper.ticks(10.0):
		var distance := sampler.closest_distance(car.global_position)
		var target := sampler.position(distance + 14.0) + sampler.right(distance + 14.0) * -10.0
		TrailScenarios.drive_toward(car, target, 14.0)
		for wheel in car.wheels:
			if wheel.in_contact and wheel.surface.id == &"mud":
				saw_mud = true
		await get_tree().physics_frame
	var finish_distance := sampler.closest_distance(car.global_position)
	gut.p("left-verge bypass attempt ended at %.0f m; touched mud: %s" % [finish_distance, saw_mud])
	assert_true(saw_mud or finish_distance < 1050.0,
			"the return stops the outside line, or the car is forced onto mud")


func test_hidden_shortcut_connects_its_entry_and_exit() -> void:
	var level := _load()
	var car := level.rig.car
	var sampler := level.trail.sampler
	var shortcut := level.trail.shortcut_builder
	await TrailScenarios.wait_for_go(level)
	await TrailScenarios.place(level, shortcut.transform_at(1277.0, CheckpointPlacer.RESET_HEIGHT))
	watch_signals(level.resets)
	var lowest_compression := INF
	var highest_compression := -INF
	var reached_end := false
	var seconds := 45.0
	for tick in ScenarioHelper.ticks(seconds):
		var distance := sampler.closest_distance(car.global_position)
		if distance >= 1487.0 and absf(sampler.lateral_offset(car.global_position)) < level.trail.trail.half_total_width():
			seconds = tick / float(Engine.physics_ticks_per_second)
			reached_end = true
			break
		TrailScenarios.drive_toward(car, shortcut.surface_point(minf(distance + 8.0, 1490.0)), 10.0)
		for wheel in car.wheels:
			if wheel.in_contact:
				lowest_compression = minf(lowest_compression, wheel.compression)
				highest_compression = maxf(highest_compression, wheel.compression)
		await get_tree().physics_frame
	var final_distance := sampler.closest_distance(car.global_position)
	var final_lateral := sampler.lateral_offset(car.global_position)
	gut.p("rough shortcut: reached %s in %.1f s at %.0f m, lateral %.1f m, compression range %.3f m" % [
			reached_end, seconds, final_distance, final_lateral, highest_compression - lowest_compression])
	assert_true(reached_end, "the shortcut runs from the hedge start to its exit")
	assert_signal_not_emitted(level.resets, "car_reset")
	assert_lt(absf(final_lateral), level.trail.trail.half_total_width())
	assert_gt(highest_compression - lowest_compression, 0.18, "the shortcut has a substantial roughness drawback")


## A car that slides into the creek can drive out along it. (Straight up the
## road-side bank it stalls: there the bank adds to the road's embankment.)
func test_a_car_in_the_creek_drives_out_along_it() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var trail := level.trail.trail
	var field := level.trail.field
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var distance := 820.0
	var centre := TerrainField.creek_point(sampler, trail, distance)
	var along := sampler.forward(distance)
	var spot := Vector3(centre.x, field.height_at(centre.x, centre.y) + 1.0, centre.y)
	await TrailScenarios.place(level, Transform3D(Basis.looking_at(Vector3(along.x, 0.0, along.z)), spot))
	var out_of_channel := trail.creek_width * 0.5 + TerrainField.CREEK_BANK
	var seconds := 10.0
	for tick in ScenarioHelper.ticks(10.0):
		if field.creek_distance_at(car.global_position.x, car.global_position.z) > out_of_channel:
			seconds = tick / float(Engine.physics_ticks_per_second)
			break
		car.input.virtual_steer = 0.0
		car.input.virtual_throttle = 1.0
		car.input.virtual_brake = 0.0
		await get_tree().physics_frame
	gut.p("out of the creek channel in %.1f s" % seconds)
	assert_lt(seconds, 10.0, "the creek channel is shallow enough to drive out of")


func test_the_road_carries_on_past_the_finish() -> void:
	var level := _load()
	var sampler := level.trail.sampler
	var car := level.rig.car
	await TrailScenarios.wait_for_go(level)
	var finish := level.trail.checkpoints.gate_distances[-1]
	await TrailScenarios.place_on_road(level, finish - 150.0)
	await TrailScenarios.full_throttle_until(level, 30.0,
			func() -> bool: return sampler.closest_distance(car.global_position) >= finish)
	var speed := car.forward_speed()
	await TrailScenarios.brake_to_stop(level)
	var stopped_at := sampler.closest_distance(car.global_position)
	gut.p("crossed the finish at %.0f km/h and stopped %.0f m past it (road ends %.0f m past it)" % [
		speed * 3.6, stopped_at - finish, sampler.length - finish])
	assert_lt(stopped_at, sampler.length - 5.0, "stops on the run-off")
	assert_lt(absf(sampler.lateral_offset(car.global_position)), level.trail.trail.half_total_width())
