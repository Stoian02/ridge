extends GutTest
## Ford geometry, road collision and water/audio lifecycle (M5 spec §9).

var trail: TrailDef
var terrain: TerrainDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var ford: FordDef


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -400.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	ford = FordDef.new()
	ford.distance = 200.0
	trail.fords = [ford]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)
	terrain = TerrainDef.new()
	terrain.margin = 80.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	terrain.corridor_blend = 8.0
	field = TerrainField.generate(sampler, trail, terrain)


func _height_at(distance: float, lateral: float) -> float:
	var spot := sampler.position(distance) + sampler.right(distance) * lateral
	return field.height_at(spot.x, spot.z)


func _build() -> FordBuilder:
	var builder := FordBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)
	return builder


func test_the_road_dips_smoothly_and_adds_detail_rows() -> void:
	assert_almost_eq(profile.height(200.0, 0.0), -0.35, 0.0001)
	assert_almost_eq(profile.height(192.0, 3.0), -0.35, 0.0001)
	assert_almost_eq(profile.height(185.0, 0.0), -0.35 * (1.0 - smoothstep(0.0, 10.0, 7.0)), 0.0001)
	assert_almost_eq(profile.height(181.9, 0.0), 0.0, 0.0001)
	assert_almost_eq(profile.height(250.0, 0.0), 0.0, 0.0001)
	var previous := profile.height(175.0, 0.0)
	var at := 175.25
	while at <= 225.0:
		var height := profile.height(at, 0.0)
		assert_lt(absf(height - previous), 0.03, "continuous bank at %.2f m" % at)
		previous = height
		at += 0.25
	assert_true(profile.in_detail_range(190.0))
	assert_false(profile.in_detail_range(170.0))
	assert_true(ford.contains(207.0))
	assert_false(ford.contains(209.0))


func test_the_channel_crosses_both_sides_and_preserves_road_clearance() -> void:
	for lateral: float in [-15.0, 15.0, 35.0]:
		assert_almost_eq(_height_at(200.0, lateral), -ford.depth, 0.06, "floor %.0f m out" % lateral)
	assert_almost_eq(_height_at(200.0, -45.0), 0.0, 0.05, "beyond the waterfall ledge")
	assert_almost_eq(_height_at(200.0, 62.0), 0.0, 0.05, "beyond the river")
	assert_almost_eq(_height_at(230.0, 15.0), 0.0, 0.05, "alongside the channel")
	assert_lt(_height_at(200.0, 0.0), -ford.depth - 0.2, "terrain stays below road collision")


func test_water_and_channel_use_the_raised_road_after_rock_steps() -> void:
	for step_height: float in [0.35, 0.5, 0.3]:
		var step := RockStepDef.new()
		step.distance = 100.0 + trail.rock_steps.size() * 20.0
		step.height = step_height
		step.lateral_from = -6.5
		step.lateral_to = 6.5
		trail.rock_steps.append(step)
	trail.undulation_amplitude = 0.08
	profile = RoadProfile.new(trail, sampler.length)
	field = TerrainField.generate(sampler, trail, terrain)
	var builder := _build()
	var floor := sampler.surface_point(ford.distance, 0.0, profile).y
	assert_gt(floor, 0.7, "the permanent step heights are included")
	assert_almost_eq(builder.water_levels[0] - floor, ford.water_depth, 0.0001)
	assert_almost_eq(_height_at(ford.distance, 18.0), floor, 0.06)
	assert_almost_eq(builder.waterfall_feet[0].y, floor, 0.0001)


func test_low_ground_gets_a_supported_river_floor_and_containing_banks() -> void:
	# Reapply the earthworks to a valley below the crossing. Lower-only carving
	# would leave a floating ribbon here instead of a shallow supported river.
	field.heights.fill(-5.0)
	TrailEarthworks.apply_fords(field, sampler, trail)
	assert_almost_eq(_height_at(200.0, 30.0), -ford.depth, 0.06)
	assert_gt(_height_at(212.0, 30.0), -ford.depth + ford.water_depth, "bank contains the water")
	assert_lt(_height_at(200.0, 0.0), -ford.depth, "never fill through the road")
	assert_almost_eq(_height_at(200.0, 65.0), -5.0, 0.001, "untouched beyond the river")


