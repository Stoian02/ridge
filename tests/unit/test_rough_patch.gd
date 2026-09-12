extends GutTest

const ASPHALT := preload("res://surfaces/asphalt.tres")
const SIZE := Vector2(10.0, 200.0)
const ROUGH := RoughPatch.Profile.ROUGH_ASPHALT
const RUTS := RoughPatch.Profile.RUTTED_MUD


## Height at x across and `along` metres from the entry end.
func _height(which: RoughPatch.Profile, x: float, along: float) -> float:
	return RoughPatch.height_at(which, Vector2(x, SIZE.y * 0.5 - along), SIZE)


func test_strip_starts_and_ends_at_ground_level() -> void:
	assert_almost_eq(_height(ROUGH, 0.0, 0.0), 0.0, 0.0001)
	assert_almost_eq(_height(ROUGH, 0.0, SIZE.y), 0.0, 0.0001)


func test_plain_stretch_sits_at_base_height() -> void:
	assert_almost_eq(_height(ROUGH, 4.0, 180.0), RoughPatch.BASE_HEIGHT, 0.0001)


func test_pothole_dips_below_base() -> void:
	# Centre of the first pothole: (x -1.2, 10 m along).
	var expected := RoughPatch.BASE_HEIGHT - RoughPatch.POTHOLE_DEPTH
	assert_almost_eq(_height(ROUGH, -1.2, 10.0), expected, 0.0001)


func test_speed_bump_rises_above_base() -> void:
	var expected := RoughPatch.BASE_HEIGHT + RoughPatch.BUMP_HEIGHT
	assert_almost_eq(_height(ROUGH, 0.0, 70.0), expected, 0.0001)


func test_washboard_ripples_around_base() -> void:
	var quarter := RoughPatch.WASHBOARD_WAVELENGTH * 0.25
	var crest := _height(ROUGH, 0.0, RoughPatch.WASHBOARD_START + quarter)
	assert_almost_eq(crest, RoughPatch.BASE_HEIGHT + RoughPatch.WASHBOARD_AMPLITUDE, 0.001)


func test_ruts_follow_the_wheel_track() -> void:
	var between := _height(RUTS, 0.0, 50.0)
	assert_almost_eq(_height(RUTS, -0.76, 50.0), between - RoughPatch.RUT_DEPTH, 0.0001)
	assert_almost_eq(_height(RUTS, 0.76, 50.0), between - RoughPatch.RUT_DEPTH, 0.0001)


func test_heights_never_go_below_the_ground() -> void:
	for which in [ROUGH, RUTS]:
		var along := 0.0
		while along <= SIZE.y:
			for x in [-5.0, -1.2, -0.76, 0.0, 0.76, 1.5, 5.0]:
				assert_true(_height(which, x, along) >= 0.0)
			along += 0.5


func test_built_mesh_faces_up() -> void:
	var patch := RoughPatch.new()
	patch.surface = ASPHALT
	patch.size = Vector2(4.0, 20.0)
	add_child_autofree(patch)
	var mesh_instance: MeshInstance3D = patch.get_children().filter(func(n): return n is MeshInstance3D)[0]
	var normals: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_gt(normals[0].y, 0.5, "normals point up, so the strip is lit and visible from above")
