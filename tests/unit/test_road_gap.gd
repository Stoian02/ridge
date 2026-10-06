extends GutTest
## True gaps must remove all near-deck support, not just hide a road mesh.


func _fixture(angle: float = 0.0, bank: float = 0.0) -> Dictionary:
	var trail := TrailDef.new()
	trail.shoulder_width = 1.25
	trail.terrain_blend_width = 3.0
	trail.undulation_amplitude = 0.0
	trail.chunk_length = 68.0  # the takeoff lip is also a chunk boundary
	var gap := RoadGapDef.new()
	gap.takeoff_start = 50.0
	gap.takeoff_end = 68.0
	gap.landing_start = 84.0
	gap.landing_end = 144.0
	gap.recovery_end = 180.0
	gap.cut_half_width = 100.0
	trail.road_gaps = [gap]
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3(0, 20, 0))
	curve.add_point(Vector3(0, 20, -220).rotated(Vector3.UP, angle))
	curve.set_point_tilt(0, bank)
	curve.set_point_tilt(1, bank)
	var sampler := RoadSampler.new(curve, true, trail)
	var profile := RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 24.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	var field := TerrainField.generate(sampler, trail, terrain, true, profile)
	return {"trail": trail, "gap": gap, "sampler": sampler, "profile": profile, "field": field}


func test_gap_stations_and_inputs_are_validated_without_changing_old_trails() -> void:
	var f := _fixture()
	var trail: TrailDef = f.trail
	var gap: RoadGapDef = f.gap
	assert_true(trail.gap_validation_errors(220.0).is_empty())
	assert_true(TrailDef.new().gap_validation_errors(10.0).is_empty())
	gap.landing_start = gap.takeoff_end
	assert_false(trail.gap_validation_errors(220.0).is_empty())
	gap.landing_start = 84.0
	gap.rise = NAN
	assert_false(trail.gap_validation_errors(220.0).is_empty())
	gap.rise = 2.0
	trail.road_gaps.append(gap.duplicate())
	assert_false(trail.gap_validation_errors(220.0).is_empty())
	trail.road_gaps.resize(1)
	var bridge := BridgeDef.new()
	bridge.start = 60.0
	trail.bridges = [bridge]
	assert_false(trail.gap_validation_errors(220.0).is_empty())
	trail.bridges.clear()
	var ford := FordDef.new()
	ford.distance = 100.0
	trail.fords = [ford]
	assert_false(trail.gap_validation_errors(220.0).is_empty())
	trail.fords.clear()
	assert_eq(gap.alignment_error(f.sampler), "")
	var bent := Curve3D.new()
	bent.add_point(Vector3(0, 20, 0))
	bent.add_point(Vector3(15, 20, -100))
	bent.add_point(Vector3(0, 20, -220))
	assert_false(gap.alignment_error(RoadSampler.new(bent)).is_empty())


func test_profile_has_an_upward_lip_and_continuous_landing_recovery() -> void:
	var f := _fixture()
	var gap: RoadGapDef = f.gap
	var profile: RoadProfile = f.profile
	assert_eq(gap.height_offset(49.0), 0.0)
	assert_eq(gap.height_offset(50.0), 0.0)
	assert_almost_eq(gap.height_offset(68.0), 2.0, 0.000001)
	assert_almost_eq((gap.height_offset(68.0) - gap.height_offset(67.999)) / 0.001,
			tan(deg_to_rad(14.0)), 0.0001)
	assert_almost_eq(gap.height_offset(84.0), 0.5, 0.000001)
	assert_almost_eq(gap.height_offset(144.0), -0.7, 0.000001)
	assert_almost_eq(gap.height_offset(143.999), gap.height_offset(144.001), 0.00005)
	assert_eq(gap.height_offset(180.0), 0.0)
	assert_true(profile.omits_road(76.0))
	assert_false(profile.omits_road(68.0))
	assert_false(profile.omits_road(84.0))
	assert_eq(profile.surface_at(76.0).id, &"asphalt", "route hint is not logs or proof of support")
	for at: float in gap.boundaries():
		assert_true(profile.exact_rows().has(at))
	var cached := RoadProfile.new(f.trail, 220.0)
	cached.cache_build_samples(true)
	for at: float in [49.0, 50.0, 55.3, 68.0, 76.0, 84.0, 100.1, 144.0, 179.9]:
		for lateral: float in [-4.75, 0.0, 4.75]:
			assert_eq(cached.height(at, lateral), profile.height(at, lateral))


func test_serial_and_threaded_road_and_joins_emit_identical_gap_geometry() -> void:
	var f := _fixture(0.6, 0.06)
	for kind in 2:
		var builders: Array[Node3D] = []
		for threaded: bool in [false, true]:
			var builder: Node3D = RoadBuilder.new() if kind == 0 else RoadBlendBuilder.new()
			builder.set("threaded", threaded)
			add_child_autofree(builder)
			if kind == 0:
				(builder as RoadBuilder).build(f.sampler, f.profile, f.trail)
			else:
				(builder as RoadBlendBuilder).build(f.sampler, f.profile, f.field, f.trail)
			builders.append(builder)
		assert_eq(builders[0].get_child_count(), builders[1].get_child_count())
		for i in builders[0].get_child_count():
			var a := builders[0].get_child(i)
			var b := builders[1].get_child(i)
			if a is MeshInstance3D:
				assert_eq(a.mesh.get_faces(), b.mesh.get_faces())
			elif a is StaticBody3D:
				assert_eq(a.get_child(0).shape.get_faces(), b.get_child(0).shape.get_faces())


func test_actual_physics_support_matches_the_visible_gap_at_every_lateral() -> void:
	for angle: float in [0.0, 0.61]:
		var f := _fixture(angle, 0.04)
		var root := Node3D.new()
		add_child_autofree(root)
		var sampler: RoadSampler = f.sampler
		var profile: RoadProfile = f.profile
		var road := RoadBuilder.new()
		root.add_child(road)
		road.build(sampler, profile, f.trail)
		var joins := RoadBlendBuilder.new()
		root.add_child(joins)
		joins.build(sampler, profile, f.field, f.trail)
		var terrain := TerrainBuilder.new()
		root.add_child(terrain)
		terrain.build(f.field)
		var caps := GapBuilder.new()
		root.add_child(caps)
		caps.build(sampler, profile, f.field, f.trail)
		await wait_physics_frames(2)
		var space := root.get_world_3d().direct_space_state
		for at: float in [68.1, 69.0, 76.0, 83.0, 83.9]:
			for lateral: float in [-8.0, -4.5, 0.0, 4.5, 8.0]:
				var p := sampler.position(at) + sampler.right(at) * lateral
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5, p - Vector3.UP * 5))
				assert_true(hit.is_empty(), "no invisible road/join/terrain support at %.1f / %.1f" % [at, lateral])
		for at: float in [60.0, 67.9, 84.1, 95.0, 150.0]:
			for lateral: float in [-4.0, 0.0, 4.0]:
				var p := sampler.surface_point(at, lateral, profile)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.5, p - Vector3.UP * 0.5))
				assert_false(hit.is_empty(), "approach/landing has real support")
				if not hit.is_empty():
					assert_lt(hit.position.distance_to(p), 0.01)
		var floor_point := sampler.position(76.0)
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point, floor_point - Vector3.UP * 30))
		assert_false(floor_hit.is_empty(), "dry ravine has a visible colliding floor")
		if not floor_hit.is_empty():
			assert_almost_eq(floor_hit.position.y, f.gap.floor_height(sampler, profile), 0.01)
		root.queue_free()
		await wait_process_frames(2)
