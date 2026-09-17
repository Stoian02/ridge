extends GutTest
## The road width profile (M5 spec §5): eased widths, the widest half-width, and
## the road mesh, terrain corridor, posts and gates following the taper.

var def: TrailDef
var sampler: RoadSampler


func before_each() -> void:
	def = TrailDef.new()
	def.undulation_amplitude = 0.0
	def.painted_lines = false
	def.width_stretches = [Vector4(100.0, 100.0, 4.5, 0.0)]
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	sampler = RoadSampler.new(curve, true, def)


func _terrain() -> TerrainDef:
	var terrain := TerrainDef.new()
	terrain.margin = 60.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	return terrain


func test_widths_ease_into_and_out_of_a_stretch() -> void:
	assert_almost_eq(def.road_width_at(50.0), 7.0, 0.0001, "the trail's width before the stretch")
	assert_almost_eq(def.shoulder_width_at(50.0), 2.5, 0.0001)
	assert_almost_eq(def.road_width_at(100.0), 7.0, 0.0001, "unchanged at the stretch's start")
	assert_almost_eq(def.road_width_at(105.0), 5.75, 0.0001, "halfway through the 10 m blend")
	assert_almost_eq(def.road_width_at(150.0), 4.5, 0.0001, "the stretch's width in its middle")
	assert_almost_eq(def.shoulder_width_at(150.0), 0.0, 0.0001)
	assert_almost_eq(def.road_width_at(195.0), 5.75, 0.0001, "easing back out")
	assert_almost_eq(def.road_width_at(200.0), 7.0, 0.0001, "the trail's width again at the end")
	assert_almost_eq(sampler.half_width_at(150.0), 2.25, 0.0001)
	assert_almost_eq(sampler.road_half_width_at(150.0), 2.25, 0.0001)
	assert_almost_eq(sampler.half_width_at(50.0), 6.0, 0.0001)


func test_half_total_width_is_the_widest_on_the_trail() -> void:
	assert_almost_eq(def.half_total_width(), 6.0, 0.0001, "a narrower stretch does not lower it")
	def.width_stretches.append(Vector4(250.0, 20.0, 10.0, 3.0))
	assert_almost_eq(def.half_total_width(), 8.0, 0.0001, "a wider stretch raises it")
	assert_almost_eq(TrailDef.new().half_total_width(), 6.0, 0.0001)


func test_a_sampler_without_a_trail_uses_the_default_widths() -> void:
	var plain := RoadSampler.new(sampler.curve)
	assert_almost_eq(plain.half_width_at(150.0), 6.0, 0.0001)
	assert_almost_eq(plain.road_half_width_at(150.0), 3.5, 0.0001)


func test_station_laterals_scale_the_road_about_the_centre_and_the_shoulders_from_its_edge() -> void:
	var road := Vector2(-2.0, RoadBuilder.Part.ROAD)
	var shoulder := Vector2(-6.0, RoadBuilder.Part.SHOULDER)
	assert_eq(RoadBuilder.station_lateral(road, 3.5, 1.0, 1.0), -2.0, "unscaled rows return the station exactly")
	assert_eq(RoadBuilder.station_lateral(shoulder, 3.5, 1.0, 1.0), -6.0)
	assert_almost_eq(RoadBuilder.station_lateral(road, 3.5, 0.5, 0.0), -1.0, 0.0001)
	assert_almost_eq(RoadBuilder.station_lateral(shoulder, 3.5, 0.5, 0.0), -1.75, 0.0001, "a zero-width shoulder collapses onto the road edge")
	assert_almost_eq(RoadBuilder.station_lateral(Vector2(6.0, RoadBuilder.Part.SHOULDER), 3.5, 1.0, 0.4), 4.5, 0.0001)


func test_road_mesh_and_collision_narrow_to_the_stretch_in_both_build_modes() -> void:
	var profile := RoadProfile.new(def, sampler.length)
	for threaded: bool in [true, false]:
		var road := RoadBuilder.new()
		road.threaded = threaded
		add_child(road)
		road.build(sampler, profile, def)
		var widest_mid := 0.0
		var widest_outside := 0.0
		for child in road.get_children():
			if child is MeshInstance3D:
				var vertices: PackedVector3Array = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					if absf(vertex.z + 150.0) < 0.6:
						widest_mid = maxf(widest_mid, absf(vertex.x))
					elif absf(vertex.z + 50.0) < 0.6:
						widest_outside = maxf(widest_outside, absf(vertex.x))
		assert_almost_eq(widest_mid, 2.25, 0.01, "4.5 m road and no shoulders mid-stretch (threaded %s)" % threaded)
		assert_almost_eq(widest_outside, 6.0, 0.01, "full width outside it (threaded %s)" % threaded)
		await wait_physics_frames(2)
		var space := road.get_world_3d().direct_space_state
		var on_road := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(2.0, 3.0, -150.0), Vector3(2.0, -3.0, -150.0)))
		assert_false(on_road.is_empty(), "collision under the narrow road")
		var off_road := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(4.0, 3.0, -150.0), Vector3(4.0, -3.0, -150.0)))
		assert_true(off_road.is_empty(), "no collision where the shoulder used to be")
		remove_child(road)
		road.queue_free()
		await wait_process_frames(1)


