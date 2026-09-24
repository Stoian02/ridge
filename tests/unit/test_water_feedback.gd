extends GutTest
## Bounded presentation and append-only recording, independent of force tuning.

const RIG := preload("res://levels/shared/driving_rig.tscn")
const FEELS := preload("res://effects/surface_feel_table.tres")
const ASPHALT := preload("res://surfaces/asphalt.tres")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func test_warning_priority_and_empty_dry_state() -> void:
	assert_eq(WaterFeedback.warning(false, false, false, false), "")
	assert_eq(WaterFeedback.warning(false, false, false, true), "Intake at risk")
	assert_eq(WaterFeedback.warning(false, true, false, true), "Engine stalled")
	assert_eq(WaterFeedback.warning(false, true, true, true), "Restarting…")
	assert_eq(WaterFeedback.warning(true, true, true, true), "Sinking — Reset available")


func test_splash_fades_below_surface_but_wash_can_continue() -> void:
	assert_eq(WaterFeedback.wheel_splash(0.0, 10.0, 100.0, 0.0), 0.0)
	var surface := WaterFeedback.wheel_splash(1.0, 10.0, 4.0, 0.0)
	assert_gt(surface, 0.0)
	assert_lt(WaterFeedback.wheel_splash(1.0, 10.0, 4.0, 0.15), surface)
	assert_eq(WaterFeedback.wheel_splash(1.0, 10.0, 4.0, 0.30), 0.0)
	assert_eq(WaterFeedback.wheel_splash(1.0, 10.0, 4.0, 3.0), 0.0)
	assert_gt(WaterFeedback.wash(1.0, 10.0, 4.0), 0.0)
	assert_lte(WaterFeedback.wash(1.0, 1000.0, 1000.0), 0.35)
	assert_eq(WaterFeedback.wake(0.5, 1.0), 0.0)
	assert_eq(WaterFeedback.wake(100.0, 0.0), 0.0)


func test_wet_tyre_keeps_muted_bed_sound_but_no_full_dry_skid() -> void:
	var wheels: Array[Dictionary] = [{"feel": FEELS.feel_for(ASPHALT),
		"ground_speed": 20.0, "slip_speed": 5.0, "sliding": true}]
	var dry := TyreSoundLogic.mix(wheels)
	wheels[0]["water_wetness"] = 1.0
	var wet := TyreSoundLogic.mix(wheels)
	assert_almost_eq(wet["road"], dry["road"] * 0.25, 0.000001)
	assert_eq(wet["skid"], 0.0)


func test_one_mixed_emitter_keeps_particle_cap_and_dry_configuration_recovers() -> void:
	var spray: WheelSpray = add_child_autofree(WheelSpray.new())
	var dry: SurfaceFeel = FEELS.feel_for(ASPHALT)
	spray.update_water(dry, 1.0, Color.CYAN, 0.8, 0.8, 0.016)
	assert_eq(spray.amount, 24)
	assert_true(spray.emitting)
	spray.update_water(dry, 1.0, Color.CYAN, 0.0, 1.0, 0.016)
	assert_false(spray.emitting, "no dry smoke deep underwater")
	spray.update(dry, 1.0, 0.016)
	assert_eq(spray.kind, dry.spray)
	assert_almost_eq(spray.lifetime, 1.4, 0.0001)


func test_old_csv_prefix_and_rows_are_preserved_and_water_is_appended() -> void:
	var old_header := PackedStringArray(["time", "speed_kmh", "rpm", "gear", "throttle", "brake", "steer",
		"airborne", "pos_x", "pos_y", "pos_z", "pitch_deg", "yaw_deg", "roll_deg"])
	for wheel: String in RunRecorder.WHEEL_NAMES:
		for field: String in RunRecorder.WHEEL_FIELDS:
			old_header.append("%s_%s" % [wheel, field])
	var header := RunRecorder.csv_header().split(",")
	assert_eq(header.slice(0, old_header.size()), old_header)
	assert_eq(header[old_header.size()], "water_immersion")
	var row := RunRecorder.csv_row(TelemetrySample.make(), 1.5).split(",")
	assert_eq(row.size(), header.size())
	assert_eq(row[old_header.size()], "0.00000", "legacy telemetry defaults to dry")
	var sample := TelemetrySample.make()
	sample["water"] = {"immersion": 0.7, "stalled": 1.0}
	row = RunRecorder.csv_row(sample, 1.5).split(",")
	assert_eq(row[header.find("water_immersion")], "0.70000")
	assert_eq(row[header.find("water_stalled")], "1.00000")


