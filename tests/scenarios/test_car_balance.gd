extends GutTest
## Cornering balance: does a car push its nose wide (understeer) or hang its
## rear out (oversteer)? Measured as rear tyre slip angle minus front, in a
## steady corner and on the two throttle changes that unsettle a car most.
##
## The rally cars are AWD and must behave like it. Before the 2026-09-23 tuning
## they ran 65% rear torque, and the rear stepped out by up to 9.7 deg on power
## mid-corner, which the owner felt as the car driving like a rear-wheel-drive.
## Lifting off still rotates them, on purpose.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const RALLY := preload("res://car/rally_car.tres")
const TUNED := preload("res://car/rally_car_tuned.tres")
const OFFROAD := preload("res://car/offroad_4x4.tres")
const STEER := 0.55
const TARGET_KMH := 85.0
## Rear slip may exceed front by at most this much (deg) on power mid-corner:
## an all-wheel-drive car should pull itself straight, not step out. Measured
## 1.0 at worst after the tuning, against 9.7 before it; the gap between those
## is wide enough that this catches a real regression, and the headroom absorbs
## the run-to-run variation that comes from residual physics state.
const POWER_LIMIT := 3.0
## Lifting off rotates a rally car on purpose, but it must not snap. Measured
## 4.9 at worst after the tuning, against 8.0 before it.
const LIFT_LIMIT := 6.5


func test_power_on_does_not_step_the_rear_out() -> void:
	for stats: CarStats in [RALLY, TUNED, OFFROAD]:
		for surface: SurfaceDef in [ASPHALT, DIRT]:
			var result := await _corner(stats, surface, "power")
			assert_lt(result["worst"], POWER_LIMIT, "%s on %s, power mid-corner" % [
					stats.display_name, surface.id])


func test_lifting_off_rotates_without_snapping() -> void:
	for stats: CarStats in [RALLY, TUNED, OFFROAD]:
		for surface: SurfaceDef in [ASPHALT, DIRT]:
			var result := await _corner(stats, surface, "lift")
			assert_lt(result["worst"], LIFT_LIMIT, "%s on %s, lifting off" % [
					stats.display_name, surface.id])


## A near-even torque split is what stops these cars driving like RWDs. Locking
## the centre differential was tried too and rejected: it added enough mud
## understeer to run the car off Muddy Valley's final bend (see the feel log).
func test_the_rally_cars_are_driven_as_all_wheel_drive() -> void:
	for stats: CarStats in [RALLY, TUNED]:
		assert_eq(stats.drive_type, CarStats.DriveType.AWD, stats.display_name)
		assert_between(stats.front_torque_split, 0.4, 0.5,
				"%s sends close to half its torque forward" % stats.display_name)


## Returns {"front", "rear", "worst"} in degrees. `regime` is "hold", "power"
## or "lift": the throttle change made once the car is settled in the corner.
func _corner(stats: CarStats, surface: SurfaceDef, regime: String) -> Dictionary:
	var ground := ScenarioHelper.make_flat_ground(surface, Vector3.ZERO, 3000.0)
	add_child_autofree(ground)
	var car := ScenarioHelper.spawn_car(self, Vector3(0.0, 1.0, 0.0))
	car.stats = stats
	await get_tree().physics_frame
	for i in ScenarioHelper.ticks(1.0):
		await get_tree().physics_frame

	car.input.virtual_throttle = 1.0
	for i in ScenarioHelper.ticks(30.0):
		await get_tree().physics_frame
		if car.forward_speed() * 3.6 >= TARGET_KMH:
			break
	var entry := car.forward_speed() * 3.6

	car.input.virtual_throttle = 0.35
	car.input.virtual_steer = STEER
	for i in ScenarioHelper.ticks(0.8):
		await get_tree().physics_frame
	if regime == "power":
		car.input.virtual_throttle = 1.0
	elif regime == "lift":
		car.input.virtual_throttle = 0.0

	var front := 0.0
	var rear := 0.0
	var worst := -99.0
	var samples := 0
	for i in ScenarioHelper.ticks(2.0):
		await get_tree().physics_frame
		var f := (absf(rad_to_deg(car.wheels[0].slip_angle)) + absf(rad_to_deg(car.wheels[1].slip_angle))) * 0.5
		var r := (absf(rad_to_deg(car.wheels[2].slip_angle)) + absf(rad_to_deg(car.wheels[3].slip_angle))) * 0.5
		front += f
		rear += r
		worst = maxf(worst, r - f)
		samples += 1
	gut.p("%-8s %-16s %-5s: entry %5.1f km/h, front %5.2f deg, rear %5.2f deg, worst rear-front %+5.2f" % [
			surface.id, stats.display_name, regime, entry, front / samples, rear / samples, worst])
	car.queue_free()
	ground.queue_free()
	await get_tree().physics_frame
	return {"front": front / samples, "rear": rear / samples, "worst": worst}
