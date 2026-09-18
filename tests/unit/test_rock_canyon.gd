extends GutTest
## Rock Canyon's data and build (M5 spec §3, §13): the route's length and
## climb, its surfaces and structures, the recommendation, and an integrated
## build with every part, its phase summary and its surfaces under the wheels.

const TRAIL := preload("res://levels/rock_canyon/rock_canyon_trail.tres")
const TERRAIN := preload("res://levels/rock_canyon/rock_canyon_terrain.tres")
const SCATTER := preload("res://levels/rock_canyon/rock_canyon_scatter.tres")
const CURVE := preload("res://levels/rock_canyon/rock_canyon_curve.tres")
const LEVEL := preload("res://levels/rock_canyon/rock_canyon_level.tres")

var sampler: RoadSampler
var profile: RoadProfile


func before_each() -> void:
	sampler = RoadSampler.new(CURVE, TRAIL.use_curve_banking, TRAIL)
	profile = RoadProfile.new(TRAIL, sampler.length)


func test_route_length_climb_and_separation() -> void:
	assert_between(sampler.length - TRAIL.end_margin, 2050.0, 2150.0, "about 2.1 km to the finish")
	assert_eq(TRAIL.end_margin, 70.0)
	assert_gt(sampler.position(sampler.length).y - sampler.position(0.0).y, 60.0, "climbs to the rim")
	assert_true(CurveGenerator.separation_problems(CURVE).is_empty(), "no parts pass too close")
	assert_true(TRAIL.use_curve_banking)


func test_surfaces_along_the_route() -> void:
	for check: Array in [[100.0, &"asphalt"], [250.0, &"dirt"], [303.0, &"mud"], [400.0, &"deep_mud"], [800.0, &"dirt"],
			[770.0, &"scree"], [1200.0, &"scree"], [1283.0, &"wet_rock"], [1290.0, &"wet_rock"], [1590.0, &"rock"],
			[1700.0, &"dirt"], [1950.0, &"scree"]]:
		assert_eq(profile.surface_at(check[0]).id, check[1], "surface at %.0f m" % check[0])
	assert_eq(TRAIL.base_surface.id, &"dirt")
	assert_false(TRAIL.painted_lines)
	var deep: SurfaceStretch = TRAIL.surface_stretches.filter(func(s: SurfaceStretch) -> bool: return s.surface.id == &"deep_mud")[0]
	assert_almost_eq(deep.rut_depth, 0.18, 0.0001, "multiple driven lines sink about 18 cm")
	assert_almost_eq(deep.water_rut_depth, 0.09, 0.0001, "shallow standing water inside the wheel ruts")
	assert_almost_eq(deep.start, 300.0, 0.0001)
	assert_almost_eq(deep.length, 260.0, 0.0001)
	var ford: FordDef = TRAIL.fords[0]
	for distance: float in range(int(ford.distance - ford.half_width()), int(ford.distance + ford.half_width())):
		assert_eq(profile.surface_at(distance + 0.01).id, &"wet_rock", "whole river channel at %.0f m" % distance)


