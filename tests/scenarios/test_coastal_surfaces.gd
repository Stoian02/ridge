extends GutTest
## Actual visible/colliding support and all-car dry-sand driving, not just data.

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


func test_all_cars_drive_both_sand_sections_and_their_transitions() -> void:
	for car_def: CarDef in CARS:
		var level := _level(car_def)
		for climb: bool in [false, true]:
			var result := await CoastalSurfaceProbe.new().attempt(level, 0.20, climb)
			var label := "%s climb=%s" % [car_def.id, climb]
			assert_almost_eq(result.reset_distance, 2240.0 if climb else 1330.0, 0.03, label)
			assert_lt(absf(result.start_distance - result.reset_distance), 0.1, "settling drift before inputs")
			assert_lt(result.start_speed, 0.5)
			assert_true(result.reached, label)
			assert_true(result.upright, label)
			assert_eq(result.resets, 0, label)
			assert_gt(result.min_up, 0.85, label)
			assert_lt(result.max_lane_fraction, 0.9, label)
			assert_eq(result.chassis_ticks, 0, label)
			assert_gt(result.sand_contacts, 1000, label)
			assert_eq(result.wrong_surface_ticks, 0, label)
			assert_lt(result.longest_air_seconds, 0.15, label)
		assert_true(level.trail.water_world.bodies.is_empty())
		level.queue_free()
		await wait_process_frames(3)


func test_boundaries_shoulders_and_depressions_have_honest_single_support() -> void:
	var level := _level(CARS[0])
	await wait_physics_frames(2)
	var trail := level.trail
	var space := level.get_world_3d().direct_space_state
	for stretch: SurfaceStretch in trail.trail.surface_stretches:
		for boundary: float in [stretch.start, stretch.end()]:
			for offset: float in [-8.0, -0.02, 0.02, 8.0]:
				var at := boundary + offset
				var half := trail.trail.road_width_at(at) * 0.5
				for lateral: float in [-half - 0.5, -1.0, 0.0, 1.0, half + 0.5]:
					var p := trail.sampler.surface_point(at, lateral, trail.profile)
					var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP, p - Vector3.UP))
					assert_false(hit.is_empty())
					if hit.is_empty():
						continue
					assert_lt(hit.position.distance_to(p), 0.015, "flush visible support near %.2f / %.2f" % [at, lateral])
					var expected: StringName = &"coastal_sand" if stretch.contains(at) else (&"dirt" if absf(lateral) > half else &"asphalt")
					assert_eq(SurfaceLookup.surface_of(hit.collider).id, expected, "physics follows exact authored boundary")
	# Every authored pothole: probe its nearest actual mesh vertex, including
	# small pits the evenly spaced triangle sampling below could otherwise miss.
	var rows := RoadBuilder.row_distances(trail.sampler.length, trail.profile, trail.trail)
	var stations := RoadBuilder.cross_section(trail.trail)
	for hole: Vector4 in trail.profile.damage_potholes:
		var index := mini(rows.bsearch(hole.x), rows.size() - 1)
		if index > 0 and absf(rows[index - 1] - hole.x) < absf(rows[index] - hole.x):
			index -= 1
		var at := rows[index]
		var scales := RoadBuilder.width_scales(trail.trail, at)
		var nearest := INF
		for station: Vector2 in stations:
			if int(station.y) == RoadBuilder.Part.SHOULDER:
				continue
			var lateral := RoadBuilder.station_lateral(station, trail.trail.road_width * 0.5, scales.x, scales.y)
			if absf(lateral - hole.y) < absf(nearest - hole.y):
				nearest = lateral
		assert_lt(trail.profile.pothole_height(at, nearest), 0.0, "probe is inside the depression")
		var p := trail.sampler.surface_point(at, nearest, trail.profile)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP, p - Vector3.UP * 0.1))
		assert_false(hit.is_empty())
		if not hit.is_empty():
			assert_lt(hit.position.distance_to(p), 0.002, "terrain cannot fill a drawn pothole")
	# Probe the actually drawn triangles, not the analytic profile between mesh rows.
	var probes := 0
	for child: Node in trail.road_builder.get_children():
		if not child is MeshInstance3D:
			continue
		var faces: PackedVector3Array = child.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3 * 137):
			var p := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP, p - Vector3.UP * 0.05)
			var hit := space.intersect_ray(query)
			assert_false(hit.is_empty())
			if hit.is_empty():
				continue
			assert_lt(hit.position.distance_to(p), 0.002, "no terrain above the drawn triangle")
			query.from = p + Vector3.UP * 0.01
			query.to = p - Vector3.UP * 0.01
			query.exclude = [hit.rid]
			assert_true(space.intersect_ray(query).is_empty(), "one supporting surface, not stacked sheets")
			probes += 1
	assert_gt(probes, 100)
	assert_true(trail.profile.patches.is_empty())
	assert_true(trail.water_world.bodies.is_empty())
