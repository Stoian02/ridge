extends GutTest
## The car can drive over the rough strips: it stays upright and on the strip,
## and the suspension actually works (compression varies over the features).

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")


## Builds dirt ground plus a strip whose entry is at z = 0 (running toward -Z),
## drives a car across it at roughly target_kmh for `seconds`, and returns stats.
func _drive_over(surface: SurfaceDef, profile: RoughPatch.Profile, length: float,
		target_kmh: float, seconds: float) -> Dictionary:
	add_child_autofree(ScenarioHelper.make_flat_ground(DIRT))
	var patch := RoughPatch.new()
	patch.surface = surface
	patch.profile = profile
	patch.size = Vector2(10.0, length)
	patch.position = Vector3(0.0, 0.0, -length * 0.5)
	add_child_autofree(patch)
	var car := ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 8.0))
	await wait_physics_frames(ScenarioHelper.ticks(1.0))

	var lowest := INF
	var highest := -INF
	var saw_surface := false
	for i in ScenarioHelper.ticks(seconds):
		car.input.virtual_throttle = 1.0 if car.forward_speed() * 3.6 < target_kmh else 0.0
		await get_tree().physics_frame
		var wheel: Wheel = car.wheels[0]
		if wheel.in_contact and wheel.surface == surface:
			saw_surface = true
			lowest = minf(lowest, wheel.compression)
			highest = maxf(highest, wheel.compression)
	return {"car": car, "saw_surface": saw_surface, "compression_range": highest - lowest}


func test_rough_asphalt_is_drivable_and_felt() -> void:
	var result := await _drive_over(ASPHALT, RoughPatch.Profile.ROUGH_ASPHALT, 200.0, 50.0, 14.0)
	var car: Car = result.car
	gut.p("rough asphalt: compression range %.3f m, ended at z %.0f" % [result.compression_range, car.global_position.z])
	assert_true(result.saw_surface, "the front-left wheel drove on the strip")
	assert_gt(result.compression_range, 0.04, "bumps and potholes moved the suspension")
	assert_true(ScenarioHelper.is_upright(car))
	assert_lt(absf(car.global_position.x), 4.0, "still on the 10 m wide strip")


func test_rutted_mud_is_drivable_and_felt() -> void:
	var result := await _drive_over(MUD, RoughPatch.Profile.RUTTED_MUD, 100.0, 30.0, 10.0)
	var car: Car = result.car
	gut.p("rutted mud: compression range %.3f m, ended at z %.0f" % [result.compression_range, car.global_position.z])
	assert_true(result.saw_surface, "the front-left wheel drove on the strip")
	assert_gt(result.compression_range, 0.02, "the waves moved the suspension")
	assert_true(ScenarioHelper.is_upright(car))
	assert_lt(absf(car.global_position.x), 4.0, "still on the 10 m wide strip")
