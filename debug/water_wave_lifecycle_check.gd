extends Node
## Opt-in real UI/scene lifecycle audit; no save mutation or timing-window work.
## Also exercised headlessly, but only rendered runs verify covered first use.

const GROUND := preload("res://levels/test_ground/test_ground.tscn")
const CAR_IDS: Array[String] = ["offroad_4x4", "rally", "rally_tuned"]
var checks: Array[Dictionary] = []
var rounds: Array[Dictionary] = []
var _label := ""


func run(output: String, repetitions: int = 3) -> bool:
	var base_nodes := get_tree().get_node_count()
	for repetition in repetitions:
		for car_id: String in CAR_IDS:
			_label = "%s_r%d" % [car_id, repetition]
			var level: Node3D = GROUND.instantiate()
			var rig: DrivingRig = level.get_node("DrivingRig")
			rig.car_override = GameState.car_catalog.find_by_id(StringName(car_id))
			add_child(level)
			rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
			rig.car.freeze = true
			var waves: WaterWaveTestGround = level.water_waves
			var world: WaterWorld = level.water_course.water_world
			var menu: PauseMenu = level.pause_menu
			var controls: WaterWaveTestControls = menu.level_options
			_check(waves.mode == 0 and waves.runtime == null, "new scene defaults Off without wave preparation")
			_check(world.wave_binding_count() == 0, "new scene has no stale bindings")
			rig.touch_controls.handle_touch(91, rig.touch_controls.gas_rect().get_center(), true)
			menu.open()
			_check(rig.touch_controls._touches.is_empty(), "pause releases held touch")
			_check(rig.car.input.virtual_throttle == 0.0, "pause releases throttle")
			await controls._choose(WaterWaveTestGround.Mode.FULL)
			_check(waves.mode == 2 and waves.error.is_empty(), "UI Full enable succeeds")
			_check(get_tree().paused and menu.is_open(), "mode preparation preserves menu pause")
			_check(not waves.busy and not menu.interaction_locked, "cover releases interaction lock")
			if repetition == 0 and car_id == "offroad_4x4" and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(output + "/pause_controls.png")
			_check(world.wave_binding_count() == 6, "exactly six wave bindings")
			_check(not level.water_course.get_node("CalmWater").visible, "flat top hidden under waves")
			var runtime := waves.runtime
			if runtime == null:
				menu.close()
				level.queue_free()
				await get_tree().process_frame
				continue
			var entry := {"case": _label, "cpu_preparation_usec": waves.preparation_usec,
				"covered_wait_usec": waves.covered_wait_usec, "tops": waves._tops.size()}
			var clock := runtime.field.clock_seconds
			var ambient: Variant = runtime.views[0].material.get_shader_parameter("wave_ambient")
			for frame in 8:
				await get_tree().process_frame
			_check(runtime.field.clock_seconds == clock, "pause freezes field clock")
			_check(runtime.views[0].material.get_shader_parameter("wave_ambient") == ambient,
				"pause freezes drawn snapshot")
			menu.close()
			await _ticks(8)
			_check(runtime.field.clock_seconds > clock, "resume advances field")
			runtime.field.queue_packet(WaterWaveField.Kind.ENTRY, &"test_calm", Vector2(0.0, 96.0), Vector2.ZERO, 0.08)
			await _ticks(3)
			_check(runtime.field.active_count() == 1, "reset test starts with a live disturbance")
			level._on_reset_requested()
			_check(runtime.field.active_count() == 0, "Reset clears live history")
			_check(not rig.car.water.state.stalled and rig.car.water.state.flooding == 0.0, "Reset clears water state")
			_check(rig.car.global_transform == level._spawn, "Reset keeps the authored spawn")
			menu.open()
			await controls._choose(WaterWaveTestGround.Mode.CAR_WAVES)
			_check(waves.runtime == runtime, "toggle reuses prepared runtime")
			_check(runtime.views[0].snapshot.ambient[0].z == 0.0, "Car waves removes ambient")
			await controls._choose(WaterWaveTestGround.Mode.OFF)
			_check(world.wave_binding_count() == 0, "Off detaches every sampler")
			_check(level.water_course.get_node("CalmWater").visible, "Off restores original top")
			_check(not runtime.is_physics_processing() and not waves.emitter.is_physics_processing(), "Off stops wave work")
			await controls._choose(WaterWaveTestGround.Mode.FULL)
			_check(waves.runtime == runtime and world.wave_binding_count() == 6, "re-enable has no duplicated resources")
			menu.close()
			level.water_course.build()
			await _ticks(3)
			_check(waves.mode == 0 and world.wave_binding_count() == 0, "world rebuild invalidates old binding safely")
			await controls._choose(WaterWaveTestGround.Mode.FULL)
			_check(waves.mode == 2 and world.wave_binding_count() == 6, "rebuilt world can enable again")
			var runtime_weak: WeakRef = weakref(waves.runtime)
			var emitter_weak: WeakRef = weakref(waves.emitter)
			remove_child(level)
			for player: AudioStreamPlayer in rig.audio.players.values():
				_check(not player.playing, "exit stops audio " + player.name)
			_check(world.wave_binding_count() == 0 and world.bodies.is_empty(), "exit unregisters world and samplers")
			level.free()
			await get_tree().process_frame
			await get_tree().process_frame
			_check(runtime_weak.get_ref() == null and emitter_weak.get_ref() == null, "exit frees runtime and emitter")
			entry["nodes_after_cleanup"] = get_tree().get_node_count()
			_check(get_tree().get_node_count() == base_nodes, "scene cycles do not accumulate nodes")
			rounds.append(entry)
			print("WAVE_LIFECYCLE round ", JSON.stringify(entry))
	# Stopped audio playbacks are released on the real-time mixer thread. Keep
	# this outside any timing window and do not mistake fast headless exit for
	# a gameplay audio leak or hitch fix.
	var audio_deadline := Time.get_ticks_msec() + 200
	while Time.get_ticks_msec() < audio_deadline:
		await get_tree().process_frame
	var passed := not checks.is_empty()
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	var file := FileAccess.open(output + "/lifecycle.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "rounds": rounds,
		"rendered": DisplayServer.get_name() != "headless", "baseline_nodes": base_nodes,
		"car_change_scope": "scene recreation with car_override; owner selection/save untouched"}, "\t"))
	file.close()
	print("WAVE_LIFECYCLE done passed=", passed, " checks=", checks.size(), " rounds=", rounds.size())
	return passed


func _check(value: bool, description: String) -> void:
	checks.append({"case": _label, "check": description, "passed": value})
	if not value:
		push_error("Wave lifecycle: " + _label + ": " + description)


func _ticks(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame
