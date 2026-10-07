class_name CoastalSurfaceProbe
extends RefCounted
## Normal-controls dry surface check from an actual approach checkpoint.
## No velocity injection, assistance or changes to the player's controls.

var samples: Array[Dictionary] = []


static func checkpoint_index(level: RunLevel, climb: bool) -> int:
	var stretch: SurfaceStretch = level.trail.trail.surface_stretches[1 if climb else 0]
	var index := 0
	for i in level.trail.trail.checkpoint_distances.size():
		if level.trail.trail.checkpoint_distances[i] < stretch.start:
			index = i + 1
	return index


func attempt(level: RunLevel, strength: float, climb: bool = false) -> Dictionary:
	var tree := level.get_tree()
	var car := level.rig.car
	var sampler := level.trail.sampler
	var profile := level.trail.profile
	var stretch: SurfaceStretch = profile.def.surface_stretches[1 if climb else 0]
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 0.0
	while level.run.clock.stage == RunClock.Stage.COUNTDOWN:
		await tree.physics_frame
	level.tracker.restart()
	for i in range(1, checkpoint_index(level, climb) + 1):
		level.tracker.enter_gate(i)
	level.resets.reset_car(&"coastal_surface_probe")
	var reset_distance := sampler.closest_distance(car.position)
	car.drivetrain.traction_control_strength = strength
	for tick in Engine.physics_ticks_per_second:
		await tree.physics_frame
	var resets := [0]
	var count_reset := func(_reason: StringName) -> void: resets[0] += 1
	level.resets.car_reset.connect(count_reset)
	car.max_contacts_reported = 8
	car.contact_monitor = true
	var result := {"car": String(level.rig.car_def.id), "tc": strength, "climb": climb,
		"reset_distance": reset_distance,
		"start_distance": sampler.closest_distance(car.position), "start_speed": car.linear_velocity.length(),
		"reached": false, "upright": false, "resets": 0, "min_up": 1.0, "max_lane_fraction": 0.0,
		"chassis_ticks": 0, "sand_contacts": 0, "wrong_surface_ticks": 0, "longest_air_seconds": 0.0}
	var driver := TrailDriver.new(car, sampler, profile)
	var airborne := 0
	samples.clear()
	for tick in Engine.physics_ticks_per_second * 140:
		driver.drive()
		await tree.physics_frame
		var at := sampler.closest_distance(car.position)
		result.min_up = minf(result.min_up, car.global_basis.y.y)
		result.max_lane_fraction = maxf(result.max_lane_fraction,
			absf(sampler.lateral_offset(car.position)) / profile.def.half_total_width_at(at))
		result.chassis_ticks += 1 if car.get_contact_count() > 0 else 0
		var wheels := 0
		for wheel: Wheel in car.wheels:
			if wheel.in_contact:
				wheels += 1
				if wheel.surface.id == &"coastal_sand":
					result.sand_contacts += 1
				if at > stretch.start + 5.0 and at < stretch.end() - 5.0 and wheel.surface.id != &"coastal_sand":
					result.wrong_surface_ticks += 1
		airborne = airborne + 1 if wheels == 0 else 0
		result.longest_air_seconds = maxf(result.longest_air_seconds, airborne / float(Engine.physics_ticks_per_second))
		if tick % 8 == 0:
			samples.append({"tick": tick, "distance": at, "speed": car.forward_speed(), "wheels": wheels})
		if at >= stretch.end() + 25.0:
			result.reached = true
			break
		if resets[0] > 0:
			break
	result.resets = resets[0]
	result.upright = car.global_basis.y.y > 0.8
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 0.0
	car.input.virtual_steer = 0.0
	level.resets.car_reset.disconnect(count_reset)
	print("COASTAL_SURFACE ", JSON.stringify(result))
	return result
