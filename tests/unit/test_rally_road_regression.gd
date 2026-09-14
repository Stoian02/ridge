extends GutTest
## Rally Road's road must come out of the surface-stretch builder exactly as it did
## before Muddy Valley: the values below were recorded from master at b349da9.
## Only the last chunk may differ, because the 60 m run-off past the finish extends it.

const CHUNK_VERTICES := [2727, 2727, 4347, 2727, 2727, 2727, 4266, 10827, 5238, 2727, 4347, 2727, 2727, 2727, 2727]
## Collision faces per chunk as [asphalt road, dirt shoulders].
const CHUNK_FACES := [
	[10800, 1200], [10800, 1200], [17280, 1920], [10800, 1200], [10800, 1200], [10800, 1200], [16956, 1884],
	[43200, 4800], [20844, 2316], [10800, 1200], [17280, 1920], [10800, 1200], [10800, 1200], [10800, 1200],
	[10800, 1200],
]


func _rally_road_trail() -> TrailLevel:
	var root: Node = load("res://levels/rally_road/rally_road.tscn").instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	add_child_autofree(trail)  # builds in _ready
	return trail


func test_rally_road_is_built_as_before_up_to_the_old_road_end() -> void:
	var trail := _rally_road_trail()
	var vertices := []
	var faces := []
	for child in trail.road_builder.get_children():
		if child is MeshInstance3D:
			vertices.append(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
		elif child is StaticBody3D:
			var shape: ConcavePolygonShape3D = child.get_child(0).shape
			faces.append([child.get_meta(SurfaceLookup.META_KEY).id, shape.get_faces().size()])
	assert_eq(vertices.size(), CHUNK_VERTICES.size() + 1, "one more chunk than recorded: the run-off")
	assert_eq(vertices.slice(0, CHUNK_VERTICES.size()), CHUNK_VERTICES)
	for chunk in CHUNK_FACES.size():
		assert_eq(faces[chunk * 2], [&"asphalt", CHUNK_FACES[chunk][0]], "chunk %d road" % chunk)
		assert_eq(faces[chunk * 2 + 1], [&"dirt", CHUNK_FACES[chunk][1]], "chunk %d shoulders" % chunk)
	assert_eq(trail.profile.potholes.size(), 36)
	assert_eq(trail.profile.patches.size(), 12)


func test_rally_road_gates_stay_put_with_road_past_the_finish() -> void:
	var trail := _rally_road_trail()
	var gates := trail.checkpoints.gate_distances
	assert_eq(Array(gates.slice(0, 5)), [10.0, 300.0, 600.0, 900.0, 1200.0])
	assert_almost_eq(gates[-1], 1503.38, 0.01, "the finish is where it was")
	assert_almost_eq(trail.sampler.length - gates[-1], 70.0, 0.01, "with 70 m of road after it")
