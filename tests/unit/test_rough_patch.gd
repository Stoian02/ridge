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


# --- Test Ground areas added after the M3B phone test ---

const SLOPE := RoughPatch.Profile.SIDE_SLOPE
const TWISTER := RoughPatch.Profile.TWISTER
const WHOOPS := RoughPatch.Profile.WHOOPS
const SLOPE_SIZE := Vector2(14.0, 180.0)


func _slope_height(x: float, along: float) -> float:
	return RoughPatch.height_at(SLOPE, Vector2(x, SLOPE_SIZE.y * 0.5 - along), SLOPE_SIZE)


func test_the_side_slope_tilts_from_flat_to_its_steepest_and_holds() -> void:
	assert_eq(RoughPatch.slope_angle_deg(5.0, SLOPE_SIZE.y), 0.0, "flat to drive onto")
	var rise_end := SLOPE_SIZE.y - RoughPatch.SLOPE_HOLD
	var halfway := (RoughPatch.SLOPE_FLAT + rise_end) * 0.5
	assert_almost_eq(RoughPatch.slope_angle_deg(halfway, SLOPE_SIZE.y), RoughPatch.SLOPE_MAX_DEG * 0.5, 0.01)
	assert_almost_eq(RoughPatch.slope_angle_deg(rise_end + 5.0, SLOPE_SIZE.y), RoughPatch.SLOPE_MAX_DEG, 0.01)
	assert_almost_eq(RoughPatch.SLOPE_MAX_DEG, 40.0, 0.01)
	for degrees: float in [5.0, 20.0, 35.0]:
		var along := RoughPatch.slope_distance_for(degrees, SLOPE_SIZE.y)
		assert_almost_eq(RoughPatch.slope_angle_deg(along, SLOPE_SIZE.y), degrees, 0.01, "a %d degree marker" % degrees)


func test_the_side_slope_rises_across_the_strip_at_its_angle() -> void:
	var along := RoughPatch.slope_distance_for(30.0, SLOPE_SIZE.y)
	var low_edge := _slope_height(SLOPE_SIZE.x * 0.5, along)
	var high_edge := _slope_height(-SLOPE_SIZE.x * 0.5, along)
	assert_almost_eq(low_edge, RoughPatch.BASE_HEIGHT, 0.001, "the +X edge stays on the ground")
	assert_almost_eq(high_edge - low_edge, SLOPE_SIZE.x * tan(deg_to_rad(30.0)), 0.001)
	assert_gt(_slope_height(0.0, along), low_edge)


func test_the_twister_humps_lift_one_wheel_line_at_a_time() -> void:
	var first := RoughPatch.TWISTER_START
	var hump := RoughPatch.BASE_HEIGHT + RoughPatch.TWISTER_HEIGHT
	assert_almost_eq(_height(TWISTER, -RoughPatch.TWISTER_OFFSET, first), hump, 0.001, "left wheel line first")
	assert_almost_eq(_height(TWISTER, RoughPatch.TWISTER_OFFSET, first), RoughPatch.BASE_HEIGHT, 0.001)
	var second := first + RoughPatch.TWISTER_SPACING
	assert_almost_eq(_height(TWISTER, RoughPatch.TWISTER_OFFSET, second), hump, 0.001, "then the right")
	assert_almost_eq(_height(TWISTER, -RoughPatch.TWISTER_OFFSET, second), RoughPatch.BASE_HEIGHT, 0.001)


func test_whoops_roll_between_the_base_and_their_crest() -> void:
	var start := RoughPatch.WHOOPS_START
	var wavelength := RoughPatch.WHOOP_WAVELENGTH
	assert_almost_eq(_height(WHOOPS, 0.0, start), RoughPatch.BASE_HEIGHT, 0.001)
	assert_almost_eq(_height(WHOOPS, 2.0, start + wavelength * 0.5), RoughPatch.BASE_HEIGHT + RoughPatch.WHOOP_HEIGHT, 0.001)
	assert_almost_eq(_height(WHOOPS, -2.0, start + wavelength), RoughPatch.BASE_HEIGHT, 0.001)


func test_new_profiles_never_go_below_the_ground() -> void:
	for which: RoughPatch.Profile in [SLOPE, TWISTER, WHOOPS]:
		var along := 0.0
		while along <= SIZE.y:
			for x: float in [-5.0, -0.8, 0.0, 0.8, 5.0]:
				assert_true(RoughPatch.height_at(which, Vector2(x, SIZE.y * 0.5 - along), SIZE) >= 0.0)
			along += 1.0


func test_a_strip_can_use_coarser_samples() -> void:
	var patch := RoughPatch.new()
	patch.surface = ASPHALT
	patch.profile = SLOPE
	patch.size = Vector2(14.0, 180.0)
	patch.spacing = 0.5
	add_child_autofree(patch)
	var collision: CollisionShape3D = patch.get_children().filter(func(n): return n is CollisionShape3D)[0]
	var shape: HeightMapShape3D = collision.shape
	assert_eq(shape.map_width, 29)
	assert_eq(shape.map_depth, 361)
	assert_almost_eq(collision.scale.x, 0.5, 0.0001)


func test_a_raised_strip_has_side_walls_down_into_the_ground() -> void:
	var patch := RoughPatch.new()
	patch.surface = ASPHALT
	patch.profile = WHOOPS
	patch.size = Vector2(4.0, 40.0)
	add_child_autofree(patch)
	var mesh_instance: MeshInstance3D = patch.get_children().filter(func(n): return n is MeshInstance3D)[0]
	var vertices: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var grid := (int(patch.size.x / patch.spacing) + 1) * (int(patch.size.y / patch.spacing) + 1)
	assert_gt(vertices.size(), grid, "wall vertices beyond the top grid")
	assert_lt(mesh_instance.mesh.get_aabb().position.y, 0.0, "walls reach below the ground, so no gap shows")
	# A wall on the left edge, halfway along a roller crest, from the top down past the ground.
	var edge := -patch.size.x * 0.5
	var along := RoughPatch.WHOOPS_START + RoughPatch.WHOOP_WAVELENGTH * 0.5
	var z := patch.size.y * 0.5 - along
	var top := RoughPatch.height_at(WHOOPS, Vector2(edge, z), patch.size)
	var has_top := false
	var has_bottom := false
	for vertex in vertices.slice(grid):
		if absf(vertex.x - edge) < 0.001 and absf(vertex.z - z) < 0.001:
			has_top = has_top or absf(vertex.y - top) < 0.001
			has_bottom = has_bottom or vertex.y < 0.0
	assert_true(has_top and has_bottom, "the left edge wall spans the roller's full height")
