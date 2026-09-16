extends GutTest
## Compare real winter launches, without requiring less TC to mean more speed:
## wheelspin/rev limiting can make the fully-off setting slower too.

const CAR := preload("res://car/car.tscn")
const CARS: Array[CarDef] = [preload("res://car/cars/rally.tres"),
		preload("res://car/cars/rally_tuned.tres"), preload("res://car/cars/offroad_4x4.tres")]
const SURFACES: Array[SurfaceDef] = [preload("res://surfaces/snow.tres"), preload("res://surfaces/ice.tres")]


func _launch(car_def: CarDef, strength: float) -> Dictionary:
	var car: Car = CAR.instantiate()
	car.stats = car_def.stats
	car.body_def = car_def.body
	car.position = Vector3(0.0, 1.0, 0.0)
	add_child(car)
	car.drivetrain.traction_control_strength = strength
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var start := car.position
	var slip := 0.0
	var ticks := ScenarioHelper.ticks(6.0)
	car.input.virtual_throttle = 1.0
	for tick in ticks:
		await get_tree().physics_frame
		for wheel: Wheel in car.wheels:
			slip += maxf(wheel.slip_ratio, 0.0) / (ticks * 4.0)
	var result := {"distance": start.z - car.position.z, "slip": slip, "speed": car.forward_speed() * 3.6}
	assert_true(car.position.is_finite())
	assert_true(ScenarioHelper.is_upright(car))
	assert_gt(result["distance"], 1.0, "still pulls away")
	remove_child(car)
	car.queue_free()
	await get_tree().process_frame
	return result


func test_all_cars_launch_on_snow_and_ice_with_off_partial_and_full_assist() -> void:
	for surface: SurfaceDef in SURFACES:
		var ground := ScenarioHelper.make_flat_ground(surface)
		add_child(ground)
		for car_def: CarDef in CARS:
			var samples: Array[Dictionary] = []
			for strength: float in [0.0, 0.5, 1.0]:
				var sample := await _launch(car_def, strength)
				samples.append(sample)
				gut.p("%s %s TC %d%%: 6 s launch %.1f m, %.1f km/h, mean wheel slip %.2f" % [
						car_def.display_name, surface.id, roundi(strength * 100),
						sample["distance"], sample["speed"], sample["slip"]])
			assert_gt(samples[0]["slip"], samples[2]["slip"], "off allows more wheelspin than full")
		remove_child(ground)
		ground.queue_free()
		await get_tree().process_frame
