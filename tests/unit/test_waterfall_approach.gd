extends GutTest
## Owner-approved next section: narrow crawl, tree clearing, steeper dirt and
## a washed-out S-bend. The geometry is real, including below-road clearance.

const TRAIL := preload("res://levels/rock_canyon/rock_canyon_trail.tres")
const TERRAIN := preload("res://levels/rock_canyon/rock_canyon_terrain.tres")
const CURVE := preload("res://levels/rock_canyon/rock_canyon_curve.tres")


func test_cross_ruts_are_diagonal_rounded_and_tapered_with_no_off_section_effect() -> void:
	for rut: CrossRutDef in TRAIL.cross_ruts:
		assert_almost_eq(rut.height_at(rut.distance, 0.0), -rut.depth, 0.00001)
		for lateral: float in [-1.0, 0.0, 1.0]:
			var centre := rut.distance + lateral * rut.skew
			assert_almost_eq(rut.height_at(centre, lateral), -rut.depth, 0.00001)
			assert_almost_eq(rut.height_at(centre + rut.width * 0.25, lateral), -rut.depth * 0.5, 0.00001)
			assert_almost_eq(rut.height_at(centre + rut.width * 0.5, lateral), 0.0, 0.00001)
		for edge: float in [rut.lateral_from, rut.lateral_to]:
			assert_eq(rut.height_at(rut.distance + edge * rut.skew, edge), 0.0, "ends ease into a bypass line")
		var span := rut.bounds()
		assert_gt(span.x, 1150.0)
		assert_lt(span.y, 1240.0, "no channel at the checkpoint or ford approach")
	var profile := RoadProfile.new(TRAIL, CURVE.get_baked_length())
	for at: float in [700.0, 940.0, 1250.0, 1270.0, 1290.0, 1500.0]:
		assert_eq(profile.cross_rut_height(at, 0.0), 0.0)
	for rut: CrossRutDef in TRAIL.cross_ruts:
		assert_eq(profile.row_step(rut.distance), TRAIL.detail_step)


func test_sequence_narrows_opens_and_climbs_to_a_flatter_waterfall_approach() -> void:
	var sampler := RoadSampler.new(CURVE, TRAIL.use_curve_banking, TRAIL)
	assert_eq(TRAIL.road_width_at(700.0), 8.0, "checkpoint kept wide")
	assert_eq(TRAIL.road_width_at(760.0), 5.75)
	assert_eq(TRAIL.shoulder_width_at(760.0), 1.0)
	assert_eq(TRAIL.road_width_at(940.0), 10.0)
	assert_eq(TRAIL.road_width_at(1100.0), 5.75)
	assert_eq(TRAIL.road_width_at(1250.0), 8.0)
	for side: float in [-1.0, 1.0]:
		assert_eq(TERRAIN.wall_delta(940.0, side), 0.0, "walls open around the tree")
		assert_gt(TERRAIN.wall_delta(1050.0, side), 20.0)
	assert_between(sampler.forward(940.0).y, 0.05, 0.08, "clearing still climbs")
	assert_between(sampler.forward(1040.0).y, 0.085, 0.105, "dirt climb steepens")
	var previous_turn := 0.0
	var reversals := 0
	var total_turn := 0.0
	for at: float in range(1158, 1240, 5):
		var a := sampler.forward(at)
		var b := sampler.forward(at + 5.0)
		var turn := Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z))
		if turn * previous_turn < 0.0:
			reversals += 1
		previous_turn = turn
		total_turn += absf(turn)
	assert_eq(reversals, 2, "opposing arcs, not the old straight talus bed")
	assert_gt(total_turn, 1.5)
	assert_lt(absf(sampler.forward(1265.0).y), 0.005, "level before the ford banks")
	assert_eq(TRAIL.fords[0].distance, 1290.0)


