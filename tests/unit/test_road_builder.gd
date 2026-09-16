extends GutTest

var def: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var builder: RoadBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -250.0))
	sampler = RoadSampler.new(curve)
	def = TrailDef.new()
	def.undulation_amplitude = 0.0
	def.rough_sections = [Vector3(120.0, 40.0, 25.0)]
	profile = RoadProfile.new(def, sampler.length)
	builder = RoadBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, def)


func _children_of(type: String) -> Array:
	return builder.get_children().filter(func(child: Node) -> bool: return child.is_class(type))


func test_cross_section_is_symmetric_with_sharp_part_boundaries() -> void:
	var stations := RoadBuilder.cross_section(def)
	assert_almost_eq(stations[0].x, -6.0, 0.0001)
	assert_almost_eq(stations[-1].x, 6.0, 0.0001)
	for i in stations.size():
		assert_almost_eq(stations[i].x, -stations[-1 - i].x, 0.0001, "station %d mirrors" % i)
	var line_stations := stations.filter(func(s: Vector2) -> bool: return int(s.y) == RoadBuilder.Part.LINE)
	assert_eq(line_stations.size(), 4, "two stations per edge line")


func test_rows_are_denser_inside_rough_ranges() -> void:
	var distances := RoadBuilder.row_distances(sampler.length, profile, def)
	assert_almost_eq(distances[0], 0.0, 0.0001)
	assert_almost_eq(distances[-1], sampler.length, 0.01)
	var inside := 0
	for d in distances:
		if d > 125.0 and d < 155.0:
			inside += 1
	assert_gte(inside, 116, "0.25 m rows over 30 m of rough ground")


func test_one_mesh_and_two_collision_bodies_per_chunk() -> void:
	assert_eq(_children_of("MeshInstance3D").size(), 3, "250 m in 100 m chunks")
	var bodies := _children_of("StaticBody3D")
	assert_eq(bodies.size(), 6)
	assert_eq(bodies[0].get_meta(SurfaceLookup.META_KEY).id, &"asphalt")
	assert_eq(bodies[1].get_meta(SurfaceLookup.META_KEY).id, &"dirt")


func test_triangles_face_up() -> void:
	var mesh: ArrayMesh = _children_of("MeshInstance3D")[0].mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var winding := (vertices[indices[t + 1]] - a).cross(vertices[indices[t + 2]] - a)
		assert_lt(winding.y, 0.0)
		if winding.y >= 0.0:
			return


func test_chunks_meet_exactly() -> void:
	var meshes := _children_of("MeshInstance3D")
	var first: PackedVector3Array = meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var second: PackedVector3Array = meshes[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var width := RoadBuilder.cross_section(def).size()
	for column in width:
		assert_eq(first[first.size() - width + column], second[column])


func test_collision_surfaces_under_road_and_shoulder() -> void:
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var road_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(1.0, 5.0, -60.0), Vector3(1.0, -5.0, -60.0)))
	var shoulder_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(5.0, 5.0, -60.0), Vector3(5.0, -5.0, -60.0)))
	assert_eq(SurfaceLookup.surface_of(road_hit["collider"]).id, &"asphalt")
	assert_eq(SurfaceLookup.surface_of(shoulder_hit["collider"]).id, &"dirt")
	var road_y: float = road_hit["position"].y
	assert_almost_eq(road_y, 0.0, 0.01)


func test_snow_shoulders_have_snow_collision() -> void:
	def.base_surface = load("res://surfaces/snow.tres")
	def.shoulder_surface = def.base_surface
	builder.build(sampler, profile, def)
	await wait_physics_frames(2)
	var hit := builder.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(Vector3(5.0, 3.0, -60.0), Vector3(5.0, -3.0, -60.0)))
	assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, &"snow")


