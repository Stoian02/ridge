extends GutTest
## An open arch and a single driveable deck must be true in physics, not just art.


func _fixture(angle: float = 0.0) -> Dictionary:
	var trail := TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.shoulder_width = 1.25
	trail.terrain_blend_width = 3.0
	trail.chunk_length = 70.0
	var bridge := StoneBridgeDef.new()
	bridge.start = 70.0
	trail.stone_bridges = [bridge]
	var curve := Curve3D.new()
	curve.add_point(Vector3(0, 12, 0))
	curve.add_point(Vector3(0, 12, -180).rotated(Vector3.UP, angle))
	var sampler := RoadSampler.new(curve, false, trail)
	var profile := RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 36.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	var field := TerrainField.generate(sampler, trail, terrain, true, profile)
	return {"trail": trail, "bridge": bridge, "sampler": sampler, "profile": profile, "field": field}


func _build(f: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	var road := RoadBuilder.new()
	road.name = "Road"
	root.add_child(road)
	road.build(f.sampler, f.profile, f.trail)
	var joins := RoadBlendBuilder.new()
	joins.name = "Joins"
	root.add_child(joins)
	joins.build(f.sampler, f.profile, f.field, f.trail)
	var ground := TerrainBuilder.new()
	root.add_child(ground)
	ground.build(f.field)
	var bridge := StoneBridgeBuilder.new()
	bridge.name = "StoneBridge"
	root.add_child(bridge)
	bridge.build(f.sampler, f.profile, f.field, f.trail)
	return root


func test_dimensions_alignment_and_overlaps_fail_closed() -> void:
	var f := _fixture()
	var bridge: StoneBridgeDef = f.bridge
	var trail: TrailDef = f.trail
	assert_eq(bridge.validation_error(180.0), "")
	assert_eq(bridge.alignment_error(f.sampler), "")
	assert_true(trail.stone_bridge_validation_errors(180.0).is_empty())
	bridge.crest = NAN
	assert_false(bridge.validation_error(180.0).is_empty())
	bridge.crest = 0.15
	bridge.channel_depth = 2.0
	assert_false(bridge.validation_error(180.0).is_empty())
	bridge.channel_depth = 5.5
	trail.stone_bridges.append(bridge.duplicate())
	assert_false(trail.stone_bridge_validation_errors(180.0).is_empty())
	trail.stone_bridges.resize(1)
	var log_bridge := BridgeDef.new()
	log_bridge.start = 75.0
	trail.bridges = [log_bridge]
	assert_false(trail.stone_bridge_validation_errors(180.0).is_empty())
	trail.bridges.clear()
	var tunnel := TunnelDef.new()
	tunnel.start = 80.0
	trail.tunnels = [tunnel]
	assert_false(trail.stone_bridge_validation_errors(180.0).is_empty())
	trail.tunnels.clear()
	var bad_curve := Curve3D.new()
	bad_curve.add_point(Vector3(0, 12, 0))
	bad_curve.add_point(Vector3(8, 12, -79))
	bad_curve.add_point(Vector3(0, 12, -180))
	assert_false(bridge.alignment_error(RoadSampler.new(bad_curve, false, trail)).is_empty())


func test_profile_is_flush_smooth_asphalt_and_never_log_surface() -> void:
	var f := _fixture()
	var bridge: StoneBridgeDef = f.bridge
	var profile: RoadProfile = f.profile
	assert_eq(bridge.height_offset(70.0), 0.0)
	assert_eq(bridge.height_offset(88.0), 0.0)
	assert_almost_eq(bridge.height_offset(79.0), 0.15, 0.000001)
	assert_lt(bridge.height_offset(70.001) / 0.001, 0.0001)
	assert_lt(bridge.height_offset(87.999) / 0.001, 0.0001)
	assert_true(profile.exact_rows().has(70.0))
	assert_true(profile.exact_rows().has(88.0))
	assert_true(profile.omits_road(79.0))
	assert_false(profile.on_bridge(79.0), "legacy predicate remains logs-only")
	assert_eq(profile.surface_at(79.0).id, &"asphalt")
	var cached := RoadProfile.new(f.trail, 180.0)
	cached.cache_build_samples(true)
	for at: float in [69.9, 70.0, 70.2, 78.2, 79.0, 87.8, 88.0, 88.1]:
		assert_eq(cached.height(at, 1.0), profile.height(at, 1.0))
	var empty := TrailDef.new()
	assert_true(empty.stone_bridges.is_empty())
	assert_true(empty.stone_bridge_validation_errors(180.0).is_empty())


func test_deck_has_one_visible_asphalt_support_and_flush_joints() -> void:
	for angle: float in [0.0, 0.63]:
		var f := _fixture(angle)
		var root := _build(f)
		var sampler: RoadSampler = f.sampler
		var profile: RoadProfile = f.profile
		await wait_physics_frames(2)
		var space := root.get_world_3d().direct_space_state
		for at: float in [69.99, 70.01, 73.0, 78.25, 79.0, 85.0, 87.99, 88.01]:
			for lateral: float in [-3.0, 0.0, 3.0]:
				var p := sampler.surface_point(at, lateral, profile)
				var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p - Vector3.UP * 0.3)
				var hit := space.intersect_ray(query)
				assert_false(hit.is_empty(), "visible deck contact %.2f / %.1f" % [at, lateral])
				if hit.is_empty():
					continue
				assert_lt(hit.position.distance_to(p), 0.002)
				assert_eq((hit.collider.get_meta(SurfaceLookup.META_KEY) as SurfaceDef).id, &"asphalt")
				query.exclude = [hit.rid]
				assert_true(space.intersect_ray(query).is_empty(), "no duplicate road/terrain deck support")
		for builder: Node3D in [root.get_node("Road"), root.get_node("Joins")]:
			for child in builder.get_children():
				if child is MeshInstance3D:
					var faces: PackedVector3Array = child.mesh.get_faces()
					for i in range(0, faces.size(), 3):
						var at := sampler.closest_distance((faces[i] + faces[i + 1] + faces[i + 2]) / 3.0)
						assert_false(at > 70.001 and at < 87.999, "ordinary road/shoulder/earth faces omitted")
		root.queue_free()
		await wait_process_frames(2)


