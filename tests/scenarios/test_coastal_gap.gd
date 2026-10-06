extends GutTest

const LEVEL := preload("res://levels/coastal_highway/coastal_highway.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/rally.tres"),
	preload("res://car/cars/rally_tuned.tres"), preload("res://car/cars/offroad_4x4.tres")]
const STRENGTHS: Array[float] = [0.0, 0.15, 0.20, 1.0]


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _level(car_def: CarDef) -> RunLevel:
	var level: RunLevel = LEVEL.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	assert_true(level.trail.water_world.bodies.is_empty(), "B1 has no water bodies")
	assert_eq(level.trail.water_world.wave_binding_count(), 0)
	return level


func _assert_crossing(result: Dictionary) -> void:
	var label := "%s TC %.0f%% held=%s" % [result.car, result.tc * 100.0, result.held]
	assert_true(result.reached, label + " reaches recovery under normal inputs")
	assert_true(result.upright, label + " upright after landing")
	assert_gt(result.air_seconds, 0.20, label + " genuinely airborne")
	assert_gte(result.landing_contact_distance, 869.0, label + " wheel contact has >=2 m far-bank margin")
	assert_eq(result.resets, 0, label + " no reset disguises failure")
	assert_lt(result.start_speed, 0.5, label + " starts at rest, not injected speed")
	assert_almost_eq(result.start_distance, 730.0, 1.0, label + " actual checkpoint reset")
	assert_gt(result.min_up, 0.70, label + " no severe pitch/roll")
	assert_lt(result.max_lateral, 3.5, label + " stays on the actual landing")
	# Record bottom-outs, but do not confuse momentary chassis contact with a
	# wedge. The owner still judges landing harshness at this greybox stop.
	assert_lt(result.longest_chassis_seconds, 0.40, label + " no sustained chassis wedge")
	assert_gt(result.min_recovery_speed, 8.0, label + " landing retains forward motion")
	assert_lt(result.peak_landing_yaw, 20.0, label + " no spin kick on landing")


func test_all_cars_clear_from_reset_at_off_owner_range_and_full_tc() -> void:
	for car_def: CarDef in CARS:
		var level := _level(car_def)
		for strength: float in STRENGTHS:
			for repeat in 3:
				var probe := CoastalGapProbe.new()
				var result := await probe.attempt(level, strength)
				_assert_crossing(result)
		level.queue_free()
		await wait_process_frames(3)


func test_held_throttle_is_tested_explicitly_not_marked_pending() -> void:
	for car_def: CarDef in CARS:
		var level := _level(car_def)
		for strength: float in STRENGTHS:
			var result := await CoastalGapProbe.new().attempt(level, strength, true)
			_assert_crossing(result)
		level.queue_free()
		await wait_process_frames(3)


func test_off_centre_launch_and_failed_slow_approach_have_honest_outcomes() -> void:
	var level := _level(CARS[2])
	for side: float in [-2.0, 2.0]:
		var result := await CoastalGapProbe.new().attempt(level, 0.20, false, side, 1.0, true)
		_assert_crossing(result)
	var failed := await CoastalGapProbe.new().attempt(level, 0.20, false, 0.0, 0.12)
	assert_false(failed.reached, "too little approach speed must not receive hidden assistance")
	level.resets.reset_car(&"button")
	assert_almost_eq(level.trail.sampler.closest_distance(level.rig.car.position), 730.0, 0.01)
	assert_lt(level.rig.car.linear_velocity.length(), 0.01)
	level.rig.car.input.virtual_brake = 0.0
	await wait_physics_frames(240)
	assert_almost_eq(level.trail.sampler.closest_distance(level.rig.car.position), 730.0, 0.1,
		"stopped on the approach remains at rest using ordinary auto-hold")


func test_ravine_has_no_side_support_or_under_road_bypass() -> void:
	var level := _level(CARS[2])
	await wait_physics_frames(370)
	var sampler := level.trail.sampler
	var gap: RoadGapDef = level.trail.trail.road_gaps[0]
	var space := level.get_world_3d().direct_space_state
	for side: float in [-70.0, -20.0, -8.0, 0.0, 8.0, 20.0, 70.0]:
		var p := sampler.position(861.0) + sampler.right(861.0) * side
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4, p - Vector3.UP * 5))
		assert_true(hit.is_empty(), "no road-height bypass at lateral %.1f" % side)
	# Challenge the far face from the dry floor, including outside the road cap.
	for side: float in [-20.0, 0.0, 20.0]:
		level.tracker.restart()
		level.tracker.enter_gate(1)
		var pose := level.tracker.reset_transform()
		pose.origin = sampler.position(860.0) + sampler.right(860.0) * side
		pose.origin.y = gap.floor_height(sampler, level.trail.profile) + 1.2
		level.rig.place_car(pose)
		level.rig.car.input.virtual_brake = 0.0
		level.rig.car.input.virtual_throttle = 1.0
		await wait_physics_frames(600)
		var padded_bank_end := gap.landing_start + level.trail.field.spacing * sqrt(2.0) \
			+ level.trail.field.spacing + level.rig.car.stats.body_size.z * 0.5
		gut.p("Ravine side %.1f: station %.3f, height %.3f; bank footprint ends %.3f" % [
			side, sampler.closest_distance(level.rig.car.position), level.rig.car.position.y, padded_bank_end])
		assert_eq(level.tracker.last_passed, 1, "cannot earn the landing gate from underneath")
		assert_lt(sampler.closest_distance(level.rig.car.position), padded_bank_end,
			"cannot crawl past the conservatively padded terrain bank")
		level.rig.car.input.virtual_throttle = 0.0
		level.resets.reset_car(&"button")
		assert_almost_eq(sampler.closest_distance(level.rig.car.position), 730.0, 0.01)


func test_preview_restart_car_selection_pause_and_exit_keep_progress_untouched() -> void:
	var scene := load("res://debug/coastal_playcheck.tscn") as PackedScene
	var preview: RunLevel = scene.instantiate()
	add_child(preview)
	preview.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	assert_null(preview.level)
	assert_eq(preview.tracker.last_passed, 1)
	preview.run.restart()
	assert_eq(preview.tracker.last_passed, 1)
	assert_almost_eq(preview.trail.sampler.closest_distance(preview.rig.car.position), 730.0, 0.01)
	preview.pause_menu.open()
	assert_true(get_tree().paused)
	preview.pause_menu.close()
	assert_false(get_tree().paused)
	preview._change_car()
	assert_eq(GameState.pending_scene, "res://debug/coastal_playcheck.tscn")
	assert_false(SaveSandbox.requested_scenes.is_empty())
	var weak: WeakRef = weakref(preview.rig.audio)
	remove_child(preview)
	preview.free()
	await wait_process_frames(3)
	assert_null(weak.get_ref(), "preview audio and callbacks are released on exit")
