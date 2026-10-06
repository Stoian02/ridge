class_name CoastalGapProbe
extends RefCounted
## Opt-in measurements through normal inputs and the actual checkpoint Reset.
## No velocity injection, physics tuning, progress writes or player assistance.

var samples: Array[Dictionary] = []


func attempt(level: RunLevel, strength: float, hold_in_air: bool = false,
		lateral: float = 0.0, throttle: float = 1.0, hold_lane: bool = false) -> Dictionary:
	var tree := level.get_tree()
	var car := level.rig.car
	var sampler := level.trail.sampler
	var gap: RoadGapDef = level.trail.trail.road_gaps[0]
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	car.input.virtual_throttle = 0.0
	# Both pedals released engages the car's existing auto-hold. Holding the
	# brake at rest requests reverse; it is not a stationary settling input.
	car.input.virtual_brake = 0.0
	for tick in Engine.physics_ticks_per_second * 5:
		if level.run.clock.stage != RunClock.Stage.COUNTDOWN:
			break
		await tree.physics_frame
	if level.run.clock.stage != RunClock.Stage.RUNNING:
		push_error("Coastal probe requires a running countdown; refusing a fabricated launch")
		return {}
	level.tracker.restart()
	level.tracker.enter_gate(1)
	level.resets.reset_car(&"coastal_probe")
	car.drivetrain.traction_control_strength = strength
	if lateral != 0.0:
		# Perturb only the initial reset placement for off-centre robustness cases.
		var pose := level.tracker.reset_transform()
		pose.origin += pose.basis.x * lateral
		level.rig.place_car(pose)
	for tick in roundi(Engine.physics_ticks_per_second * 1.0):
		await tree.physics_frame
	var resets := [0]
	var count_reset := func(_reason: StringName) -> void: resets[0] += 1
	level.resets.car_reset.connect(count_reset)
	car.max_contacts_reported = 8
	car.contact_monitor = true
	var result := {"car": String(level.rig.car_def.id), "tc": strength,
		"held": hold_in_air, "lateral_start": lateral, "throttle": throttle,
		"start_distance": sampler.closest_distance(car.global_position),
		"start_speed": car.linear_velocity.length(), "lip_speed": 0.0,
		"takeoff": 0.0, "landing": 0.0, "air_seconds": 0.0,
		"min_up": 1.0, "max_lateral": 0.0, "peak_landing_yaw": 0.0,
		"chassis_ticks": 0, "first_chassis_distance": -1.0,
		"last_chassis_distance": -1.0, "longest_chassis_seconds": 0.0,
		"landing_contact_distance": 0.0, "min_recovery_speed": INF,
		"start_position": [car.position.x, car.position.y, car.position.z],
		"start_forward": [-car.basis.z.x, -car.basis.z.y, -car.basis.z.z],
		"min_pitch": 0.0, "max_pitch": 0.0,
		"resets": 0, "reached": false, "upright": false}
	var took_off := false
	var landed := false
	var air_ticks := 0
	var lowest_up := 1.0
	var largest_lateral := 0.0
	var chassis_ticks := 0
	var contact_streak := 0
	var longest_contact := 0
	var peak_yaw := 0.0
	samples.clear()
	for tick in roundi(30.0 * Engine.physics_ticks_per_second):
		var distance := sampler.closest_distance(car.global_position)
		var target_point := sampler.position(distance + 12.0)
		if hold_lane:
			target_point += sampler.right(distance + 12.0) * lateral
		var target := target_point - car.global_position
		var heading := -car.global_basis.z
		var angle := Vector2(heading.x, heading.z).normalized().angle_to(Vector2(target.x, target.z).normalized())
		var max_angle := Steering.max_angle_for_speed(car.forward_speed(), car.stats)
		car.input.virtual_steer = clampf(angle / maxf(max_angle, 0.05), -1.0, 1.0)
		car.input.virtual_brake = 0.0
		car.input.virtual_throttle = throttle if hold_in_air or distance < gap.takeoff_end or landed else 0.0
		await tree.physics_frame
		distance = sampler.closest_distance(car.global_position)
		var contacts := 0
		for wheel: Wheel in car.wheels:
			if wheel.in_contact:
				contacts += 1
		if distance < gap.takeoff_end:
			result["lip_speed"] = car.forward_speed()
		if distance >= gap.takeoff_end - 4.0 and contacts == 0 and not took_off:
			took_off = true
			result["takeoff"] = distance
		if took_off and not landed:
			if contacts == 0:
				air_ticks += 1
			elif air_ticks > 6:
				landed = true
				result["landing"] = distance
				result.landing_contact_distance = INF
				for wheel: Wheel in car.wheels:
					if wheel.in_contact:
						result.landing_contact_distance = minf(result.landing_contact_distance,
							sampler.closest_distance(wheel.contact_point))
		if took_off:
			var pitch := rad_to_deg(asin(clampf(-car.global_basis.z.y, -1.0, 1.0)))
			result.min_pitch = minf(result.min_pitch, pitch)
			result.max_pitch = maxf(result.max_pitch, pitch)
			lowest_up = minf(lowest_up, car.global_basis.y.y)
			largest_lateral = maxf(largest_lateral, absf(sampler.lateral_offset(car.global_position)))
			if landed:
				peak_yaw = maxf(peak_yaw, absf(rad_to_deg(car.angular_velocity.y)))
				result.min_recovery_speed = minf(result.min_recovery_speed, car.forward_speed())
		if car.get_contact_count() > 0:
			chassis_ticks += 1
			contact_streak += 1
			longest_contact = maxi(longest_contact, contact_streak)
			if float(result.first_chassis_distance) < 0.0:
				result.first_chassis_distance = distance
			result.last_chassis_distance = distance
		else:
			contact_streak = 0
		if tick % 4 == 0:
			samples.append({"tick": tick, "distance": distance, "speed": car.forward_speed(),
				"position": [car.global_position.x, car.global_position.y, car.global_position.z],
				"contacts": contacts, "up": car.global_basis.y.y, "body_contacts": car.get_contact_count()})
		if distance >= gap.recovery_end and landed:
			result["reached"] = true
			break
		if resets[0] > 0 or car.global_position.y < gap.floor_height(sampler, level.trail.profile) + 2.0:
			break
	result["air_seconds"] = air_ticks / float(Engine.physics_ticks_per_second)
	result["air_distance"] = float(result["landing"]) - float(result["takeoff"]) if landed else 0.0
	result["min_up"] = lowest_up
	result["max_lateral"] = largest_lateral
	result["peak_landing_yaw"] = peak_yaw
	result["chassis_ticks"] = chassis_ticks
	result.longest_chassis_seconds = longest_contact / float(Engine.physics_ticks_per_second)
	result["resets"] = resets[0]
	result["upright"] = car.global_basis.y.y > 0.8
	result["end_distance"] = sampler.closest_distance(car.global_position)
	car.input.virtual_throttle = 0.0
	car.input.virtual_brake = 1.0
	car.input.virtual_steer = 0.0
	level.resets.car_reset.disconnect(count_reset)
	print("COASTAL_GAP ", JSON.stringify(result))
	return result
