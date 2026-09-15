extends GutTest
## The three cars on real ground (spec §8.2): the new cars finish both levels, the
## tuned car is quicker on asphalt, the 4x4 is quicker up the mud climb and its
## differential locks matter, the 4x4 does not roll at full lock, and a run drives
## the car chosen in car select.

const RALLY_ROAD := preload("res://levels/rally_road/rally_road.tscn")
const MUDDY_VALLEY := preload("res://levels/muddy_valley/muddy_valley.tscn")
const CAR_SCENE := preload("res://car/car.tscn")
const RALLY := preload("res://car/cars/rally.tres")
const TUNED := preload("res://car/cars/rally_tuned.tres")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")
const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


## A level scene driven by `car_def`, with touch controls off.
func _level(scene: PackedScene, car_def: CarDef) -> RunLevel:
	var level: RunLevel = scene.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = car_def
	add_child(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level


func _free(node: Node) -> void:
	remove_child(node)
	node.queue_free()
	await get_tree().process_frame


## Drives a whole level with the scripted driver. Returns the finish time, or -1.0
## without a finish; fails the test on any reset. `surface_aware` makes the driver
## slow for the grip of the surface ahead.
func _scripted_run(scene: PackedScene, car_def: CarDef, surface_aware := false) -> float:
	var level := _level(scene, car_def)
	var driver := TrailDriver.new(level.rig.car, level.trail.sampler, level.trail.profile if surface_aware else null)
	watch_signals(level.resets)
	for tick in ScenarioHelper.ticks(200.0):
		if level.tracker.is_finished():
			break
		driver.drive()
		await get_tree().physics_frame
	var time := level.run.clock.elapsed if level.tracker.is_finished() else -1.0
	var resets: int = get_signal_emit_count(level.resets, "car_reset")
	gut.p("%s on %s: %s, %d resets" % [car_def.display_name, level.name,
			RunHud.format_time(time) if time > 0.0 else "no finish", resets])
	assert_eq(resets, 0, "%s on %s: no resets" % [car_def.display_name, level.name])
	await _free(level)
	return time


func test_every_car_finishes_rally_road_and_the_tuned_car_is_quickest() -> void:
	var times := {}
	for car_def: CarDef in [RALLY, TUNED, OFFROAD]:
		times[car_def.id] = await _scripted_run(RALLY_ROAD, car_def)
		assert_between(times[car_def.id], 60.0, 150.0, car_def.display_name)
	assert_lt(times[&"rally_tuned"], times[&"rally"], "the tuned car beats stock on asphalt")


## The plain scripted driver judges speed by tire grip alone, so the grippier tuned
## car reaches Muddy Valley's hedged mud too fast and slides into a hedge it cannot
## reverse away from. The surface-aware driver slows for mud, as a player would.
func test_the_new_cars_finish_muddy_valley() -> void:
	for car_def: CarDef in [TUNED, OFFROAD]:
		var time := await _scripted_run(MUDDY_VALLEY, car_def, true)
		assert_between(time, 60.0, 150.0, car_def.display_name)


## Seconds from rest to `kmh` at full throttle, straight on flat `surface`; -1.0 if
## not reached in 20 s. `stats` override `car_def`'s own when set.
func _time_to_speed(car_def: CarDef, surface: SurfaceDef, kmh: float) -> float:
	var ground := ScenarioHelper.make_flat_ground(surface)
	add_child(ground)
	var car: Car = CAR_SCENE.instantiate()
	car.stats = car_def.stats
	car.body_def = car_def.body
	car.position = Vector3(0.0, 1.0, 0.0)
	add_child(car)
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var seconds := -1.0
	for tick in ScenarioHelper.ticks(20.0):
		car.input.virtual_throttle = 1.0
		await get_tree().physics_frame
		if car.forward_speed() * 3.6 >= kmh:
			seconds = tick / float(Engine.physics_ticks_per_second)
			break
	await _free(car)
	await _free(ground)
	return seconds


func test_the_tuned_car_reaches_100_kmh_clearly_sooner_than_stock() -> void:
	var stock := await _time_to_speed(RALLY, ASPHALT, 100.0)
	var tuned := await _time_to_speed(TUNED, ASPHALT, 100.0)
	gut.p("0-100 km/h on asphalt: stock %.2f s, tuned %.2f s" % [stock, tuned])
	assert_gt(stock, 0.0)
	assert_gt(tuned, 0.0)
	assert_lt(tuned, stock * 0.9, "at least 10% sooner")


func test_the_4x4_climbs_out_of_the_mud_sooner_than_the_rally_car() -> void:
	var seconds := {}
	for car_def: CarDef in [RALLY, OFFROAD]:
		var level := _level(MUDDY_VALLEY, car_def)
		await TrailScenarios.wait_for_go(level)
		await TrailScenarios.place_on_road(level, 1400.0)
		var finish := level.trail.checkpoints.gate_distances[-1]
		var car := level.rig.car
		seconds[car_def.id] = await TrailScenarios.full_throttle_until(level, 30.0,
				func() -> bool: return level.trail.sampler.closest_distance(car.global_position) >= finish)
		await _free(level)
	gut.p("from a standstill at 1400 m up the mud to the finish: Rally Car %.1f s, 4x4 %.1f s" % [
			seconds[&"rally"], seconds[&"offroad_4x4"]])
	assert_lt(seconds[&"offroad_4x4"], seconds[&"rally"])


## Metres covered from rest in `seconds` at full throttle, with the left wheels on
## near-frictionless ground and the right wheels on dirt.
func _split_surface_pull(stats: CarStats, seconds: float) -> float:
	var slick := SurfaceDef.new()
	slick.id = &"slick"
	slick.grip = 0.05
	var left := ScenarioHelper.make_flat_ground(slick, Vector3(-150.0, 0.0, 0.0), 300.0)
	var right := ScenarioHelper.make_flat_ground(DIRT, Vector3(150.0, 0.0, 0.0), 300.0)
	add_child(left)
	add_child(right)
	var car: Car = CAR_SCENE.instantiate()
	car.stats = stats
	car.position = Vector3(0.0, 1.2, 0.0)
	add_child(car)
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var start := car.global_position
	for tick in ScenarioHelper.ticks(seconds):
		car.input.virtual_throttle = 1.0
		await get_tree().physics_frame
	var covered := Vector2(car.global_position.x - start.x, car.global_position.z - start.z).length()
	await _free(car)
	await _free(left)
	await _free(right)
	return covered


func test_the_4x4s_locks_pull_it_away_with_one_side_on_slippery_ground() -> void:
	var open: CarStats = OFFROAD.stats.duplicate()
	open.front_diff_lock = 0.0
	open.rear_diff_lock = 0.0
	open.centre_diff_lock = 0.0
	var locked := await _split_surface_pull(OFFROAD.stats, 4.0)
	var unlocked := await _split_surface_pull(open, 4.0)
	gut.p("4 s from rest, left wheels on slick ground: locked %.1f m, open %.1f m" % [locked, unlocked])
	assert_gt(locked, unlocked * 1.15, "the locks clearly help")


func test_the_4x4_does_not_roll_over_at_full_lock() -> void:
	var ground := ScenarioHelper.make_flat_ground(DIRT)
	add_child(ground)
	var car: Car = CAR_SCENE.instantiate()
	car.stats = OFFROAD.stats
	car.position = Vector3(0.0, 1.2, 0.0)
	add_child(car)
	await wait_physics_frames(ScenarioHelper.ticks(1.0))
	var lowest_up := 1.0
	for tick in ScenarioHelper.ticks(12.0):
		var turning := car.forward_speed() * 3.6 >= 40.0 or tick > ScenarioHelper.ticks(8.0)
		car.input.virtual_steer = 1.0 if turning else 0.0
		car.input.virtual_throttle = 1.0 if car.forward_speed() * 3.6 < 40.0 else 0.0
		await get_tree().physics_frame
		if turning:
			lowest_up = minf(lowest_up, car.global_basis.y.y)
	gut.p("4x4 at full lock around 40 km/h on dirt: most tilt %.0f deg" % rad_to_deg(acos(clampf(lowest_up, -1.0, 1.0))))
	assert_true(ScenarioHelper.is_upright(car), "still on its wheels")
	assert_gt(lowest_up, 0.5, "never tipped past 60 degrees")
	await _free(car)
	await _free(ground)


func test_a_run_drives_the_car_chosen_in_car_select() -> void:
	var state := SaveSandbox.game_state()
	state.record_finish(state.catalog.levels[0], 60.0, {})
	state.set_selected_car(&"offroad_4x4")
	var level: RunLevel = RALLY_ROAD.instantiate()
	add_child_autofree(level)
	assert_eq(level.rig.car_def, OFFROAD)
	assert_eq(level.rig.car.stats, OFFROAD.stats)
	level.results.retry_pressed.emit()
	assert_eq(SaveSandbox.requested_scenes, [level.scene_file_path], "Retry reloads the level")
	assert_eq(state.selected_car(), OFFROAD, "with the same car")
	level.pause_menu.car_select_pressed.emit()
	assert_eq(SaveSandbox.requested_scenes[-1], state.CAR_SELECT, "Change car opens car select")
	assert_eq(state.pending_scene, level.scene_file_path, "for this level")
