extends GutTest
## Coastal-only structures: visible support, ordinary traversal and rebuilds.

const LEVEL := preload("res://levels/coastal_highway/coastal_highway.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/rally.tres"),
	preload("res://car/cars/rally_tuned.tres"), preload("res://car/cars/offroad_4x4.tres")]


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _level(car_def: CarDef) -> RunLevel:
	var level: RunLevel = LEVEL.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func test_tunnel_cover_portals_floor_and_lamps_leave_the_open_runup_unchanged() -> void:
	var level := _level(CARS[0])
	await wait_physics_frames(2)
	var trail := level.trail
	var tunnel: TunnelDef = trail.trail.tunnels[0]
	assert_eq(tunnel.start, 610.0)
	assert_eq(tunnel.end(), 710.0)
	assert_eq(tunnel.inner_width, 10.5)
	assert_eq(tunnel.height, 6.0)
	assert_eq(trail.tunnel_builder.lamp_distances.size(), 8)
	assert_true(tunnel.omit_earth_joins)
	assert_true(trail.tunnel_builder.find_children("*", "Light3D", true, false).is_empty())
	var space := level.get_world_3d().direct_space_state
	for at: float in [598.0, 610.0, 620.0, 660.0, 700.0, 710.0, 722.0, 730.0]:
		var centre := trail.sampler.position(at)
		for lateral: float in [-3.0, 0.0, 3.0]:
			var p := trail.sampler.surface_point(at, lateral, trail.profile)
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP, p - Vector3.UP))
			assert_false(floor_hit.is_empty(), "dry road through portal %.1f / %.1f" % [at, lateral])
			if not floor_hit.is_empty():
				assert_lt(floor_hit.position.distance_to(p), 0.01)
		if at >= tunnel.start and at <= tunnel.end():
			assert_gte(trail.field.height_at(centre.x, centre.z) - centre.y, tunnel.height + tunnel.cover - 0.01)
	for at: float in [610.0, 710.0]:
		for lateral: float in [-3.0, 0.0, 3.0]:
			var p := trail.sampler.position(at) + trail.sampler.right(at) * lateral + Vector3.UP * 1.5
			var direction := trail.sampler.forward(at)
			assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(p - direction * 15, p + direction * 15)).is_empty(),
				"opening is not blocked by roof terrain, portal or earth joins")
	var ceiling := trail.sampler.position(660.0)
	for side: float in [-1.0, 1.0]:
		var floor_point := ceiling + trail.sampler.right(660.0) * side * 5.0
		var return_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point + Vector3.UP, floor_point - Vector3.UP))
		assert_false(return_hit.is_empty(), "floor return supports the space between shoulder and wall")
		if not return_hit.is_empty():
			assert_almost_eq(return_hit.position.y, floor_point.y, 0.01)
	var roof_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ceiling + Vector3.UP, ceiling + Vector3.UP * 8))
	assert_false(roof_hit.is_empty())
	if not roof_hit.is_empty():
		assert_almost_eq(roof_hit.position.y - ceiling.y, 6.0, 0.1)
	assert_true(trail.water_world.bodies.is_empty())
	assert_eq(trail.water_world.wave_binding_count(), 0)


func test_all_cars_reach_jump_through_tunnel_from_the_real_course_start() -> void:
	for car_def: CarDef in CARS:
		var level := _level(car_def)
		for strength: float in [0.0, 0.15, 0.20, 1.0]:
			var result := await CoastalGapProbe.new().attempt(level, strength, false, 0.0, 1.0, false, true, true)
			var label := "%s TC %.0f%% from course" % [car_def.id, strength * 100.0]
			assert_almost_eq(result.start_distance, 10.0, 1.0, label)
			assert_lt(result.start_speed, 0.5)
			assert_gt(result.tunnel_ticks, 100, label + " traversed the tunnel")
			assert_eq(result.tunnel_contacts, 0, label + " no shell/floor chassis hit")
			assert_lt(result.tunnel_camera_height, 5.8, label + " camera below ceiling")
			assert_lt(result.tunnel_max_lateral, 1.0, label + " stays centred")
			assert_gt(result.tunnel_min_up, 0.95)
			assert_true(result.reached, label + " reaches jump recovery")
			assert_true(result.upright)
			assert_eq(result.resets, 0)
			assert_gt(result.unsupported_seconds, 0.2)
			assert_gte(result.landing_contact_distance, 873.0)
			assert_gt(result.min_up, 0.70)
			assert_lt(result.max_lateral, 3.5)
			assert_lt(result.longest_chassis_seconds, 0.40)
			assert_gt(result.min_recovery_speed, 8.0)
			assert_lt(result.peak_landing_yaw, 20.0)
		level.queue_free()
		await wait_process_frames(3)


