extends GutTest


func test_damp_moves_part_way_toward_the_target() -> void:
	var result := ChaseCamera.damp(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 5.0, 0.1)
	# 10 * (1 - e^-0.5) = 3.93
	assert_almost_eq(result.x, 3.935, 0.001)


func test_damp_is_frame_rate_independent() -> void:
	var goal := Vector3(10.0, 4.0, -2.0)
	var one_step := ChaseCamera.damp(Vector3.ZERO, goal, 5.0, 0.1)
	var two_steps := ChaseCamera.damp(ChaseCamera.damp(Vector3.ZERO, goal, 5.0, 0.05), goal, 5.0, 0.05)
	assert_almost_eq(one_step.distance_to(two_steps), 0.0, 0.0001)


func test_damp_arrives_eventually() -> void:
	var result := ChaseCamera.damp(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 5.0, 10.0)
	assert_almost_eq(result.x, 10.0, 0.001)


func test_flat_heading_ignores_pitch() -> void:
	var nose_up := Basis(Vector3.RIGHT, deg_to_rad(30.0))
	var heading := ChaseCamera.flat_heading(nose_up, Vector3.RIGHT)
	assert_almost_eq(heading.distance_to(Vector3.FORWARD), 0.0, 0.0001)


func test_flat_heading_keeps_previous_when_pointing_straight_up() -> void:
	var vertical := Basis(Vector3.RIGHT, deg_to_rad(90.0))
	assert_eq(ChaseCamera.flat_heading(vertical, Vector3.RIGHT), Vector3.RIGHT)