func test_waterfall_water_mist_and_positional_sound_match_the_data() -> void:
	var builder := _build()
	assert_eq(builder.water_levels.size(), 1)
	assert_almost_eq(builder.water_levels[0], -ford.depth + ford.water_depth, 0.0001)
	for child_name: String in ["Water0", "Waterfall0", "Waterfall0Rock", "Mist0", "Waterfall0Sound"]:
		assert_not_null(builder.get_node_or_null(child_name), child_name)
	var foot := builder.waterfall_feet[0]
	assert_almost_eq(foot.x, -22.0, 0.01)
	assert_almost_eq(foot.z, -200.0, 0.01)
	assert_almost_eq(foot.y, -ford.depth, 0.001)
	assert_almost_eq(builder.waterfall_tops[0].y - foot.y, ford.waterfall_height, 0.0001)
	var strip: MeshInstance3D = builder.get_node("Waterfall0")
	assert_almost_eq(strip.get_aabb().size.y, ford.waterfall_height, 0.01)
	assert_almost_eq(strip.get_aabb().size.z, ford.waterfall_width, 0.01)
	var water: MeshInstance3D = builder.get_node("Water0")
	assert_almost_eq(water.get_aabb().position.x, -22.0, 0.01)
	assert_almost_eq(water.get_aabb().end.x, ford.river_reach, 0.01)
	assert_eq((water.material_override as StandardMaterial3D).transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	var sound: AudioStreamPlayer3D = builder.get_node("Waterfall0Sound")
	assert_almost_eq(sound.max_distance, 80.0, 0.0001)
	assert_true(sound.playing)
	assert_true(builder.find_children("*", "CollisionObject3D", true, false).is_empty(), "visual water has no collision")
	var material: StandardMaterial3D = strip.material_override
	var offset_before := material.uv1_offset.y
	builder._process(0.5)
	assert_ne(material.uv1_offset.y, offset_before)
	assert_eq(material.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED)


func test_waterfall_rock_top_joins_a_supported_upstream_ledge() -> void:
	var builder := _build()
	var backing: MeshInstance3D = builder.get_node("Waterfall0Rock")
	assert_gte(backing.mesh.get_faces().size(), 24, "front, top and closed side returns")
	var upstream := ford.waterfall_offset - FordBuilder.LEDGE_RUN
	assert_gte(_height_at(ford.distance, upstream), builder.waterfall_tops[0].y - 0.1)
	assert_almost_eq(_height_at(ford.distance, ford.waterfall_offset + 3.0), -ford.depth, 0.08, "river meets the base")
	assert_gte(backing.get_aabb().end.y, builder.waterfall_tops[0].y)


func test_rotated_walled_channel_is_deterministic_in_both_build_modes() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3(20.0, 3.0, 40.0))
	curve.add_point(Vector3(260.0, 3.0, -280.0))
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)
	terrain.noise_amplitude = 15.0
	terrain.wall_sections = [Vector4(100.0, 200.0, 26.0, 14.0)]
	var serial := TerrainField.generate(sampler, trail, terrain, false)
	field = TerrainField.generate(sampler, trail, terrain, true)
	assert_eq(field.heights, serial.heights)
	assert_eq(field.edge_distances, serial.edge_distances)
	assert_eq(field.lowest_height, serial.lowest_height)
	var builder := _build()
	assert_almost_eq(builder.waterfall_feet[0].distance_to(
			sampler.position(ford.distance) + sampler.right(ford.distance) * ford.waterfall_offset
			- Vector3.UP * ford.depth), 0.0, 0.01)
	assert_almost_eq(_height_at(ford.distance, 18.0), builder.water_levels[0] - ford.water_depth, 0.1)
	assert_lt(field.kill_height(), field.lowest_height)


func test_the_continuous_road_collision_is_the_wet_riverbed() -> void:
	var stretch := SurfaceStretch.new()
	stretch.start = ford.distance - ford.half_width()
	stretch.length = ford.channel_width
	stretch.surface = preload("res://surfaces/wet_rock.tres")
	trail.surface_stretches = [stretch]
	profile = RoadProfile.new(trail, sampler.length)
	var road := RoadBuilder.new()
	add_child_autofree(road)
	road.build(sampler, profile, trail)
	var ground := TerrainBuilder.new()
	add_child_autofree(ground)
	ground.build(field)
	_build()
	await wait_physics_frames(2)
	var space := road.get_world_3d().direct_space_state
	for distance: float in [180.0, 185.0, 191.5, 195.0, 200.0, 205.0, 208.5, 215.0, 220.0]:
		var spot := sampler.surface_point(distance, 0.0, profile)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 2.0, spot - Vector3.UP * 2.0))
		assert_false(hit.is_empty(), "no road gap at %.1f m" % distance)
		if not hit.is_empty():
			var position: Vector3 = hit["position"]
			assert_almost_eq(position.y, spot.y, 0.01)
			if ford.contains(distance):
				assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, &"wet_rock")


func test_rebuilding_and_exiting_stop_the_waterfall_loop() -> void:
	var builder := _build()
	var first: AudioStreamPlayer3D = builder.get_node("Waterfall0Sound")
	trail.fords = []
	builder.build(sampler, profile, field, trail)
	assert_false(first.playing, "stop before deferred deletion on rebuild")
	assert_eq(builder.get_child_count(), 0)
	assert_true(builder.water_levels.is_empty())
	trail.fords = [ford]
	builder.build(sampler, profile, field, trail)
	var second: AudioStreamPlayer3D = builder.get_node("Waterfall0Sound")
	remove_child(builder)
	assert_false(second.playing, "stop synchronously on level exit")
	add_child(builder)  # keep GUT ownership while deferred old children are freed
	await wait_process_frames(1)


func test_no_ford_builds_nothing() -> void:
	trail.fords = []
	var builder := _build()
	assert_eq(builder.get_child_count(), 0)
