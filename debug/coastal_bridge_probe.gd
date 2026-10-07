class_name CoastalBridgeProbe
extends RefCounted
## Opt-in dry bridge traversal through normal controls from its actual checkpoint.

var samples: Array[Dictionary] = []


static func checkpoint_index(level: RunLevel) -> int:
	var bridge: StoneBridgeDef = level.trail.trail.stone_bridges[0]
	var index := 0
	for i in level.trail.trail.checkpoint_distances.size():
		if level.trail.trail.checkpoint_distances[i] < bridge.start:
			index = i + 1
	return index


func attempt(level: RunLevel, strength: float, speed: float = 20.0, lateral: float = 0.0) -> Dictionary:
	var tree := level.get_tree()
	var car := level.rig.car
	var sampler := level.trail.sampler
	var bridge: StoneBridgeDef = level.trail.trail.stone_bridges[0]
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 0.0
	for tick in Engine.physics_ticks_per_second * 5:
		if level.run.clock.stage != RunClock.Stage.COUNTDOWN:
			break
		await tree.physics_frame
	assert(level.run.clock.stage == RunClock.Stage.RUNNING)
	level.tracker.restart()
	# Reach the chosen reset through the normal ordered tracker API.
	for i in range(1, checkpoint_index(level) + 1):
		level.tracker.enter_gate(i)
	level.resets.reset_car(&"coastal_bridge_probe")
	car.drivetrain.traction_control_strength = strength
	if lateral != 0.0:
		var pose := level.tracker.reset_transform()
		pose.origin += pose.basis.x * lateral
		level.rig.place_car(pose)
	for tick in Engine.physics_ticks_per_second:
		await tree.physics_frame
	var resets := [0]
	var count_reset := func(_reason: StringName) -> void: resets[0] += 1
	level.resets.car_reset.connect(count_reset)
	car.max_contacts_reported = 8
	car.contact_monitor = true
	var result := {"car": String(level.rig.car_def.id), "tc": strength, "wanted_speed": speed,
		"lateral_start": lateral, "start_distance": sampler.closest_distance(car.global_position),
		"start_speed": car.linear_velocity.length(), "crossing_ticks": 0, "min_wheels": 4,
		"min_up": 1.0, "max_lateral": 0.0, "min_speed": INF, "max_speed": 0.0,
		"chassis_ticks": 0, "wrong_surface_ticks": 0, "resets": 0, "reached": false, "upright": false}
	samples.clear()
	for tick in Engine.physics_ticks_per_second * 40:
		var distance := sampler.closest_distance(car.global_position)
		var target := sampler.position(distance + 12.0) + sampler.right(distance + 12.0) * lateral - car.global_position
		var heading := -car.global_basis.z
		var angle := Vector2(heading.x, heading.z).normalized().angle_to(Vector2(target.x, target.z).normalized())
		car.input.virtual_steer = clampf(angle / maxf(Steering.max_angle_for_speed(car.forward_speed(), car.stats), 0.05), -1.0, 1.0)
		car.input.virtual_throttle = 1.0 if car.forward_speed() < speed - 0.5 else 0.0
		car.input.virtual_brake = 1.0 if car.forward_speed() > speed + 1.0 else 0.0
		await tree.physics_frame
		distance = sampler.closest_distance(car.global_position)
		if distance >= bridge.start - 4.0 and distance <= bridge.end() + 4.0:
			result.crossing_ticks += 1
			var wheels := 0
			for wheel: Wheel in car.wheels:
				if wheel.in_contact:
					wheels += 1
					if wheel.surface.id != &"asphalt":
						result.wrong_surface_ticks += 1
			result.min_wheels = mini(result.min_wheels, wheels)
			result.min_up = minf(result.min_up, car.global_basis.y.y)
			result.max_lateral = maxf(result.max_lateral, absf(sampler.lateral_offset(car.global_position)))
			result.min_speed = minf(result.min_speed, car.forward_speed())
			result.max_speed = maxf(result.max_speed, car.forward_speed())
			result.chassis_ticks += 1 if car.get_contact_count() > 0 else 0
		if tick % 4 == 0:
			samples.append({"tick": tick, "distance": distance, "speed": car.forward_speed(),
				"up": car.global_basis.y.y, "body_contacts": car.get_contact_count()})
		if distance >= bridge.end() + 25.0:
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
	print("COASTAL_BRIDGE ", JSON.stringify(result))
	return result
