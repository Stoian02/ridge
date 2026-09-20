extends GutTest

const TRAIL := preload("res://levels/rock_canyon/rock_canyon_trail.tres")
const TERRAIN := preload("res://levels/rock_canyon/rock_canyon_terrain.tres")
const CURVE := preload("res://levels/rock_canyon/rock_canyon_curve.tres")


func test_local_waves_are_shallow_smooth_and_confined_to_the_shelf() -> void:
	var profile := RoadProfile.new(TRAIL, CURVE.get_baked_length())
	var lowest := 0.0
	var highest := 0.0
	for i in 22000:
		var distance := i * 0.1
		var offset := profile.local_undulation(distance)
		assert_lte(absf(offset), 0.14)
		if distance <= 1512.0 or distance >= 1888.0:
			assert_eq(offset, 0.0, "opening, earlier obstacles, gates and easier finish unchanged")
		else:
			assert_lt(absf(offset - profile.local_undulation(distance + 0.1)), 0.007, "no new ledges")
		lowest = minf(lowest, offset)
		highest = maxf(highest, offset)
	assert_lt(lowest, -0.10)
	assert_gt(highest, 0.10)


func test_surface_colours_and_gravel_detail_fade_without_changing_physics() -> void:
	var profile := RoadProfile.new(TRAIL, CURVE.get_baked_length())
	var plain: TrailDef = TRAIL.duplicate()
	plain.surface_color_blend = 0.0
	var original := RoadProfile.new(plain, profile.road_length)
	for boundary: float in profile.surface_boundaries():
		for shoulder: bool in [false, true]:
			var base := TRAIL.shoulder_color if shoulder else TRAIL.asphalt_color
			var before := profile.surface_color(boundary - 0.001, base, shoulder)
			var after := profile.surface_color(boundary + 0.001, base, shoulder)
			assert_lt(Vector3(before.r - after.r, before.g - after.g, before.b - after.b).length(), 0.001)
		for distance: float in [boundary - 0.01, boundary, boundary + 0.01]:
			assert_eq(profile.surface_at(distance), original.surface_at(distance))
			assert_eq(profile.rut_height(distance, 0.8), original.rut_height(distance, 0.8))
	assert_eq(profile.gravel_weight(1500.0), 0.0)
	assert_eq(profile.gravel_weight(1900.0), 0.0)
	assert_eq(profile.gravel_weight(1540.0), 1.0, "no texture seams at internal stone-field boundaries")
	assert_between(profile.gravel_weight(1504.0), 0.4, 0.6)
	assert_between(profile.gravel_weight(1896.0), 0.4, 0.6)


func test_earth_join_matches_road_edge_and_buries_its_outer_seam() -> void:
	var sampler := RoadSampler.new(CURVE, true, TRAIL)
	var profile := RoadProfile.new(TRAIL, sampler.length)
	var field := TerrainField.generate(sampler, TRAIL, TERRAIN)
	var builder := RoadBlendBuilder.new()
	add_child_autofree(builder)
	for distance: float in [208, 220, 292, 300, 548, 560, 698, 708, 878, 900, 1120, 1150, 1240, 1265, 1900, 1980]:
		for side: float in [-1.0, 1.0]:
			var ring := builder._ring(sampler, profile, field, TRAIL, distance, side)
			var vertices: PackedVector3Array = ring["vertices"]
			var colors: PackedColorArray = ring["colors"]
			assert_eq(vertices[0], sampler.surface_point(distance, side * sampler.half_width_at(distance), profile))
			assert_lt(RoadBlendBuilder.ground_height(field, vertices[0].x, vertices[0].z), vertices[0].y - 0.10,
				"terrain cannot poke through the road/earth join")
			assert_eq(colors[0], profile.surface_color(distance, TRAIL.shoulder_color, true))
			assert_almost_eq(vertices[-1].y, RoadBlendBuilder.ground_height(field, vertices[-1].x, vertices[-1].z) - 0.035, 0.0001)
	for distance: float in [1510, 1580, 1685, 1790, 1880, 1890, 1272, 1290, 1308]:
		assert_eq(RoadBlendBuilder.width_at(TRAIL, distance), 0.0, "no easier shelf escape or buried ford")
	var default_trail := TrailDef.new()
	builder.build(sampler, profile, field, default_trail)
	assert_eq(builder.get_child_count(), 0, "other levels keep their geometry")


func test_visible_earth_join_has_matching_collision_and_mud_keeps_its_surface() -> void:
	var sampler := RoadSampler.new(CURVE, true, TRAIL)
	var profile := RoadProfile.new(TRAIL, sampler.length)
	var field := TerrainField.generate(sampler, TRAIL, TERRAIN)
	var builder := RoadBlendBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, TRAIL)
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var probes := 0
	var mud_sides: Dictionary = {}
	for child in builder.get_children():
		if not child is MeshInstance3D:
			continue
		var faces: PackedVector3Array = child.mesh.get_faces()
		for i in range(0, faces.size(), maxi(1, int(faces.size() / 120.0)) * 3):
			if (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).length_squared() < 0.000001:
				continue
			var facing := (faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i]).normalized()
			assert_gte(facing.y, 0.0, "both earth joins face up, not dark backfaces")
			var point := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.2, point - Vector3.UP * 0.2))
			assert_false(hit.is_empty())
			if not hit.is_empty():
				# Millimetre-scale precision at thin taper triangles, >1 km from origin.
				assert_lt(point.distance_to(hit.position), 0.002, "visible join and collision agree")
				var distance := sampler.closest_distance(point)
				if distance > 350.0 and distance < 450.0:
					assert_eq(SurfaceLookup.surface_of(hit.collider).id, &"deep_mud", "the blend does not add a dirt bypass")
					mud_sides[signf(sampler.lateral_offset(point))] = true
			probes += 1
	assert_gt(probes, 400)
	assert_true(mud_sides.has(-1.0))
	assert_true(mud_sides.has(1.0))