func test_revised_bridge_has_flush_support_at_new_ends_and_an_open_taller_arch() -> void:
	var level := _level(CARS[0])
	await wait_physics_frames(2)
	var sampler := level.trail.sampler
	var profile := level.trail.profile
	var bridge: StoneBridgeDef = level.trail.trail.stone_bridges[0]
	var space := level.get_world_3d().direct_space_state
	for at: float in [2053.99, 2054.01, 2057.0, 2060.0, 2064.0, 2071.0, 2073.99, 2074.01]:
		for lateral: float in [-3.0, 0.0, 3.0]:
			var p := sampler.surface_point(at, lateral, profile)
			var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p - Vector3.UP * 0.3)
			var hit := space.intersect_ray(query)
			assert_false(hit.is_empty(), "new span support %.2f / %.1f" % [at, lateral])
			if hit.is_empty():
				continue
			assert_lt(hit.position.distance_to(p), 0.002, "visible and physical deck match")
			assert_eq((hit.collider.get_meta(SurfaceLookup.META_KEY) as SurfaceDef).id, &"asphalt")
			query.exclude = [hit.rid]
			assert_true(space.intersect_ray(query).is_empty(), "no duplicate terrain/road support")
	var centre := sampler.position(bridge.start + bridge.length * 0.5)
	var across := sampler.right(bridge.start + bridge.length * 0.5)
	var passage := centre - Vector3.UP * 3.0
	assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(
		passage - across * 18.0, passage + across * 18.0)).is_empty(), "arch is physically open")
	var ceiling := space.intersect_ray(PhysicsRayQueryParameters3D.create(passage, centre))
	assert_false(ceiling.is_empty())
	if not ceiling.is_empty():
		assert_almost_eq(ceiling.position.y, centre.y - bridge.crown_thickness, 0.003)
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(passage, passage - Vector3.UP * 5.0))
	assert_false(floor_hit.is_empty())
	if not floor_hit.is_empty():
		assert_almost_eq(floor_hit.position.y, centre.y - bridge.channel_depth, 0.003)


func test_all_cars_cross_the_stone_bridge_slowly_and_at_road_speed() -> void:
	for car_def: CarDef in CARS:
		var level := _level(car_def)
		assert_true(level.trail.build_phases.has(&"stone_bridges"))
		for speed: float in [6.0, 20.0]:
			var result := await CoastalBridgeProbe.new().attempt(level, 0.20, speed)
			_assert_bridge(result)
		level.queue_free()
		await wait_process_frames(3)


func test_bridge_off_centre_approaches_and_preview_reset_use_the_real_checkpoint() -> void:
	var level := _level(CARS[2])
	for side: float in [-2.0, 2.0]:
		_assert_bridge(await CoastalBridgeProbe.new().attempt(level, 0.20, 20.0, side))
	level.resets.reset_car(&"button")
	assert_almost_eq(level.trail.sampler.closest_distance(level.rig.car.position), 1970.0, 0.02)
	assert_lt(level.rig.car.linear_velocity.length(), 0.01)
	assert_true(level.trail.water_world.bodies.is_empty())
	assert_eq(level.trail.water_world.wave_binding_count(), 0)


func _assert_bridge(result: Dictionary) -> void:
	var label := "%s bridge at %.1f m/s, lateral %.1f" % [result.car, result.wanted_speed, result.lateral_start]
	assert_almost_eq(result.start_distance, 1970.0, 1.0, label + " actual reset")
	assert_lt(result.start_speed, 0.5)
	assert_true(result.reached, label + " completes crossing and recovery")
	assert_true(result.upright)
	assert_eq(result.resets, 0)
	assert_gt(result.crossing_ticks, 100)
	assert_gte(result.min_wheels, 2, label + " no forced mid-bridge jump")
	assert_gt(result.min_up, 0.95)
	assert_lt(result.max_lateral, absf(result.lateral_start) + 0.5)
	assert_gt(result.min_speed, result.wanted_speed - 2.0)
	assert_eq(result.chassis_ticks, 0, label + " no snag at either joint")
	assert_eq(result.wrong_surface_ticks, 0, label + " asphalt, not logs or hidden terrain")
