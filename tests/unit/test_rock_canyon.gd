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
	assert_almost_eq(deep.rut_depth, 0.15, 0.0001, "water-filled ruts sink about 15 cm")
	assert_almost_eq(deep.water_rut_depth, 0.09, 0.0001, "shallow standing water inside the wheel ruts")
	assert_almost_eq(deep.start, 300.0, 0.0001)
	assert_almost_eq(deep.length, 260.0, 0.0001)
	var ford: FordDef = TRAIL.fords[0]
	for distance: float in range(int(ford.distance - ford.half_width()), int(ford.distance + ford.half_width())):
		assert_eq(profile.surface_at(distance + 0.01).id, &"wet_rock", "whole river channel at %.0f m" % distance)


func test_structures_match_the_spec() -> void:
	assert_eq(TRAIL.width_stretches, [Vector4(1500.0, 400.0, 4.5, 0.0)] as Array[Vector4])
	assert_almost_eq(TRAIL.road_width_at(1700.0), 4.5, 0.0001)
	assert_almost_eq(TRAIL.shoulder_width_at(1700.0), 0.0, 0.0001)
	assert_eq(TRAIL.rock_steps.size(), 3)
	assert_eq(TRAIL.rock_steps.map(func(s: RockStepDef) -> float: return s.distance), [812.0, 947.0, 1078.0])
	assert_eq(TRAIL.rock_steps.map(func(s: RockStepDef) -> float: return s.height), [0.35, 0.5, 0.3])
	assert_true(TRAIL.rock_steps[0].covers(-6.0) and TRAIL.rock_steps[0].covers(6.0), "the first step spans the whole road")
	assert_false(TRAIL.rock_steps[1].covers(-1.0), "the second leaves a ramp on the left")
	assert_true(TRAIL.rock_steps[1].covers(2.0))
	assert_eq(TRAIL.boulder_fields.size(), 5)
	assert_eq(TRAIL.boulder_fields[0].start, 720.0)
	assert_eq(TRAIL.boulder_fields[4].count, 2, "the squeeze is two blocks")
	assert_eq(TRAIL.talus.size(), 1)
	assert_eq(TRAIL.talus[0].count, 40)
	assert_eq(TRAIL.fords.size(), 1)
	assert_between(TRAIL.fords[0].distance, 1250.0, 1330.0)
	assert_eq(TRAIL.fords[0].waterfall_height, 14.0)
	assert_eq(TRAIL.fords[0].waterfall_offset, -22.0)
	assert_eq(Array(TRAIL.checkpoint_distances), [300.0, 700.0, 1250.0, 1500.0, 1900.0])
	assert_eq(TERRAIN.wall_sections.size(), 4)
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
	assert_eq(level.boulder_builder.placed.size(), 5)
	assert_gte(level.talus_builder.stones.size(), 36, "40 stones less any on the 1250 m gate")
	assert_eq(level.ford_builder.water_levels.size(), 1)
	assert_gt(level.rut_water_builder.puddle_ranges.size(), 4, "standing water survives the actual gully's banking and undulation")
	assert_eq(level.checkpoints.reset_transforms.size(), 7, "start, five checkpoints, finish")
	assert_eq(level.scatter_builder.pine_count, 0)
	assert_eq(level.scatter_builder.post_count, 0, "no roadside posts in the canyon")
	assert_gt(level.scatter_builder.rock_count, 100)
	var space := level.get_world_3d().direct_space_state
	for check: Array in [[100.0, &"asphalt"], [400.0, &"deep_mud"], [1290.0, &"wet_rock"], [1590.0, &"rock"], [1950.0, &"scree"]]:
		var point := sampler.surface_point(check[0], 0.0, level.profile)
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