func test_channel_terrain_clearance_and_visible_road_collision_match() -> void:
	var sampler := RoadSampler.new(CURVE, TRAIL.use_curve_banking, TRAIL)
	var profile := RoadProfile.new(TRAIL, sampler.length)
	var field := TerrainField.generate(sampler, TRAIL, TERRAIN)
	var road := RoadBuilder.new()
	add_child_autofree(road)
	road.build(sampler, profile, TRAIL)
	var terrain := TerrainBuilder.new()
	add_child_autofree(terrain)
	terrain.build(field)
	await wait_physics_frames(2)
	var space := road.get_world_3d().direct_space_state
	for rut: CrossRutDef in TRAIL.cross_ruts:
		for lateral: float in [-1.67, -0.73, 0.07, 0.83, 1.61]:
			for offset: float in [-0.7, 0.03, 0.7]:
				var at := rut.distance + lateral * rut.skew + offset
				var point := sampler.surface_point(at, lateral, profile)
				assert_lt(field.height_at(point.x, point.z), point.y - 0.02, "terrain must not bridge a washout")
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN))
				assert_false(hit.is_empty())
				if not hit.is_empty():
					assert_eq(hit["collider"].get_parent(), road)
					assert_almost_eq(hit["position"].y, point.y, 0.06)


func test_fallen_tree_has_exact_visible_collision_and_a_lower_thin_end() -> void:
	var sampler := RoadSampler.new(CURVE, TRAIL.use_curve_banking, TRAIL)
	var profile := RoadProfile.new(TRAIL, sampler.length)
	var builder := FallenTreeBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, TRAIL)
	assert_eq(builder.get_child_count(), 2)
	var mesh: MeshInstance3D = builder.get_child(0)
	var body: StaticBody3D = builder.get_child(1)
	var collider: ConcavePolygonShape3D = body.get_child(0).shape
	var visible := mesh.mesh.get_faces()
	var solid := collider.get_faces()
	assert_eq(visible.size(), solid.size())
	var maximum_error := 0.0
	for i in mini(visible.size(), solid.size()):
		maximum_error = maxf(maximum_error, visible[i].distance_to(solid[i]))
	assert_lt(maximum_error, 0.0002, "same triangles, within mesh float precision at world coordinates")
	var arrays := mesh.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(normals[0].y, 0.8, "upper bark faces outward/up, not into the trunk")
	assert_eq(SurfaceLookup.surface_of(body).id, &"logs")
	assert_eq(mesh.visibility_range_end, 200.0)
	assert_lt(mesh.mesh.get_faces().size() / 3, 200, "merged low-poly trunk and roots")
	await wait_physics_frames(2)
	var tree := TRAIL.fallen_trees[0]
	var tops: Array[float] = []
	for lateral: float in [-2.0, 0.0, 2.5]:
		var at := tree.distance + (lateral - tree.lateral) * tan(deg_to_rad(tree.angle_degrees))
		var point := sampler.surface_point(at, lateral, profile)
		var hit := builder.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN))
		assert_false(hit.is_empty(), "log across each intended crossing line")
		if not hit.is_empty():
			assert_eq(hit["collider"], body)
			tops.append(hit["position"].y - point.y)
	assert_eq(tops.size(), 3)
	if tops.size() == 3:
		gut.p("fallen tree height over road, left/centre/right: %s" % [tops])
		assert_gt(tops[0], tops[1])
		assert_gt(tops[1], tops[2])
		assert_between(tops[2], 0.07, 0.22, "part-buried thin end is a gentler crossing")
		assert_between(tops[1], 0.15, 0.36)


func test_empty_new_features_leave_existing_trails_unchanged() -> void:
	var trail := TrailDef.new()
	assert_true(trail.cross_ruts.is_empty())
	assert_true(trail.fallen_trees.is_empty())
	var sampler := RoadSampler.new(CURVE, false, trail)
	var profile := RoadProfile.new(trail, sampler.length)
	var builder := FallenTreeBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, trail)
	assert_eq(builder.get_child_count(), 0)
	assert_eq(profile.cross_rut_height(1185.0, 0.0), 0.0)