func test_structures_match_the_spec() -> void:
	assert_eq(TRAIL.width_stretches, [Vector4(1500.0, 400.0, 4.5, 0.0), Vector4(560.0, 100.0, 12.0, 4.0)] as Array[Vector4])
	assert_almost_eq(TRAIL.road_width_at(1700.0), 4.5, 0.0001)
	assert_almost_eq(TRAIL.shoulder_width_at(1700.0), 0.0, 0.0001)
	assert_eq(TRAIL.rock_steps.size(), 3)
	assert_eq(TRAIL.rock_steps.map(func(s: RockStepDef) -> float: return s.distance), [812.0, 947.0, 1078.0])
	assert_eq(TRAIL.rock_steps.map(func(s: RockStepDef) -> float: return s.height), [0.35, 0.5, 0.3])
	assert_true(TRAIL.rock_steps[0].covers(-6.0) and TRAIL.rock_steps[0].covers(6.0), "the first step spans the whole road")
	assert_false(TRAIL.rock_steps[1].covers(-1.0), "the second leaves a ramp on the left")
	assert_true(TRAIL.rock_steps[1].covers(2.0))
	assert_eq(TRAIL.boulder_fields.size(), 6, "five authored obstacle fields plus the approved fixed-talus fallback")
	assert_eq(TRAIL.boulder_fields[0].start, 720.0)
	assert_eq(TRAIL.boulder_fields[4].count, 2, "the squeeze is two blocks")
	assert_true(TRAIL.talus.is_empty(), "loose stones disabled after the desktop chassis-wedge acceptance failure")
	var fallback: BoulderFieldDef = TRAIL.boulder_fields.back()
	assert_eq(fallback.start, 1150.0)
	assert_eq(fallback.length, 100.0)
	assert_eq(fallback.count, 40)
	assert_eq(TRAIL.fords.size(), 1)
	assert_between(TRAIL.fords[0].distance, 1250.0, 1330.0)
	assert_eq(TRAIL.fords[0].waterfall_height, 14.0)
	assert_eq(TRAIL.fords[0].waterfall_offset, -22.0)
	assert_eq(Array(TRAIL.checkpoint_distances), [300.0, 700.0, 1250.0, 1500.0, 1900.0])
	assert_eq(TERRAIN.wall_sections.size(), 7)
	assert_eq(TERRAIN.wall_sections[3], Vector4(1500.0, 400.0, 25.0, -40.0), "the shelf: cliff left, air right")
	assert_eq(TERRAIN.view_distance, 350.0)
	assert_eq(TERRAIN.detail_distance, 140.0)
	assert_eq(SCATTER.pine_spacing, 0.0, "no pines in the desert")
	assert_gt(SCATTER.post_drop, 100.0, "no roadside posts")


func test_catalog_entry() -> void:
	assert_eq(LEVEL.id, &"rock_canyon")
	assert_eq(LEVEL.display_name, "Rock Canyon")
	assert_eq(LEVEL.surfaces, "Deep mud, rock, scree, water")
	assert_eq(LEVEL.recommended_car, &"offroad_4x4")
	assert_eq(LEVEL.two_star_time, 285.0, "placeholder pending the owner's runs")
	assert_eq(LEVEL.three_star_time, 255.0)
	assert_true(ResourceLoader.exists(LEVEL.scene_path))


func test_mud_climbs_through_opposing_turns_then_opens_into_a_clearing() -> void:
	assert_between(sampler.forward(315.0).y, 0.015, 0.04, "climb starts with the mud")
	assert_between(sampler.forward(410.0).y, 0.045, 0.065)
	assert_between(sampler.forward(505.0).y, 0.09, 0.11, "last climbing bend reaches about 10%")
	assert_gt(sampler.position(560.0).y - sampler.position(300.0).y, 14.0)
	var turning := 0.0
	for distance: float in range(305, 550, 5):
		var a := sampler.forward(distance)
		var b := sampler.forward(distance + 5.0)
		turning += absf(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))
	assert_gt(turning, 4.5, "multiple substantial turns, not the old gentle gully")
	assert_lt(absf(sampler.forward(610.0).y), 0.015, "almost level clearing")
	assert_eq(TRAIL.road_width_at(610.0), 12.0)
	assert_eq(TRAIL.shoulder_width_at(610.0), 4.0)
	assert_eq(profile.surface_at(610.0).id, &"dirt")
	assert_eq(TERRAIN.wall_delta(610.0, -1.0), 0.0)
	assert_eq(TERRAIN.wall_delta(610.0, 1.0), 0.0)


func test_multiple_wheel_paths_weave_and_cross_without_stacking_depth() -> void:
	var mud := TRAIL.surface_stretches[1]
	assert_eq(mud.extra_rut_paths.size(), 2)
	assert_eq(mud.rut_centres(350.0).size(), 6, "three choices of paired wheel paths")
	assert_ne(mud.rut_centres(350.0), mud.rut_centres(380.0), "additional lines wander across the road")
	var overlaps := 0
	for distance: float in range(320, 540, 2):
		var centres := mud.rut_centres(distance)
		for i in centres.size():
			var depth := profile.rut_height(distance, centres[i])
			assert_almost_eq(depth, -mud.rut_depth, 0.0001, "crossings never double the trench depth")
			assert_lt(absf(centres[i]) + mud.rut_width * 0.5, TRAIL.road_width_at(distance) * 0.5)
			for j in range(i + 1, centres.size()):
				if absf(centres[i] - centres[j]) < 0.15:
					overlaps += 1
	assert_gt(overlaps, 10, "lines visibly cross and overlap in several places")
	assert_gt(profile.roller_height(452.0), 0.15)