func test_arch_is_open_parapets_solid_and_collision_matches_drawn_faces() -> void:
	var f := _fixture(0.37)
	var root := _build(f)
	var sampler: RoadSampler = f.sampler
	var profile: RoadProfile = f.profile
	await wait_physics_frames(2)
	var space := root.get_world_3d().direct_space_state
	var centre := sampler.position(79.0)
	var across := sampler.right(79.0)
	var passage := centre - Vector3.UP * 3.0
	assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(passage - across * 18, passage + across * 18)).is_empty(),
		"no ground slab or masonry plug across the visible aperture")
	var ceiling := space.intersect_ray(PhysicsRayQueryParameters3D.create(passage, centre + Vector3.UP * 0.05))
	assert_false(ceiling.is_empty())
	if not ceiling.is_empty():
		assert_almost_eq(ceiling.position.y, centre.y - 0.9, 0.003)
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(passage, passage - Vector3.UP * 5))
	assert_false(floor_hit.is_empty())
	if not floor_hit.is_empty():
		assert_almost_eq(floor_hit.position.y, centre.y - 5.5, 0.003)
	for side: float in [-1.0, 1.0]:
		var p := sampler.surface_point(79.0, 0.0, profile) + Vector3.UP * 0.35
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + across * side * 6))
		assert_false(wall.is_empty())
		if not wall.is_empty():
			assert_almost_eq(absf(sampler.lateral_offset(wall.position)), 3.5, 0.003)
	var pier := sampler.position(71.0) - Vector3.UP * 3.0
	assert_false(space.intersect_ray(PhysicsRayQueryParameters3D.create(pier + across * 7, pier)).is_empty(), "solid visible abutment")
	var builder: StoneBridgeBuilder = root.get_node("StoneBridge")
	assert_eq(builder.get_child_count(), 4, "two batched meshes and two static bodies")
	for child in builder.get_children():
		if child is MeshInstance3D:
			var body: StaticBody3D = builder.get_node(String(child.name) + "Collision")
			var drawn: PackedVector3Array = child.mesh.get_faces()
			var solid: PackedVector3Array = body.get_child(0).shape.get_faces()
			assert_eq(drawn.size(), solid.size())
			var maximum := 0.0
			for i in mini(drawn.size(), solid.size()):
				maximum = maxf(maximum, drawn[i].distance_to(solid[i]))
			gut.p("%s drawn/collision maximum error: %.9f m" % [child.name, maximum])
			assert_lt(maximum, 0.001, "mesh storage precision stays below 1 mm")
	var old_mesh: WeakRef = weakref(builder.get_child(0))
	builder.build(sampler, profile, f.field, f.trail)
	await wait_process_frames(2)
	assert_null(old_mesh.get_ref(), "rebuild disposes old generated data")
	assert_eq(builder.get_child_count(), 4)


func test_serial_and_threaded_road_and_earth_omissions_match() -> void:
	var f := _fixture(0.61)
	# Include the Coastal-only tunnel-join option as well as the stone span.
	var tunnel := TunnelDef.new()
	tunnel.start = 115.0
	tunnel.length = 40.0
	tunnel.omit_earth_joins = true
	var trail: TrailDef = f.trail
	trail.tunnels = [tunnel]
	for kind in 2:
		var pair: Array[Node3D] = []
		for threaded: bool in [false, true]:
			var builder: Node3D = RoadBuilder.new() if kind == 0 else RoadBlendBuilder.new()
			builder.set("threaded", threaded)
			add_child_autofree(builder)
			if kind == 0:
				(builder as RoadBuilder).build(f.sampler, f.profile, f.trail)
			else:
				(builder as RoadBlendBuilder).build(f.sampler, f.profile, f.field, f.trail)
			pair.append(builder)
		assert_eq(pair[0].get_child_count(), pair[1].get_child_count())
		for i in pair[0].get_child_count():
			var a := pair[0].get_child(i)
			var b := pair[1].get_child(i)
			if a is MeshInstance3D:
				assert_eq(a.mesh.get_faces(), b.mesh.get_faces())
			elif a is StaticBody3D:
				assert_eq(a.get_child(0).shape.get_faces(), b.get_child(0).shape.get_faces())
