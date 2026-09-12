extends GutTest
## The Test Ground loads, the car lands on the runway, and reset works.

const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")


func _load_level() -> Node3D:
	var level: Node3D = TEST_GROUND.instantiate()
	add_child_autofree(level)
	return level


func test_car_lands_upright_on_the_asphalt_runway() -> void:
	var level := _load_level()
	await wait_physics_frames(ScenarioHelper.ticks(2.0))
	var car: Car = level.get_node("Car")
	for wheel in car.wheels:
		assert_true(wheel.in_contact)
		assert_eq(wheel.surface.id, &"asphalt")
	assert_true(ScenarioHelper.is_upright(car))


func test_reset_returns_the_car_to_spawn() -> void:
	var level := _load_level()
	var car: Car = level.get_node("Car")
	# The touch controls own the car's virtual inputs in a real scene; switch them
	# off so this test can drive the car through the same inputs.
	level.get_node("TouchControls").process_mode = Node.PROCESS_MODE_DISABLED
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	car.input.virtual_throttle = 1.0
	await wait_physics_frames(ScenarioHelper.ticks(2.0))
	car.input.virtual_throttle = 0.0
	assert_lt(car.global_position.z, -5.0, "the car drove away first")
	car.input.request_reset()
	assert_almost_eq(car.global_position.distance_to(Vector3(0.0, 1.0, 0.0)), 0.0, 0.01)
