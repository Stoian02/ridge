extends GutTest
## CarBodyBuilder's low-poly bodies, and a car wearing one (spec §6).

const CAR_SCENE := preload("res://car/car.tscn")
const RALLY_STATS := preload("res://car/rally_car.tres")


func _every_extra() -> CarBodyDef:
	var body := CarBodyDef.new()
	body.rear_spoiler = true
	body.big_wing = true
	body.hood_scoop = true
	body.roof_rack = true
	body.bull_bar = true
	body.spare_wheel = true
	body.fender_flares = true
	return body


func _vertices(mesh: ArrayMesh) -> PackedVector3Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]


func _has_color(mesh: ArrayMesh, color: Color) -> bool:
	var colors: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	# Vertex colours are stored as 8-bit, so compare within a couple of steps.
	return Array(colors).any(func(c: Color) -> bool: return Vector3(c.r, c.g, c.b).distance_to(Vector3(color.r, color.g, color.b)) < 0.02)


func test_a_body_has_triangles_and_its_colours_and_stays_cheap() -> void:
	var body := CarBodyDef.new()
	body.body_color = Color(0.1, 0.5, 0.9)
	body.window_color = Color(0.2, 0.2, 0.25)
	var plain := CarBodyBuilder.build(body, RALLY_STATS)
	assert_between(_vertices(plain).size() / 3, 40, 400)
	assert_true(_has_color(plain, body.body_color), "body colour")
	assert_true(_has_color(plain, body.window_color), "window colour")
	assert_lt(_vertices(CarBodyBuilder.build(_every_extra(), RALLY_STATS)).size() / 3, 400, "with every extra")


func test_a_plain_body_fills_the_footprint_and_rises_by_its_cabin() -> void:
	var body := CarBodyDef.new()
	var bounds := CarBodyBuilder.build(body, RALLY_STATS).get_aabb()
	var size := RALLY_STATS.body_size
	assert_almost_eq(bounds.size.x, size.x, 0.001, "as wide as the body")
	assert_almost_eq(bounds.size.z, size.z, 0.001, "as long as the body")
	assert_almost_eq(bounds.position.y, -size.y * 0.5, 0.001, "starts at the body's bottom")
	assert_almost_eq(bounds.end.y, size.y * 0.5 + body.cabin_height, 0.001, "tops out at the cabin roof")


func test_extras_stay_close_to_the_footprint() -> void:
	var bounds := CarBodyBuilder.build(_every_extra(), RALLY_STATS).get_aabb()
	var size := RALLY_STATS.body_size
	assert_lte(bounds.size.x, size.x + 0.4)
	assert_lte(bounds.size.z, size.z + 0.4)
	assert_gt(bounds.size.z, size.z, "the bull bar and spare wheel stick out")


func test_triangles_have_real_area_and_unit_normals() -> void:
	var arrays := CarBodyBuilder.build(_every_extra(), RALLY_STATS).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var degenerate := 0
	for t in range(0, vertices.size(), 3):
		if (vertices[t + 1] - vertices[t]).cross(vertices[t + 2] - vertices[t]).length() < 0.000001:
			degenerate += 1
		assert_almost_eq(normals[t].length(), 1.0, 0.001)
		if not is_equal_approx(normals[t].length(), 1.0):
			return
	assert_eq(degenerate, 0)


func test_a_car_with_a_body_def_wears_the_built_body_and_keeps_its_collision_box() -> void:
	var car: Car = CAR_SCENE.instantiate()
	car.body_def = CarBodyDef.new()
	car.body_def.rim_color = Color(0.85, 0.68, 0.22)
	add_child_autofree(car)
	assert_is(car.get_node("BodyMesh").mesh, ArrayMesh)
	assert_null(car.get_node_or_null("CabinMesh"), "the cabin is part of the built body")
	assert_eq((car.get_node("BodyShape").shape as BoxShape3D).size, car.stats.body_size)
	for wheel in car.wheels:
		assert_eq(wheel.rim_color, car.body_def.rim_color)


func test_a_car_without_a_body_def_keeps_its_gray_boxes() -> void:
	var car: Car = CAR_SCENE.instantiate()
	add_child_autofree(car)
	assert_is(car.get_node("BodyMesh").mesh, BoxMesh)
	assert_not_null(car.get_node_or_null("CabinMesh"))