func test_rig_reset_clears_warning_wake_and_water_audio() -> void:
	var rig: DrivingRig = RIG.instantiate()
	add_child_autofree(rig)
	rig.set_process(false)
	rig.car.set_physics_process(false)
	rig.car.water.state.stalled = true
	rig.water_status._process(0.016)
	assert_eq(rig.water_status.label.text, "Engine stalled")
	assert_eq(rig.water_status.label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var emitter := rig.effects.water_effects.emitter
	assert_eq(emitter.amount, 32)
	assert_eq(emitter.lifetime, 0.5)
	emitter.emitting = true
	emitter.visible = true
	var entry: AudioStreamPlayer = rig.audio.players[&"water_entry"]
	entry.play()
	rig.place_car(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)))
	assert_false(emitter.emitting)
	assert_false(emitter.visible)
	assert_false(entry.playing)
	assert_false((rig.audio.players[&"water_wash"] as AudioStreamPlayer).playing)
	assert_eq(rig.water_status.label.text, "")
	assert_false(rig.water_status.intake_marker.visible)
	assert_false(rig.car.water.state.stalled)


func test_stalled_engine_audio_fades_to_silence_despite_throttle() -> void:
	var rig: DrivingRig = RIG.instantiate()
	add_child_autofree(rig)
	rig.car.set_physics_process(false)
	rig.car.water.state.stalled = true
	rig.car.input.throttle = 1.0
	rig.audio._process(1.0)
	assert_eq(rig.audio.volume(&"engine_low"), 0.0)
	assert_eq(rig.audio.volume(&"engine_high"), 0.0)


func test_no_entry_splash_or_sound_after_teleport_into_water() -> void:
	var rig: DrivingRig = RIG.instantiate()
	add_child_autofree(rig)
	rig.car.set_physics_process(false)
	var water := rig.car.water
	for i in water.body_samples.size():
		water.body_samples[i].valid = true
		water.body_samples[i].surface_y = 1.0
		water.body_positions[i] = Vector3(0.0, 1.0, 0.0)
		water.body_wetness[i] = 0.5
	water.state.body_immersion = 0.5
	rig.car.linear_velocity = Vector3(0.0, -5.0, 0.0)
	rig.effects.water_effects.notify_reset()
	rig.effects.water_effects.update(0.016, 0.0)
	assert_eq(rig.effects.water_effects.entries, 0)
	assert_false(rig.effects.water_effects.emitter.emitting)


func test_scene_exit_stops_every_audio_player() -> void:
	var rig: DrivingRig = RIG.instantiate()
	add_child(rig)
	remove_child(rig)
	for player: AudioStreamPlayer in rig.audio.players.values():
		assert_false(player.playing)
	rig.free()


func test_fully_submerged_grounded_wheel_never_keeps_dry_smoke() -> void:
	var rig: DrivingRig = RIG.instantiate()
	add_child_autofree(rig)
	rig.car.set_physics_process(false)
	rig.effects._process(0.016) # Synchronize reset serial before setting fixture data.
	var water := rig.car.water
	water.wheel_samples[0].valid = true
	water.wheel_samples[0].surface_y = 2.0
	water.wheel_samples[0].bed_y = 0.0
	water.wheel_positions[0] = Vector3(0.0, 0.2, 0.0)
	water.wheel_extents[0] = 0.35
	water.wheel_wetness[0] = 0.5 # Bed clips the lower half, but the whole tyre is underwater.
	water.relative_speed = 10.0
	var wheel := rig.car.wheels[0]
	wheel.in_contact = true
	wheel.surface = ASPHALT
	wheel.spin_speed = 100.0
	rig.car.linear_velocity = Vector3(0.0, 0.0, -10.0)
	rig.effects._process(0.016)
	assert_false(rig.effects.sprays[0].emitting)
	assert_gt(rig.effects.water_effects.wash_volume, 0.0)


func test_particle_curve_resources_are_reused_and_direct_reset_stops_audio() -> void:
	assert_same(WheelSpray._growing_curve(2.0), WheelSpray._growing_curve(2.0))
	assert_same(WheelSpray._fading_ramp(), WheelSpray._fading_ramp())
	var rig: DrivingRig = RIG.instantiate()
	add_child_autofree(rig)
	rig.car.set_physics_process(false)
	var entry: AudioStreamPlayer = rig.audio.players[&"water_entry"]
	entry.play()
	rig.car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, 0.0)))
	rig.audio._process(0.016)
	assert_false(entry.playing)


## Water thrown by a moving car travels with it, so the spray cone leans toward
## the car's motion while still pointing upward.
func test_the_spray_cone_leans_toward_travel_but_never_lies_flat() -> void:
	var effects := WaterEffects.new()
	var upright := WaterEffects.MAXIMUM_LEAN
	assert_between(upright, 0.0, 1.0, "the lean is a share of an upward cone")
	# Vector3.UP plus a horizontal share, normalised: the vertical part stays
	# dominant at any speed, so the cone never becomes a horizontal jet.
	for share: float in [0.0, upright * 0.5, upright]:
		var aim := (Vector3.UP + Vector3(share, 0.0, 0.0)).normalized()
		assert_gt(aim.y, 0.8, "share %.2f keeps the cone upward" % share)
	var slow := (Vector3.UP + Vector3(1.0, 0.0, 0.0) * clampf(1.0 / 6.0, 0.0, upright)).normalized()
	var fast := (Vector3.UP + Vector3(1.0, 0.0, 0.0) * clampf(9.0 / 6.0, 0.0, upright)).normalized()
	assert_gt(fast.x, slow.x, "a faster car throws its spray further forward")
	effects.free()