func test_the_level_builds_every_part_with_its_surfaces_and_structures() -> void:
	var level := TrailLevel.new()
	level.trail = TRAIL
	level.terrain = TERRAIN
	level.scatter = SCATTER
	var path := Path3D.new()
	path.name = "Road"
	path.curve = CURVE
	level.add_child(path)
	add_child_autofree(level)
	await wait_physics_frames(2)
	gut.p("Rock Canyon: %.0f m, built in %.2f s (%s)" % [sampler.length, level.build_seconds, level.phase_summary()])
	assert_lt(level.build_seconds, 3.0, "desktop build time")
	for part in ["Generated/RockSteps", "Generated/Boulders", "Generated/Talus", "Generated/Fords"]:
		assert_not_null(level.get_node_or_null(part), part)
	assert_eq(level.rock_step_builder.step_count, 3)
	assert_eq(level.boulder_builder.placed.size(), 6)
	assert_true(level.talus_builder.stones.is_empty(), "no dynamic stones in the shipped fallback")
	assert_gte(level.boulder_builder.placed.back().size(), 36, "40 fixed stones less any on the 1250 m gate")
	assert_eq(level.ford_builder.water_levels.size(), 1)
	assert_gt(level.rut_water_builder.puddle_ranges.size(), 4, "standing water survives the actual gully's banking and undulation")
	assert_eq(level.checkpoints.reset_transforms.size(), 7, "start, five checkpoints, finish")
	assert_eq(level.scatter_builder.pine_count, 0)
	assert_eq(level.scatter_builder.post_count, 0, "no roadside posts in the canyon")
	assert_gt(level.scatter_builder.rock_count, 100)
	var space := level.get_world_3d().direct_space_state
	var deepest := 0.0
	for hole: Vector4 in profile.damage_potholes:
		var point := sampler.surface_point(hole.x, hole.y, profile)
		deepest = maxf(deepest, hole.w)
		assert_lt(level.field.height_at(point.x, point.z), point.y - 0.02,
				"underlying ground clears the hole at %.1f m" % hole.x)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
				point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0))
		assert_false(hit.is_empty(), "physical hole floor at %.1f m" % hole.x)
		if not hit.is_empty():
			var body: Node = hit["collider"]
			assert_eq(body.get_parent(), level.road_builder, "wheels hit road, not filled-in terrain")
			assert_almost_eq(hit["position"].y, point.y, 0.1, "collision follows the depressed mesh")
	assert_gt(deepest, 0.35)
	var mud := TRAIL.surface_stretches[1]
	for distance: float in range(320, 545, 10):
		for lateral: float in mud.rut_centres(distance):
			var point := sampler.surface_point(distance, lateral, profile)
			assert_lt(level.field.height_at(point.x, point.z), point.y - 0.02,
					"all six wheel lines clear the terrain at %.0f m" % distance)
	# Adjacent chunk rows must coincide, including moving ruts on sharp bends.
	var meshes := level.road_builder.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D)
	var row_width := RoadBuilder.cross_section(TRAIL).size()
	for mesh: MeshInstance3D in meshes:
		assert_eq(mesh.visibility_range_end, 400.0, "do not draw road beyond the terrain horizon")
	for i in range(1, meshes.size()):
		var previous: PackedVector3Array = meshes[i - 1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var next: PackedVector3Array = meshes[i].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for column in row_width:
			assert_eq(previous[previous.size() - row_width + column], next[column], "no crack between road chunks")
	for distance: float in [15.0, 80.0, 150.0, 250.0]:
		for side: float in [-1.0, 1.0]:
			var point := sampler.position(distance) + sampler.right(distance) * side * 50.0
			assert_gt(level.field.height_at(point.x, point.z) - sampler.position(distance).y,
					45.0, "tall canyon on both sides at %.0f m" % distance)
	for check: Array in [[100.0, &"asphalt"], [400.0, &"deep_mud"], [1290.0, &"wet_rock"], [1590.0, &"rock"], [1950.0, &"scree"]]:
		# Probe inside triangles: exactly on the 400 m chunk vertex the float-
		# precision ray test can reject both edges (neighbouring probes hit road).
		var point := sampler.surface_point(check[0] + 0.03, 0.07, level.profile)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 2.0))
		assert_false(hit.is_empty(), "road under %.0f m" % check[0])
		if not hit.is_empty():
			gut.p("%.0f m ray: %s at %.3f, road %.3f" % [check[0], hit["collider"].name, hit["position"].y, point.y])
			assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, check[1], "surface at %.0f m" % check[0])
	var face_from := sampler.surface_point(809.0, 0.0, level.profile) + Vector3.UP * 0.1
	var face_to := sampler.surface_point(815.0, 0.0, level.profile) + Vector3.UP * 0.1
	var face := space.intersect_ray(PhysicsRayQueryParameters3D.create(face_from, face_to))
	assert_false(face.is_empty(), "the first rock step's face")
	if not face.is_empty():
		assert_eq(SurfaceLookup.surface_of(face["collider"]).id, &"rock")
	assert_almost_eq(level.profile.ford_height(1290.0), -0.35, 0.0001)
	var ford := TRAIL.fords[0]
	var foot := level.ford_builder.waterfall_feet[0]
	assert_almost_eq(sampler.lateral_offset(foot), ford.waterfall_offset, 0.5, "the waterfall stands on the left wall")
	var gully := sampler.position(430.0) + sampler.right(430.0) * -30.0
	assert_gt(level.field.height_at(gully.x, gully.z) - sampler.position(430.0).y, 12.0, "the gully's left wall")
	var cliff := sampler.position(1700.0) + sampler.right(1700.0) * -30.0
	var drop := sampler.position(1700.0) + sampler.right(1700.0) * 40.0
	assert_gt(level.field.height_at(cliff.x, cliff.z) - sampler.position(1700.0).y, 15.0, "rock cut left of the shelf")
	assert_lt(level.field.height_at(drop.x, drop.z) - sampler.position(1700.0).y, -20.0, "air right of the shelf")


