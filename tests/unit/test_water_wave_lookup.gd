extends GutTest


## Intentionally retain the original four-cell algorithm as an independent
## oracle. Do not update it to follow the optimized production implementation.
func _original(top: WaterWaveMesh, at: Vector2) -> Vector4:
	var key := top._cell(at)
	for dz in range(-1, 1):
		for dx in range(-1, 1):
			var candidates: PackedInt32Array = top._cells.get(key + Vector2i(dx, dz), PackedInt32Array())
			for triangle: int in candidates:
				var weights := top.barycentric(at, triangle)
				if weights.x >= -top.EPS and weights.y >= -top.EPS and weights.z >= -top.EPS:
					return Vector4(weights.x, weights.y, weights.z, triangle)
	return Vector4(0.0, 0.0, 0.0, -1.0)


func test_optimized_lookup_keeps_original_triangle_and_weights_on_interiors_and_seams() -> void:
	var course := WaterCourse.new()
	add_child_autofree(course)
	var cache := WaterWaveCourseCache.new()
	assert_true(cache.prepare(course))
	var random := RandomNumberGenerator.new()
	random.seed = 925120
	for top: WaterWaveMesh in cache.tops:
		for index in 1000:
			var at := Vector2(random.randf_range(-18.0, 18.0), random.randf_range(10.0, 170.0))
			assert_eq(top.locate(at), _original(top, at))
		for index in range(0, top.vertices.size(), 7):
			var vertex := top.vertices[index]
			for offset: Vector2 in [Vector2.ZERO, Vector2(0.000001, -0.000001),
					Vector2(-0.0001, 0.0001), Vector2(0.001, 0.001)]:
				var at := Vector2(vertex.x, vertex.z) + offset
				assert_eq(top.locate(at), _original(top, at), "including clipped/welded boundaries")
	assert_eq(cache.tops[0].triangle_at(Vector2(INF, 0.0)), -1)
