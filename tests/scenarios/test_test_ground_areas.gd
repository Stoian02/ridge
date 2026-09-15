extends GutTest
## The Test Ground areas added after the M3B phone test: each car drives along both
## side slopes and reports the tilt where it starts sliding down, and crawls over the
## ground clearance logs. The printed numbers are for comparing cars; the asserts
## only check the areas work.

const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")
const GROUND_SCRIPT := preload("res://levels/test_ground/test_ground.gd")
const RALLY := preload("res://car/cars/rally.tres")
const TUNED := preload("res://car/cars/rally_tuned.tres")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")

## Driving along a slope at this speed (m/s), about 16 km/h.
const SLOPE_SPEED := 4.5
## Drifting this far down from the driven line counts as sliding (m).
const SLIDE_DRIFT := 1.5
const LOG_SPEED := 2.5


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _ground(car_def: CarDef) -> Node3D:
	var ground: Node3D = TEST_GROUND.instantiate()
	(ground.get_node("DrivingRig") as DrivingRig).car_override = car_def
	add_child_autofree(ground)
	(ground.get_node("DrivingRig") as DrivingRig).touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return ground


func _free(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await get_tree().process_frame


## Drives along a side slope's centre line; returns the tilt (degrees) where the car
## first drifted SLIDE_DRIFT down the slope, or -1.0 if it held its line to the end.
func _slope_slide_angle(car_def: CarDef, center_x: float) -> float:
	var ground := _ground(car_def)
	var rig: DrivingRig = ground.get_node("DrivingRig")
	var car := rig.car
	rig.place_car(Transform3D(Basis(), Vector3(center_x, 1.0, GROUND_SCRIPT.STRIP_ENTRY_Z - 4.0)))
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var angle := -1.0
	for tick in ScenarioHelper.ticks(60.0):
		var along: float = GROUND_SCRIPT.STRIP_ENTRY_Z - car.global_position.z
		if along > GROUND_SCRIPT.SLOPE_SIZE.y - 5.0:
			break
		TrailScenarios.drive_toward(car, Vector3(center_x, car.global_position.y, car.global_position.z - 10.0), SLOPE_SPEED)
		await get_tree().physics_frame
		if car.global_position.x - center_x > SLIDE_DRIFT:
			angle = RoughPatch.slope_angle_deg(along, GROUND_SCRIPT.SLOPE_SIZE.y)
			break
	await _free(ground)
	return angle


func test_each_car_holds_a_gentle_side_slope_and_reports_where_it_slides() -> void:
	for car_def: CarDef in [RALLY, TUNED, OFFROAD]:
		var line := "%s sideways on the slopes:" % car_def.display_name
		for slope: Array in [["asphalt", GROUND_SCRIPT.ASPHALT_SLOPE_X], ["dirt", GROUND_SCRIPT.DIRT_SLOPE_X]]:
			var angle := await _slope_slide_angle(car_def, slope[1])
			line += " %s %s," % [slope[0], "slides at %.0f deg" % angle if angle >= 0.0 else "held to the end"]
			assert_true(angle < 0.0 or angle >= 10.0, "%s on %s: no slide before 10 degrees" % [car_def.display_name, slope[0]])
		gut.p(line.trim_suffix(","))


## Crawls down the clearance lane; returns how many logs the car got past.
func _logs_cleared(car_def: CarDef) -> int:
	var ground := _ground(car_def)
	var rig: DrivingRig = ground.get_node("DrivingRig")
	var car := rig.car
	var lane_x: float = GROUND_SCRIPT.LOGS_X
	rig.place_car(Transform3D(Basis(), Vector3(lane_x, 1.0, GROUND_SCRIPT.STRIP_ENTRY_Z - 2.0)))
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var cleared := 0
	var furthest: float = car.global_position.z
	var stalled := 0.0
	for tick in ScenarioHelper.ticks(60.0):
		TrailScenarios.drive_toward(car, Vector3(lane_x, car.global_position.y, car.global_position.z - 10.0), LOG_SPEED)
		await get_tree().physics_frame
		if car.global_position.z < furthest - 0.05:
			furthest = car.global_position.z
			stalled = 0.0
		else:
			stalled += 1.0 / Engine.physics_ticks_per_second
		var log_z: float = GROUND_SCRIPT.STRIP_ENTRY_Z - 25.0 - cleared * 25.0
		if cleared < GROUND_SCRIPT.LOG_DIAMETERS.size() and furthest < log_z - 3.0:
			cleared += 1
		if cleared == GROUND_SCRIPT.LOG_DIAMETERS.size() or stalled > 6.0:
			break
	await _free(ground)
	return cleared


func test_the_4x4_clears_logs_the_rally_car_cannot() -> void:
	var cleared := {}
	for car_def: CarDef in [RALLY, TUNED, OFFROAD]:
		cleared[car_def.id] = await _logs_cleared(car_def)
		var names := GROUND_SCRIPT.LOG_DIAMETERS.slice(0, cleared[car_def.id]).map(
				func(d: float) -> String: return "%d cm" % roundi(d * 100.0))
		gut.p("%s over the clearance logs: cleared %s" % [car_def.display_name,
				", ".join(names) if not names.is_empty() else "none"])
	assert_gte(cleared[&"rally"], 1, "the Rally Car gets over the 15 cm log")
	assert_gte(cleared[&"offroad_4x4"], 2, "the 4x4 gets over the 25 cm log")
	assert_gte(cleared[&"offroad_4x4"], cleared[&"rally"], "the 4x4 clears at least as many as the Rally Car")
