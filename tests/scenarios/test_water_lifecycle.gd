extends GutTest
## Real level/rig bindings and reset/pause/car-change paths, not just pure state.

const GROUND := preload("res://levels/test_ground/test_ground.tscn")
const CANYON := preload("res://levels/rock_canyon/rock_canyon.tscn")
const RALLY := preload("res://car/cars/rally.tres")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	get_tree().paused = false
	SaveSandbox.leave()


func test_test_ground_reset_pause_and_car_change_do_not_keep_water_history() -> void:
	var spawn := Transform3D.IDENTITY
	for car_def: CarDef in [RALLY, OFFROAD]:
		var level: Node3D = GROUND.instantiate()
		var rig: DrivingRig = level.get_node("DrivingRig")
		rig.car_override = car_def
		add_child(level)
		rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
		spawn = level._spawn
		assert_same(rig.car.water.world, level.water_course.water_world)
		assert_eq(rig.car.water.state.flooding, 0.0)
		rig.place_car(Transform3D(Basis.IDENTITY, Vector3(105.0, 0.8, 126.0)))
		await wait_physics_frames(100)
		assert_gt(rig.car.water.state.body_immersion, 0.65)
		var before := rig.car.water.state.deep_seconds
		get_tree().paused = true
		for frame in 12:
			await get_tree().process_frame
		get_tree().paused = false
		assert_eq(rig.car.water.state.deep_seconds, before, "pause cannot flood the car off-screen")
		level._on_reset_requested()
		assert_eq(rig.car.global_transform, spawn, "normal Reset keeps the original spawn")
		assert_eq(rig.car.water.state.flooding, 0.0)
		assert_false(rig.car.water.state.stalled)
		assert_eq(rig.water_status.label.text, "")
		assert_false(rig.effects.water_effects.emitter.emitting)
		var old_world: WaterWorld = rig.car.water.world
		remove_child(level)
		level.free()
		assert_true(old_world.bodies.is_empty(), "scene exit unregisters the old water")
		await get_tree().process_frame


func test_run_restart_clears_water_but_keeps_the_ford_registered_once() -> void:
	var level: RunLevel = CANYON.instantiate()
	(level.get_node("DrivingRig") as DrivingRig).car_override = OFFROAD
	add_child_autofree(level)
	level.rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	var water := level.rig.car.water
	assert_same(water.world, level.trail.water_world)
	var count := water.world.bodies.size()
	assert_gt(count, 0)
	water.state.flooding = 0.8
	water.state.stalled = true
	water.state.deep_seconds = 12.0
	level.run.restart()
	assert_eq(water.state.flooding, 0.0)
	assert_eq(water.state.deep_seconds, 0.0)
	assert_false(water.state.stalled)
	assert_eq(water.world.bodies.size(), count)
	assert_same(water.world, level.trail.water_world)
