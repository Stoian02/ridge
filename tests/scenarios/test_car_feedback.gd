extends GutTest
## Spray and sound driven by a real car on the Test Ground (M3B spec §9.2): clods
## and squelch on mud, dust and gravel on dirt, road sound when cruising on asphalt
## with no smoke, smoke and a squeal when sliding there, the engine pitch rising
## with rpm, and a thump for a hard landing but not for a reset.

const TEST_GROUND := preload("res://levels/test_ground/test_ground.tscn")
const RALLY := preload("res://car/cars/rally.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func _ground() -> Node3D:
	var ground: Node3D = TEST_GROUND.instantiate()
	(ground.get_node("DrivingRig") as DrivingRig).car_override = RALLY
	add_child_autofree(ground)
	var rig: DrivingRig = ground.get_node("DrivingRig")
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return ground


func _rig(ground: Node3D) -> DrivingRig:
	return ground.get_node("DrivingRig")


## Puts the car at rest facing -Z at `position` and lets it settle.
func _place(rig: DrivingRig, position: Vector3) -> void:
	rig.place_car(Transform3D(Basis(), position))
	for i in ScenarioHelper.ticks(1.0):
		rig.car.input.virtual_throttle = 0.0
		await get_tree().physics_frame


## Drives for `seconds` with the given inputs; returns the most any spray showed of
## `kind` (emitting sprays only) and the loudest each loop got.
func _drive(rig: DrivingRig, seconds: float, throttle: float, steer: float, kind: SurfaceFeel.SprayKind) -> Dictionary:
	var result := {"sprays": 0, "loudest": {}}
	for sound_name in CarAudio.LOOPS:
		result["loudest"][sound_name] = 0.0
	for tick in ScenarioHelper.ticks(seconds):
		rig.car.input.virtual_throttle = throttle
		rig.car.input.virtual_steer = steer
		await get_tree().physics_frame
		var spraying := rig.effects.sprays.filter(func(s: WheelSpray) -> bool: return s.emitting and s.kind == kind).size()
		result["sprays"] = maxi(result["sprays"], spraying)
		for sound_name in CarAudio.LOOPS:
			result["loudest"][sound_name] = maxf(result["loudest"][sound_name], rig.audio.volume(sound_name))
	return result


func test_mud_throws_clods_and_squelches() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(30.0, 0.8, -20.0))
	var run := await _drive(rig, 3.0, 1.0, 0.0, SurfaceFeel.SprayKind.CLODS)
	gut.p("mud: %d wheels throwing clods, loudest %s" % [run["sprays"], run["loudest"]])
	assert_gte(run["sprays"], 2, "the driven wheels throw mud")
	assert_gt(run["loudest"][&"mud"], 0.2)
	assert_eq(run["loudest"][&"skid"], 0.0)


func test_dirt_throws_dust_and_crunches() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(-120.0, 0.8, 0.0))
	var run := await _drive(rig, 5.0, 1.0, 0.0, SurfaceFeel.SprayKind.DUST)
	gut.p("dirt: %d wheels throwing dust, loudest %s" % [run["sprays"], run["loudest"]])
	assert_eq(run["sprays"], 4)
	assert_gt(run["loudest"][&"gravel"], 0.3)
	assert_eq(run["loudest"][&"mud"], 0.0)


func test_asphalt_is_quiet_cruising_and_smokes_and_squeals_sliding() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(0.0, 0.8, -5.0))
	# Get up to speed first: a full-throttle launch may puff a little smoke.
	await _drive(rig, 3.5, 1.0, 0.0, SurfaceFeel.SprayKind.SMOKE)
	var cruise := {"sprays": 0, "loudest": {}}
	for sound_name in CarAudio.LOOPS:
		cruise["loudest"][sound_name] = 0.0
	for tick in ScenarioHelper.ticks(2.0):
		TrailScenarios.drive_toward(rig.car, rig.car.global_position + Vector3(0.0, 0.0, -50.0), 16.0)
		await get_tree().physics_frame
		var smoking := rig.effects.sprays.filter(func(s: WheelSpray) -> bool:
				return s.emitting and s.kind == SurfaceFeel.SprayKind.SMOKE).size()
		cruise["sprays"] = maxi(cruise["sprays"], smoking)
		for sound_name in CarAudio.LOOPS:
			cruise["loudest"][sound_name] = maxf(cruise["loudest"][sound_name], rig.audio.volume(sound_name))
	gut.p("asphalt straight at %.0f km/h: %d smoking, loudest %s" % [rig.car.forward_speed() * 3.6, cruise["sprays"],
			cruise["loudest"]])
	assert_eq(cruise["sprays"], 0, "no smoke driving straight")
	assert_gt(cruise["loudest"][&"road"], 0.1)
	assert_eq(cruise["loudest"][&"skid"], 0.0)
	var slide := await _drive(rig, 1.5, 1.0, 1.0, SurfaceFeel.SprayKind.SMOKE)
	gut.p("asphalt at full lock: %d smoking, loudest skid %.2f" % [slide["sprays"], slide["loudest"][&"skid"]])
	assert_gte(slide["sprays"], 1, "sliding tyres smoke")
	assert_gt(slide["loudest"][&"skid"], 0.05)


func test_the_engine_pitch_rises_with_rpm() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(-120.0, 0.8, 0.0))
	await get_tree().process_frame
	var idle_pitch: float = rig.audio.players[&"engine_low"].pitch_scale
	var idle_rpm := rig.car.drivetrain.rpm
	var highest_pitch := 0.0
	var highest_rpm := 0.0
	for tick in ScenarioHelper.ticks(4.0):
		rig.car.input.virtual_throttle = 1.0
		await get_tree().physics_frame
		if rig.car.drivetrain.rpm > highest_rpm:
			highest_rpm = rig.car.drivetrain.rpm
			highest_pitch = rig.audio.players[&"engine_high"].pitch_scale
	gut.p("engine: idle %.0f rpm pitch %.2f, top %.0f rpm high-layer pitch %.2f" % [idle_rpm, idle_pitch, highest_rpm,
			highest_pitch])
	assert_gt(highest_rpm, idle_rpm + 2000.0)
	assert_gt(highest_pitch, EngineSoundLogic.layers(idle_rpm, 0.0, false)["high_pitch"] * 1.5)
	assert_gt(rig.audio.volume(&"engine_high"), 0.5, "the high layer carries full throttle")


func test_a_hard_landing_thumps_but_a_reset_does_not() -> void:
	var rig := _rig(_ground())
	await _place(rig, Vector3(-120.0, 0.8, 0.0))
	await wait_seconds(0.6)
	var before := rig.audio.thumps_played
	rig.place_car(Transform3D(Basis(), Vector3(-120.0, 0.8, 0.0)))
	await wait_physics_frames(ScenarioHelper.ticks(0.4))
	assert_eq(rig.audio.thumps_played, before, "a reset puts the car down silently")
	await wait_seconds(0.6)
	before = rig.audio.thumps_played
	rig.car.reset_to(Transform3D(Basis(), Vector3(-120.0, 3.0, 0.0)))
	await wait_physics_frames(ScenarioHelper.ticks(1.5))
	gut.p("thumps from a 2.5 m drop: %d" % (rig.audio.thumps_played - before))
	assert_gt(rig.audio.thumps_played, before, "dropping from 2.5 m thumps")
