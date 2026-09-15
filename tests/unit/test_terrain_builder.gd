extends GutTest

var field: TerrainField
var builder: TerrainBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 8.0, -120.0))
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	field = TerrainField.generate(RoadSampler.new(curve), TrailDef.new(), terrain)
	builder = TerrainBuilder.new()
	add_child_autofree(builder)
	builder.build(field)


func _children_of(type: String) -> Array:
	return builder.get_children().filter(func(child: Node) -> bool: return child.is_class(type))


## Full-detail meshes, one per chunk in chunk order.
func _near_meshes() -> Array:
	return _children_of("MeshInstance3D").filter(func(mesh: MeshInstance3D) -> bool: return mesh.visibility_range_begin == 0.0)


func _far_meshes() -> Array:
	return _children_of("MeshInstance3D").filter(func(mesh: MeshInstance3D) -> bool: return mesh.visibility_range_begin > 0.0)


func test_near_and_far_mesh_and_one_dirt_body_per_chunk() -> void:
	var chunks := field.chunk_count()
	assert_eq(_near_meshes().size(), chunks.x * chunks.y)
	assert_eq(_far_meshes().size(), chunks.x * chunks.y)
	var bodies := _children_of("StaticBody3D")
	assert_eq(bodies.size(), chunks.x * chunks.y)
	assert_eq(bodies[0].get_meta(SurfaceLookup.META_KEY).id, &"dirt")


func test_far_mesh_takes_over_where_the_near_mesh_ends() -> void:
	var near: MeshInstance3D = _near_meshes()[0]
	var far: MeshInstance3D = _far_meshes()[0]
	assert_eq(near.visibility_range_end, field.def.detail_distance)
	assert_eq(far.visibility_range_begin, field.def.detail_distance)
	assert_eq(far.visibility_range_end, field.def.view_distance)
	assert_eq(far.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_far_mesh_uses_every_second_sample() -> void:
	var vertices: PackedVector3Array = _far_meshes()[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var size := field.cells_per_chunk / 2 + 1
	assert_eq(vertices.size(), size * size)
	assert_eq(vertices[size + 1], field.sample_position(2, 2))


func test_triangles_face_up() -> void:
	var mesh: ArrayMesh = _near_meshes()[0].mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, indices.size(), 3):
		var a := vertices[indices[t]]
		var winding := (vertices[indices[t + 1]] - a).cross(vertices[indices[t + 2]] - a)
		# Same winding as the proven RoughPatch mesh: the cross product points down.
		assert_lt(winding.y, 0.0)
		if winding.y >= 0.0:
			return


func test_neighbouring_chunks_share_their_border() -> void:
	var meshes := _near_meshes()
	var first: PackedVector3Array = meshes[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var second: PackedVector3Array = meshes[1].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var size := field.cells_per_chunk + 1
	for row in size:
		assert_eq(first[row * size + size - 1], second[row * size], "row %d" % row)


func test_collision_matches_the_field() -> void:
	await wait_physics_frames(2)
	var space: PhysicsDirectSpaceState3D = builder.get_world_3d().direct_space_state
	for point in [Vector2(20.0, -60.0), Vector2(-30.0, -10.0), Vector2(0.0, -100.0)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 200.0, point.y), Vector3(point.x, -200.0, point.y))
		var hit: Dictionary = space.intersect_ray(query)
		assert_false(hit.is_empty(), "ray hits the terrain at %s" % point)
		var hit_position: Vector3 = hit["position"]
		assert_almost_eq(hit_position.y, field.height_at(point.x, point.y), 0.05, "at %s" % point)


func test_building_on_worker_threads_gives_the_same_terrain_as_one_thread() -> void:
	var serial := TerrainBuilder.new()
	serial.threaded = false
	add_child_autofree(serial)
	serial.build(field)
	assert_true(builder.threaded, "levels build their terrain on worker threads by default")
	var threaded_meshes := builder.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D)
	var serial_meshes := serial.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D)
	assert_eq(threaded_meshes.size(), serial_meshes.size())
	for i in serial_meshes.size():
		var a: Array = (threaded_meshes[i] as MeshInstance3D).mesh.surface_get_arrays(0)
		var b: Array = (serial_meshes[i] as MeshInstance3D).mesh.surface_get_arrays(0)
		for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
			assert_eq(a[slot], b[slot], "mesh %d, array %d" % [i, slot])
		assert_eq(threaded_meshes[i].name, serial_meshes[i].name)
	var threaded_bodies := builder.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	var serial_bodies := serial.get_children().filter(func(n: Node) -> bool: return n is StaticBody3D)
	assert_eq(threaded_bodies.size(), serial_bodies.size())
	for i in serial_bodies.size():
		assert_eq(threaded_bodies[i].position, serial_bodies[i].position)
		var a_shape: HeightMapShape3D = threaded_bodies[i].get_child(0).shape
		var b_shape: HeightMapShape3D = serial_bodies[i].get_child(0).shape
		assert_eq(a_shape.map_data, b_shape.map_data, "collision %d" % i)


func test_mesh_positions_and_normals_match_the_field() -> void:
	var arrays: Array = (_near_meshes()[5] as MeshInstance3D).mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var size := field.cells_per_chunk + 1
	var chunks := field.chunk_count()
	var first_column := (5 % chunks.x) * field.cells_per_chunk
	var first_row := (5 / chunks.x) * field.cells_per_chunk
	for sample: Vector2i in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(size - 1, size - 1), Vector2i(10, 0)]:
		var out := sample.y * size + sample.x
		var column := first_column + sample.x
		var row := first_row + sample.y
		assert_eq(vertices[out], field.sample_position(column, row), "position at %s" % sample)
		# Meshes store normals compressed, so they come back slightly rounded.
		assert_lt(normals[out].distance_to(field.normal_at_index(column, row)), 0.01, "normal at %s" % sample)
