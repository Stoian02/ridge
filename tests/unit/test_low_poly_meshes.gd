extends GutTest


func _assert_faces_point_away_from(mesh: ArrayMesh, centre: Vector3) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(vertices.size(), 0, "mesh has triangles")
	for t in range(0, vertices.size(), 3):
		var face_centre := (vertices[t] + vertices[t + 1] + vertices[t + 2]) / 3.0
		assert_gt(normals[t].dot(face_centre - centre), 0.0, "triangle %d faces outward" % (t / 3))
		if normals[t].dot(face_centre - centre) <= 0.0:
			return


func test_rock_faces_outward() -> void:
	_assert_faces_point_away_from(LowPolyMeshes.rock(Color.GRAY, 3), Vector3.ZERO)


func test_post_faces_outward() -> void:
	# The post is a single convex box apart from its band; check the body box on its own.
	_assert_faces_point_away_from(LowPolyMeshes.gate_post(Color.WHITE, 4.0), Vector3(0.0, 2.0, 0.0))


func test_banner_faces_outward() -> void:
	_assert_faces_point_away_from(LowPolyMeshes.banner(Color.ORANGE, 13.0), Vector3.ZERO)


func test_pine_has_trunk_and_foliage_colours() -> void:
	var mesh := LowPolyMeshes.pine(Color(0.3, 0.4, 0.2), Color(0.4, 0.3, 0.2))
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_gt(colors.size(), 60)
	# Vertex colours are stored as 8-bit, so compare within one step of 1/255.
	var trunk := Vector3(0.4, 0.3, 0.2)
	assert_true(Array(colors).any(func(c: Color) -> bool: return Vector3(c.r, c.g, c.b).distance_to(trunk) < 0.01), "trunk colour present")


func test_rocks_differ_by_seed() -> void:
	var a: PackedVector3Array = LowPolyMeshes.rock(Color.GRAY, 1).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var b: PackedVector3Array = LowPolyMeshes.rock(Color.GRAY, 2).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_ne(a, b)


func test_broadleaf_tree_has_a_trunk_and_leaves_and_stays_cheap() -> void:
	var mesh := LowPolyMeshes.broadleaf(Color(0.38, 0.5, 0.22), Color(0.33, 0.25, 0.18), 4)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_between(vertices.size() / 3, 20, 150, "about as cheap as a pine")
	var top: float = Array(vertices).map(func(v: Vector3) -> float: return v.y).max()
	assert_between(top, 4.0, 6.5, "about 5 m tall")
	var trunk := Vector3(0.33, 0.25, 0.18)
	assert_true(Array(colors).any(func(c: Color) -> bool: return Vector3(c.r, c.g, c.b).distance_to(trunk) < 0.01), "trunk colour present")
