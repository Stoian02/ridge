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