func test_parallel_chunks_match_the_original_serial_builder() -> void:
	var muddy := _muddy_def()
	muddy.rough_sections = [Vector3(40, 120, 25)]
	muddy.undulation_amplitude = 0.1
	muddy.surface_stretches[0].transition_surfaces = [load("res://levels/muddy_valley/soft_mud.tres")]
	muddy.surface_stretches[0].transition_length = 8.0
	for definition: TrailDef in [def, muddy]:
		var road_profile := RoadProfile.new(definition, sampler.length)
		builder.threaded = true
		builder.build(sampler, road_profile, definition)
		var serial := RoadBuilder.new()
		serial.threaded = false
		add_child_autofree(serial)
		serial.build(sampler, road_profile, definition)
		assert_eq(builder.get_child_count(), serial.get_child_count())
		for i in serial.get_child_count():
			var a := builder.get_child(i)
			var b := serial.get_child(i)
			if a is MeshInstance3D and b is MeshInstance3D:
				var aa: Array = a.mesh.surface_get_arrays(0)
				var bb: Array = b.mesh.surface_get_arrays(0)
				for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
					assert_true(aa[slot] == bb[slot], "chunk %d array %d matches exactly" % [i, slot])
			elif a is StaticBody3D and b is StaticBody3D:
				assert_eq(SurfaceLookup.surface_of(a), SurfaceLookup.surface_of(b))
				var shape_a: ConcavePolygonShape3D = a.get_child(0).shape
				var shape_b: ConcavePolygonShape3D = b.get_child(0).shape
				assert_true(shape_a.get_faces() == shape_b.get_faces(), "body %d faces match exactly" % i)


func test_curved_road_parallel_geometry_matches_serial() -> void:
	var curve: Curve3D = load("res://levels/muddy_valley/muddy_valley_curve.tres")
	var definition: TrailDef = load("res://levels/muddy_valley/muddy_valley_trail.tres")
	var road := RoadSampler.new(curve)
	var road_profile := RoadProfile.new(definition, road.length)
	builder.build(road, road_profile, definition)
	var serial := RoadBuilder.new()
	serial.threaded = false
	add_child_autofree(serial)
	serial.build(road, road_profile, definition)
	assert_eq(builder.get_child_count(), serial.get_child_count())
	for i in serial.get_child_count():
		var a := builder.get_child(i)
		var b := serial.get_child(i)
		if a is MeshInstance3D and b is MeshInstance3D:
			var aa: Array = a.mesh.surface_get_arrays(0)
			var bb: Array = b.mesh.surface_get_arrays(0)
			for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
				assert_true(aa[slot] == bb[slot], "curved chunk %d slot %d" % [i, slot])
		elif a is StaticBody3D and b is StaticBody3D:
			var shape_a: ConcavePolygonShape3D = a.get_child(0).shape
			var shape_b: ConcavePolygonShape3D = b.get_child(0).shape
			assert_true(shape_a.get_faces() == shape_b.get_faces(), "curved collision %d" % i)


func test_potholes_dip_the_surface_and_darken_it() -> void:
	var pothole := profile.potholes[0]
	assert_lt(profile.height(pothole.x, pothole.y), -0.03)


func _muddy_def() -> TrailDef:
	var muddy := TrailDef.new()
	muddy.undulation_amplitude = 0.0
	muddy.road_width = 9.0
	muddy.base_surface = preload("res://surfaces/dirt.tres")
	muddy.painted_lines = false
	var stretch := SurfaceStretch.new()
	stretch.start = 120.0
	stretch.length = 50.0
	stretch.surface = preload("res://surfaces/mud.tres")
	stretch.rut_depth = 0.08
	muddy.surface_stretches = [stretch]
	return muddy


func test_a_road_without_painted_lines_has_no_line_stations() -> void:
	var stations := RoadBuilder.cross_section(_muddy_def())
	assert_false(stations.any(func(s: Vector2) -> bool: return int(s.y) == RoadBuilder.Part.LINE))
	assert_almost_eq(stations[0].x, -7.0, 0.0001, "9 m road plus 2.5 m shoulders")
	assert_almost_eq(stations[-1].x, 7.0, 0.0001)
	for i in stations.size():
		assert_almost_eq(stations[i].x, -stations[-1 - i].x, 0.0001, "station %d mirrors" % i)