func test_shelf_has_tilted_slabs_and_a_three_metre_boulder_squeeze() -> void:
	var field := TerrainField.generate(sampler, TRAIL, TERRAIN)
	var builder := BoulderBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, TRAIL)
	assert_true(builder.slabs[2].has(true), "actual tilted slabs on the shelf, not just a rock texture")
	assert_true(builder.slabs[2].has(false), "the first washout also retains loose-looking rubble")
	var squeeze := TRAIL.boulder_fields[4]
	var rock := LowPolyMeshes.rock(squeeze.color, squeeze.seed)
	var bounds: Array[Vector4] = []
	var centre := sampler.position(squeeze.start)
	var right := sampler.right(squeeze.start)
	var forward := sampler.forward(squeeze.start)
	for transform: Transform3D in builder.placed[4]:
		var extent := Vector4(INF, -INF, INF, -INF)
		for point: Vector3 in rock.get_faces():
			var offset := transform * point - centre
			var across := offset.dot(right)
			var along := offset.dot(forward)
			extent.x = minf(extent.x, across)
			extent.y = maxf(extent.y, across)
			extent.z = minf(extent.z, along)
			extent.w = maxf(extent.w, along)
		bounds.append(extent)
	assert_eq(bounds.size(), 2)
	var gap := bounds[1].x - bounds[0].y
	gut.p("shelf squeeze: %.2f m gap, longitudinal overlap %.2f m" % [gap, minf(bounds[0].w, bounds[1].w) - maxf(bounds[0].z, bounds[1].z)])
	assert_between(gap, 2.8, 3.2, "clear gap between the actual rock hulls")
	assert_gt(minf(bounds[0].w, bounds[1].w), maxf(bounds[0].z, bounds[1].z), "blocks form one squeeze, not a slalom")


func test_walls_never_bury_any_of_the_driving_line() -> void:
	var field := TerrainField.generate(sampler, TRAIL, TERRAIN)
	var highest_intrusion := -INF
	var worst_distance := 0.0
	for distance: float in range(10, 2100, 2):
		for lateral: float in [-1.2, 0.0, 1.2]:
			var point := sampler.surface_point(distance, lateral, profile)
			var intrusion := field.height_at(point.x, point.z) - point.y
			if intrusion > highest_intrusion:
				highest_intrusion = intrusion
				worst_distance = distance
	gut.p("highest terrain relative to driving line: %.3f m at %.0f m" % [highest_intrusion, worst_distance])
	assert_lt(highest_intrusion, -0.02, "terrain remains below the drivable road")
