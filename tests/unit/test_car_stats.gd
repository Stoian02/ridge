extends GutTest

const RALLY := preload("res://car/rally_car.tres")


func test_rally_car_file_loads_as_awd_rally_archetype() -> void:
	assert_eq(RALLY.archetype, &"rally")
	assert_eq(RALLY.drive_type, CarStats.DriveType.AWD)


func test_torque_curve_arrays_match() -> void:
	assert_eq(RALLY.torque_curve_rpm.size(), RALLY.torque_curve_nm.size())
	for i in range(1, RALLY.torque_curve_rpm.size()):
		assert_gt(RALLY.torque_curve_rpm[i], RALLY.torque_curve_rpm[i - 1], "rpm points ascend")


func test_wheel_mount_positions() -> void:
	var stats := CarStats.new()
	# Front-left: left is -X, front is -Z.
	assert_eq(stats.wheel_mount_position(true, true), Vector3(-0.76, 0.1, -1.26))
	assert_eq(stats.wheel_mount_position(false, false), Vector3(0.76, 0.1, 1.26))


func test_static_sag_leaves_suspension_travel_both_ways() -> void:
	# At rest each spring carries a quarter of the weight. It should sit roughly in
	# the middle third of its travel, so it can both compress and extend.
	var sag := RALLY.mass * 9.8 / 4.0 / RALLY.spring_stiffness
	assert_between(sag / RALLY.suspension_length, 0.25, 0.5)