func test_threaded_and_serial_builders_agree_on_a_tapered_road() -> void:
	var profile := RoadProfile.new(def, sampler.length)
	var threaded := RoadBuilder.new()
	add_child_autofree(threaded)
	threaded.build(sampler, profile, def)
	var serial := RoadBuilder.new()
	serial.threaded = false
	add_child_autofree(serial)
	serial.build(sampler, profile, def)
	assert_eq(threaded.get_child_count(), serial.get_child_count())
	for i in serial.get_child_count():
		var a := threaded.get_child(i)
		var b := serial.get_child(i)
		if a is MeshInstance3D and b is MeshInstance3D:
			var aa: Array = a.mesh.surface_get_arrays(0)
			var bb: Array = b.mesh.surface_get_arrays(0)
			for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
				assert_true(aa[slot] == bb[slot], "chunk %d array %d matches exactly" % [i, slot])
		elif a is StaticBody3D and b is StaticBody3D:
			var shape_a: ConcavePolygonShape3D = a.get_child(0).shape
			var shape_b: ConcavePolygonShape3D = b.get_child(0).shape
			assert_true(shape_a.get_faces() == shape_b.get_faces(), "body %d faces match exactly" % i)


func test_the_terrain_corridor_follows_the_taper_in_both_carve_modes() -> void:
	var terrain := _terrain()
	var field := TerrainField.generate(sampler, def, terrain)
	assert_almost_eq(field.height_at(2.25, -150.0), -Corridor.EDGE_GAP, 0.05, "the shoulder edge is 2.25 m out mid-stretch")
	assert_almost_eq(field.height_at(6.0, -50.0), -Corridor.EDGE_GAP, 0.05, "and 6 m out elsewhere")
	assert_between(field.edge_distance_at(4.0, -150.0), 1.0, 2.5, "4 m out is outside the narrow shoulder edge")
	assert_lt(field.edge_distance_at(4.0, -50.0), 0.0, "and under the shoulder outside the stretch")
	var serial := TerrainField.generate(sampler, def, terrain, false)
	assert_eq(field.heights, serial.heights)
	assert_eq(field.edge_distances, serial.edge_distances)


func test_roadside_posts_stand_at_the_tapered_edge() -> void:
	var field := TerrainField.generate(sampler, def, _terrain())
	var scatter := ScatterDef.new()
	scatter.pine_spacing = 40.0
	scatter.rock_spacing = 40.0
	scatter.post_drop = -1.0  # flat ground: every side qualifies
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, RoadProfile.new(def, sampler.length), def, scatter)
	assert_gt(builder.post_count, 10)
	var inside_stretch := 0
	for post: Transform3D in builder.post_transforms:
		var spot := post.origin
		var expected := def.half_total_width_at(-spot.z) + 0.3
		assert_almost_eq(absf(spot.x), expected, 0.05, "post at %.1f m" % -spot.z)
		if -spot.z > 110.0 and -spot.z < 190.0:
			inside_stretch += 1
	assert_gt(inside_stretch, 4, "posts stand inside the narrow stretch, not only outside it")


func test_gates_narrow_with_the_road_but_never_widen_beyond_today() -> void:
	def.checkpoint_distances = PackedFloat32Array([150.0, 50.0])
	assert_almost_eq(CheckpointPlacer.gate_width_at(def, 150.0), 6.5, 0.0001, "4.5 m road plus a metre each side")
	assert_almost_eq(CheckpointPlacer.gate_width_at(def, 50.0), CheckpointPlacer.GATE_SIZE.x, 0.0001, "12 m road and shoulders keep the 12 m gate")
	var wide := TrailDef.new()
	wide.road_width = 9.0
	wide.shoulder_width = 3.0
	assert_almost_eq(CheckpointPlacer.gate_width_at(wide, 50.0), CheckpointPlacer.GATE_SIZE.x, 0.0001, "Muddy Valley's wider road keeps 12 m too")
	var placer := CheckpointPlacer.new()
	add_child_autofree(placer)
	placer.build(sampler, RoadProfile.new(def, sampler.length), def)
	var narrow_gate: Node3D = placer.get_node("Gate2")
	var box: BoxShape3D = narrow_gate.find_children("*", "CollisionShape3D", true, false)[0].shape
	assert_almost_eq(box.size.x, 6.5, 0.0001)
	var wide_gate: Node3D = placer.get_node("Gate1")
	var wide_box: BoxShape3D = wide_gate.find_children("*", "CollisionShape3D", true, false)[0].shape
	assert_almost_eq(wide_box.size.x, 12.0, 0.0001)
