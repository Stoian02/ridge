class_name CoastalRouteProbe
extends RefCounted
## Whole-course test driver: only steer/gas/brake, with real gate crossings.
## Never writes tracker progress, car pose, velocity or forces during the drive.

var samples: Array[Dictionary] = []


func attempt(level: RunLevel, strength: float = 0.20) -> Dictionary:
	var tree := level.get_tree()
	var car := level.rig.car
	var sampler := level.trail.sampler
	var gap: RoadGapDef = level.trail.trail.road_gaps[0]
	var driver := TrailDriver.new(car, sampler, level.trail.profile)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	car.drivetrain.traction_control_strength = strength
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 0.0
	level.run.start_transform = level.trail.start_transform()
	level.run.restart()
	while level.run.clock.stage == RunClock.Stage.COUNTDOWN:
		await tree.physics_frame
	var gates: Array[int] = []
	var resets: Array[StringName] = []
	var on_gate := func(index: int) -> void: gates.append(index)
	var on_reset := func(reason: StringName) -> void: resets.append(reason)
	level.tracker.checkpoint_passed.connect(on_gate)
	level.resets.car_reset.connect(on_reset)
	car.max_contacts_reported = 8
	car.contact_monitor = true
	var result := {"car": String(level.rig.car_def.id), "tc": strength,
		"start_distance": sampler.closest_distance(car.global_position),
		"start_speed": car.linear_velocity.length(), "reached": false,
		"min_up": 1.0, "max_lane_fraction": 0.0, "chassis_ticks": 0,
		"takeoff": 0.0, "touchdown": 0.0, "air_seconds": 0.0}
	var flying := false
	var landed := false
	var air_ticks := 0
	samples.clear()
	for tick in 420 * Engine.physics_ticks_per_second:
		var distance := sampler.closest_distance(car.global_position)
		driver.drive()
		if distance >= 580.0 and not landed:
			# Same uncapped tunnel/run-up and owner-style pedal balancing as the
			# accepted opening probe. No boost or automatic player assistance.
			car.input.virtual_throttle = 1.0 if distance < gap.takeoff_end else 0.0
			car.input.virtual_brake = 0.0
			if flying and car.air_control.is_active:
				var pitch := asin(clampf(-car.global_basis.z.y, -1.0, 1.0))
				var rate := car.angular_velocity.dot(car.global_basis.x)
				var correction := clampf((atan(gap.landing_grade) + deg_to_rad(2.0) - pitch) * 5.0 - rate * 3.0, -1.0, 1.0)
				car.input.virtual_throttle = maxf(0.0, correction)
				car.input.virtual_brake = maxf(0.0, -correction)
		await tree.physics_frame
		distance = sampler.closest_distance(car.global_position)
		var wheels := 0
		for wheel: Wheel in car.wheels:
			wheels += int(wheel.in_contact)
		if not flying and distance >= gap.takeoff_end - 4.0 and wheels == 0 and car.get_contact_count() == 0:
			flying = true
			result.takeoff = distance
		if flying and not landed:
			if wheels == 0 and car.get_contact_count() == 0:
				air_ticks += 1
			elif air_ticks > 6:
				landed = true
				result.touchdown = distance
		result.min_up = minf(result.min_up, car.global_basis.y.y)
		result.max_lane_fraction = maxf(result.max_lane_fraction,
			absf(sampler.lateral_offset(car.global_position)) / (level.trail.trail.road_width_at(distance) * 0.5))
		result.chassis_ticks += int(car.get_contact_count() > 0)
		if tick % 12 == 0:
			samples.append({"tick": tick, "distance": distance, "speed": car.forward_speed(),
				"lateral": sampler.lateral_offset(car.global_position), "up": car.global_basis.y.y,
				"gate": level.tracker.last_passed, "body_contacts": car.get_contact_count()})
		if level.run.clock.stage == RunClock.Stage.FINISHED:
			result.reached = true
			break
		if not resets.is_empty():
			break
	result.air_seconds = air_ticks / float(Engine.physics_ticks_per_second)
	result.gates = gates
	result.last_gate = level.tracker.last_passed
	result.expected_last_gate = level.tracker.gate_transforms.size() - 1
	result.splits = level.run.clock.splits.duplicate()
	result.seconds = level.run.clock.elapsed
	result.resets = resets.size()
	result.reset_reasons = resets
	result.upright = car.global_basis.y.y > 0.8
	result.end_distance = sampler.closest_distance(car.global_position)
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 0.0
	car.input.virtual_steer = 0.0
	level.tracker.checkpoint_passed.disconnect(on_gate)
	level.resets.car_reset.disconnect(on_reset)
	print("COASTAL_ROUTE ", JSON.stringify(result))
	return result
