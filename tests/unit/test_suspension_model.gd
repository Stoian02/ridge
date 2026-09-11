extends GutTest


func test_no_force_at_full_extension() -> void:
	assert_almost_eq(SuspensionModel.spring_damper_force(0.0, 0.0, 30000.0, 2000.0, 3000.0), 0.0, 0.001)


func test_spring_force_is_stiffness_times_compression() -> void:
	assert_almost_eq(SuspensionModel.spring_damper_force(0.1, 0.0, 30000.0, 2000.0, 3000.0), 3000.0, 0.001)


func test_compress_damping_used_while_compressing() -> void:
	# 0.1 * 30000 + 0.5 * 2000
	assert_almost_eq(SuspensionModel.spring_damper_force(0.1, 0.5, 30000.0, 2000.0, 3000.0), 4000.0, 0.001)


func test_rebound_damping_used_while_extending() -> void:
	# 0.1 * 30000 - 0.5 * 3000
	assert_almost_eq(SuspensionModel.spring_damper_force(0.1, -0.5, 30000.0, 2000.0, 3000.0), 1500.0, 0.001)


func test_force_never_pulls_the_car_down() -> void:
	assert_almost_eq(SuspensionModel.spring_damper_force(0.01, -2.0, 30000.0, 2000.0, 3000.0), 0.0, 0.001)


func test_bump_stop_inactive_before_last_15_percent() -> void:
	assert_almost_eq(SuspensionModel.bump_stop_force(0.25, 0.35, 200000.0), 0.0, 0.001)


func test_bump_stop_pushes_hard_near_full_compression() -> void:
	# Starts at 0.2975: (0.35 - 0.2975) * 200000 = 10500
	assert_almost_eq(SuspensionModel.bump_stop_force(0.35, 0.35, 200000.0), 10500.0, 0.01)


func test_anti_roll_pushes_the_compressed_side_up() -> void:
	assert_almost_eq(SuspensionModel.anti_roll_force(0.2, 0.1, 8000.0), 800.0, 0.001)
	assert_almost_eq(SuspensionModel.anti_roll_force(0.1, 0.2, 8000.0), -800.0, 0.001)
