extends GutTest
## Rock steps (M5 spec §6): the profile's level change, the ramp beside a partial
## face, the face mesh, its rock collision and the terrain following the ramp.

var trail: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var full: RockStepDef
var partial: RockStepDef


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	full = RockStepDef.new()
	full.distance = 100.0
	full.height = 0.35
	full.lateral_from = -6.0
	full.lateral_to = 6.0
	partial = RockStepDef.new()
	partial.distance = 200.0
	partial.height = 0.5
	partial.lateral_from = 0.5
	partial.lateral_to = 3.5
	trail.rock_steps = [full, partial]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)


func test_the_road_rises_at_a_full_width_face_and_stays_up() -> void:
	assert_almost_eq(profile.height(99.0, 0.0), 0.0, 0.0001)
	assert_almost_eq(profile.height(100.0, 0.0), 0.0, 0.0001, "the face row is at the old level")
	assert_almost_eq(profile.height(100.02, 0.0), 0.35 * 0.6 + 0.35 * 0.4 * 0.02 / 0.6, 0.0001, "the vertical face's top, at the start of the lip")
	assert_almost_eq(profile.height(100.6, 0.0), 0.35, 0.0001, "the lip reaches the full height over face_length")
	assert_almost_eq(profile.height(150.0, -5.0), 0.35, 0.0001)
	assert_almost_eq(profile.height(199.0, 5.0), 0.35, 0.0001, "the rise is permanent")


func test_a_partial_face_ramps_beside_it_and_both_lines_meet() -> void:
	assert_almost_eq(profile.height(200.6, 2.0), 0.85, 0.0001, "on the ledge past its lip: both steps")
	assert_almost_eq(profile.height(200.6, -2.0), 0.35 + 0.5 * 0.1, 0.0001, "beside it: only a tenth of the ramp so far")
	assert_almost_eq(profile.height(203.0, -2.0), 0.35 + 0.25, 0.0001, "halfway up the 6 m ramp")
	assert_almost_eq(profile.height(206.0, -2.0), 0.85, 0.0001, "level with the ledge at the ramp's end")
	assert_almost_eq(profile.height(206.0, 2.0), 0.85, 0.0001)
	assert_true(profile.in_detail_range(203.0))
	assert_false(profile.in_detail_range(150.0))
	assert_eq(profile.exact_rows(), PackedFloat32Array([100.0, 100.02, 200.0, 200.02]))


func test_the_road_mesh_has_a_sharp_face_in_both_build_modes() -> void:
	for threaded: bool in [true, false]:
		var road := RoadBuilder.new()
		road.threaded = threaded
		add_child(road)
		road.build(sampler, profile, trail)
		var rows := RoadBuilder.row_distances(sampler.length, profile, trail)
		assert_true(rows.has(100.0), "a row at the face")
		assert_true(rows.has(100.02), "and one just past it")
		var before := -INF
		var after := INF
		for child in road.get_children():
			if child is MeshInstance3D:
				var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					if absf(vertex.x) > 3.0:
						continue
					if vertex.z <= -99.9 and vertex.z > -100.01:
						before = maxf(before, vertex.y)
					elif vertex.z <= -100.01 and vertex.z > -100.03:
						after = minf(after, vertex.y)
		assert_almost_eq(before, 0.0, 0.001, "old level on the face row (threaded %s)" % threaded)
		assert_almost_eq(after, 0.35 * 0.6 + 0.35 * 0.4 * 0.02 / 0.6, 0.001, "ledge level 2 cm on (threaded %s)" % threaded)
		remove_child(road)
		road.queue_free()
		await wait_process_frames(1)


func test_the_builder_puts_a_rock_face_with_collision_on_the_level_change() -> void:
	var builder := RockStepBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, trail)
	assert_eq(builder.step_count, 2)
	assert_not_null(builder.get_node_or_null("RockSteps"), "one merged mesh")
	assert_not_null(builder.get_node_or_null("RockStepsCollision"))
	assert_eq(builder.get_children().filter(func(c: Node) -> bool: return c is MeshInstance3D).size(), 1, "one draw call for every step")
	assert_almost_eq(builder.face_tops[0].y, 0.35 * RockStepDef.LEDGE_SHARE, 0.02, "the face's top meets the road at the lip's start")
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.1, -97.0), Vector3(0.0, 0.1, -103.0)))
	assert_false(hit.is_empty(), "a ray along the road hits the face")
	if not hit.is_empty():
		assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, &"rock")
		assert_almost_eq(hit["position"].z, -100.0, 0.1)
	# Just inside the lip's far edge: the curve's baked samples put that edge a
	# tenth of a millimetre short of -100.6, where a ray hit would be a boundary case.
	var lip := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.0, 2.0, -100.55), Vector3(2.0, -1.0, -100.55)))
	assert_false(lip.is_empty(), "the lip has collision")
	if not lip.is_empty():
		assert_almost_eq(lip["position"].y, 0.35, 0.05, "the lip's end sits at the ledge's level")
	var beside := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-2.0, 0.1, -197.0), Vector3(-2.0, 0.1, -203.0)))
	assert_true(beside.is_empty(), "no face beside a partial ledge, just the road's ramp")


func test_the_rock_face_is_what_a_wheel_meets_with_the_road_built_too() -> void:
	# The road mesh has its own near-vertical quad over RoadProfile.FACE_ROW_GAP,
	# tagged with the road's surface. The rock face must sit in front of it, or the
	# car climbs the ledge on asphalt and the road colour stripes over the rock.
	var road := RoadBuilder.new()
	add_child_autofree(road)
	road.build(sampler, profile, trail)
	var builder := RockStepBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, trail)
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 0.1, -97.0), Vector3(0.0, 0.1, -103.0)))
	assert_false(face.is_empty(), "a ray along the road hits the ledge")
	if not face.is_empty():
		assert_eq(SurfaceLookup.surface_of(face["collider"]).id, &"rock", "the rock face, not the road's step quad")
		assert_almost_eq(face["position"].z, -100.0, 0.06, "and it stands at the step, not behind it")
	var lip := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.25, 2.0, -100.55), Vector3(2.25, -1.0, -100.55)))
	assert_false(lip.is_empty(), "the lip is there")
	if not lip.is_empty():
		assert_eq(SurfaceLookup.surface_of(lip["collider"]).id, &"rock", "the lip lies over the raised road, not under it")


func test_terrain_follows_the_ramp_under_the_road() -> void:
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	var field := TerrainField.generate(sampler, trail, terrain)
	assert_almost_eq(field.height_at(0.0, -150.0), 0.35 - terrain.under_road_drop, 0.03, "under the raised road")
	assert_almost_eq(field.height_at(0.0, -50.0), -terrain.under_road_drop, 0.03, "under the road before the step")
