extends GutTest

var sampler: RoadSampler
var flat: RoadProfile


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -100.0))
	sampler = RoadSampler.new(curve)
	var def := TrailDef.new()
	def.undulation_amplitude = 0.0
	flat = RoadProfile.new(def, sampler.length)


func _assert_vec(actual: Vector3, expected: Vector3, message: String) -> void:
	assert_almost_eq(actual.distance_to(expected), 0.0, 0.01, "%s: got %s" % [message, actual])


func test_length_and_position() -> void:
	assert_almost_eq(sampler.length, 100.0, 0.01)
	_assert_vec(sampler.position(50.0), Vector3(0.0, 0.0, -50.0), "position at 50 m")


func test_directions_on_a_straight_road() -> void:
	_assert_vec(sampler.forward(50.0), Vector3.FORWARD, "forward")
	_assert_vec(sampler.up(50.0), Vector3.UP, "up")
	_assert_vec(sampler.right(50.0), Vector3.RIGHT, "right")


func test_directions_hold_at_the_ends() -> void:
	_assert_vec(sampler.forward(0.0), Vector3.FORWARD, "forward at the start")
	_assert_vec(sampler.forward(100.0), Vector3.FORWARD, "forward at the end")


func test_closest_distance_and_lateral_offset() -> void:
	assert_almost_eq(sampler.closest_distance(Vector3(3.0, 0.0, -40.0)), 40.0, 0.1)
	assert_almost_eq(sampler.lateral_offset(Vector3(3.0, 0.0, -40.0)), 3.0, 0.05, "right of the road")
	assert_almost_eq(sampler.lateral_offset(Vector3(-2.0, 0.0, -10.0)), -2.0, 0.05, "left of the road")


func test_transform_at_faces_along_the_road() -> void:
	var transform := sampler.transform_at(20.0, 1.0, flat)
	_assert_vec(transform.origin, Vector3(0.0, 1.0, -20.0), "origin 1 m above the surface")
	_assert_vec(-transform.basis.z, Vector3.FORWARD, "the transform's forward")


func test_up_stays_perpendicular_on_a_climb() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 10.0, -100.0))
	var climbing := RoadSampler.new(curve)
	var along := climbing.forward(50.0)
	var surface_up := climbing.up(50.0)
	assert_almost_eq(along.dot(surface_up), 0.0, 0.001, "up is perpendicular to the road")
	assert_gt(surface_up.y, 0.99, "and points almost straight up on a 10% grade")