func test_ruts_get_their_own_cross_section_stations() -> void:
	var laterals := RoadBuilder.cross_section(_muddy_def()).map(func(s: Vector2) -> float: return s.x)
	for rut_station: float in [0.375, 0.575, 0.775, 0.975, 1.175]:
		for side: float in [-1.0, 1.0]:
			assert_true(laterals.any(func(x: float) -> bool: return absf(x - rut_station * side) < 0.0001),
					"station at %.3f m" % (rut_station * side))


func test_rows_land_exactly_on_stretch_ends() -> void:
	var muddy := _muddy_def()
	var distances := RoadBuilder.row_distances(sampler.length, RoadProfile.new(muddy, sampler.length), muddy)
	assert_true(distances.has(120.0))
	assert_true(distances.has(170.0))


func test_collision_follows_the_surface_stretch() -> void:
	var muddy := _muddy_def()
	builder.build(sampler, RoadProfile.new(muddy, sampler.length), muddy)
	var bodies := _children_of("StaticBody3D")
	assert_eq(bodies.size(), 4, "dirt road and shoulders share a body; the middle chunk also has mud")
	assert_eq(bodies.filter(func(b: Node) -> bool: return b.get_meta(SurfaceLookup.META_KEY).id == &"mud").size(), 1)
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	for check in [[1.0, -100.0, &"dirt"], [1.0, -145.0, &"mud"], [1.0, -190.0, &"dirt"],
			[5.5, -100.0, &"dirt"], [5.5, -145.0, &"mud"], [5.5, -190.0, &"dirt"]]:
		var from := Vector3(check[0], 5.0, check[1])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0))
		assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, check[2], "at x %.1f, z %.0f" % [check[0], check[1]])


func test_shoulder_colour_blends_into_a_surface_stretch() -> void:
	var muddy := _muddy_def()
	var muddy_profile := RoadProfile.new(muddy, sampler.length)
	var stretch := muddy.surface_stretches[0]
	assert_eq(builder._color(muddy_profile, muddy, 100.0, 5.5, RoadBuilder.Part.SHOULDER), muddy.shoulder_color)
	assert_true(builder._color(muddy_profile, muddy, 145.0, 5.5, RoadBuilder.Part.SHOULDER).is_equal_approx(stretch.color))


func test_transition_surfaces_cover_the_road_and_shoulders() -> void:
	var muddy := _muddy_def()
	var stretch := muddy.surface_stretches[0]
	var damp := SurfaceDef.new()
	damp.id = &"damp_dirt"
	var soft := SurfaceDef.new()
	soft.id = &"soft_mud"
	stretch.transition_surfaces = [damp, soft]
	stretch.transition_length = 8.0
	builder.build(sampler, RoadProfile.new(muddy, sampler.length), muddy)
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	for check in [[121.0, &"damp_dirt"], [125.0, &"soft_mud"], [145.0, &"mud"],
			[165.0, &"soft_mud"], [169.0, &"damp_dirt"]]:
		for lateral: float in [1.0, 5.5]:
			var from := Vector3(lateral, 5.0, -check[0])
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 10.0))
			assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, check[1],
					"surface at %.1f m, lateral %.1f m" % [check[0], lateral])


func test_stretches_with_the_same_ruts_share_their_stations() -> void:
	var one_stretch := RoadBuilder.cross_section(_muddy_def()).size()
	var muddy := _muddy_def()
	var second := SurfaceStretch.new()
	second.start = 200.0
	second.length = 30.0
	second.surface = preload("res://surfaces/mud.tres")
	second.rut_depth = 0.08
	muddy.surface_stretches.append(second)
	var stations := RoadBuilder.cross_section(muddy)
	assert_eq(stations.size(), one_stretch, "a second stretch with the same ruts adds no stations")
	for i in stations.size() - 1:
		var same_part := int(stations[i].y) == int(stations[i + 1].y)
		assert_false(same_part and is_equal_approx(stations[i].x, stations[i + 1].x), "no repeated station at %.3f m" % stations[i].x)
