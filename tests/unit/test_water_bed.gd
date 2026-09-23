extends GutTest
## Exact static-bed data without bilinear terrain, whole-world copies or boxes
## pretending to be the silhouettes of fixed boulders.

const QUERIES := preload("res://tests/unit/test_water_queries.gd")


func test_terrain_extraction_matches_rendered_diagonal_and_skips_portal_holes() -> void:
	var field := TerrainField.new()
	field.columns = 3
	field.rows = 3
	field.spacing = 1.0
	field.heights = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0, 0.0, 0.0])
	var top: PackedVector3Array = QUERIES.quad(3.0, Vector2(0.01, 0.01), Vector2(0.99, 0.99))
	var bed := WaterBed.extract(top, field, [])
	assert_eq(bed.size(), 6, "only the intersecting cell, not the whole field")
	assert_eq(WaterBody.triangle_height(bed, 0, 0.25, 0.25), 0.0)
	assert_almost_eq(WaterBody.triangle_height(bed, 3, 0.75, 0.75), 2.0, 0.000001)
	field.portal_holes = PackedByteArray([0, 0, 0, 0, 1, 0, 0, 0, 0])
	assert_true(WaterBed.extract(top, field, []).is_empty())


func test_nearby_meshes_are_copied_in_level_space_not_global_or_nominal_space() -> void:
	var root := Node3D.new()
	root.transform = Transform3D(Basis(Vector3.UP, 0.5), Vector3(20.0, 3.0, -30.0))
	add_child_autofree(root)
	var structure := StructureMesh.new()
	structure.box(Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(1.0, 1.0, 1.0), Color.GRAY)
	structure.add_to(root, "Near", null)
	var far := StructureMesh.new()
	far.box(Transform3D(Basis.IDENTITY, Vector3(100.0, 0.0, 0.0)), Vector3.ONE, Color.GRAY)
	far.add_to(root, "Far", null)
	var bed := WaterBed.extract(QUERIES.quad(2.0), null, [root], root.transform)
	assert_eq(bed.size(), 36, "only the nearby box")
	for point: Vector3 in bed:
		assert_lte(absf(point.x), 0.50001)
		assert_lte(absf(point.y), 0.50001)
		assert_lte(absf(point.z), 0.50001)


func test_unordered_convex_points_give_the_hull_not_their_accidental_triangle_groups() -> void:
	var points := PackedVector3Array([Vector3(1, 1, 1), Vector3(-1, -1, -1),
			Vector3(1, -1, 1), Vector3(-1, 1, -1), Vector3(1, 1, -1),
			Vector3(-1, -1, 1), Vector3(1, -1, -1), Vector3(-1, 1, 1)])
	var faces := WaterBed.convex_faces(points)
	assert_gt(faces.size(), 0)
	var highest := -INF
	for index in faces.size() / 3:
		highest = maxf(highest, WaterBody.triangle_height(faces, index * 3, 0.35, -0.42))
	assert_almost_eq(highest, 1.0, 0.000001)
	var outside := -INF
	for index in faces.size() / 3:
		outside = maxf(outside, WaterBody.triangle_height(faces, index * 3, 1.5, 0.0))
	assert_eq(outside, -INF, "no oversized bounding-box water mask")


func test_exact_stored_vertex_index_expansion_preserves_order_and_large_world_precision() -> void:
	var vertices := PackedVector3Array([Vector3(1400.1234, 82.01234, -800.4567),
			Vector3(1402.1234, 82.09876, -800.4567), Vector3(1400.1234, 82.04321, -802.4567),
			Vector3(1402.1234, 82.05678, -802.4567)])
	var indices := PackedInt32Array([0, 1, 2, 1, 3, 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var faces := WaterBed.mesh_faces(mesh)
	assert_eq(faces.size(), indices.size())
	for index in indices.size():
		assert_eq(faces[index], vertices[indices[index]], "no TriangleMesh quantization or face reorder")


func test_one_build_snapshot_reuses_static_candidates_without_changing_extracted_faces() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var structure := StructureMesh.new()
	structure.box(Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3.ONE, Color.GRAY)
	structure.add_to(root, "Solid", preload("res://surfaces/rock.tres"))
	var source := WaterBed.new()
	source.configure(null, [root])
	var top: PackedVector3Array = QUERIES.quad(2.0)
	var first := source.extract_faces(top)
	var second := source.extract_faces(top)
	assert_eq(first, second)
	assert_eq(first, WaterBed.extract(top, null, [root]))
	assert_eq(first.size(), 36, "collider subtree does not duplicate its mesh")
	assert_true(source.extract_faces(QUERIES.quad(2.0, Vector2(10.0, 10.0), Vector2(12.0, 12.0))).is_empty())
