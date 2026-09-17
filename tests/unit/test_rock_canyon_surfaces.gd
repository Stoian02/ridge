extends GutTest
## The four Rock Canyon surfaces (M5 spec §4, §12): physics values, grip
## multipliers, feels, the splash spray and the rock and waterfall sounds.

const FEELS := preload("res://effects/surface_feel_table.tres")


func test_surface_values_match_the_spec() -> void:
	var checks: Array[Array] = [
		["res://surfaces/deep_mud.tres", &"deep_mud", 0.5, 0.14, 70.0, 0.15],
		["res://surfaces/rock.tres", &"rock", 1.05, 0.03, 0.0, 0.0],
		["res://surfaces/scree.tres", &"scree", 0.55, 0.09, 5.0, 0.04],
		["res://surfaces/wet_rock.tres", &"wet_rock", 0.5, 0.05, 20.0, 0.02],
	]
	for check: Array in checks:
		assert_true(ResourceLoader.exists(check[0]), check[0])
		if not ResourceLoader.exists(check[0]):
			continue
		var surface: SurfaceDef = load(check[0])
		assert_eq(surface.id, check[1])
		assert_almost_eq(surface.grip, check[2], 0.0001, "%s grip" % check[1])
		assert_almost_eq(surface.rolling_resistance, check[3], 0.0001, "%s rolling resistance" % check[1])
		assert_almost_eq(surface.drag, check[4], 0.0001, "%s drag" % check[1])
		assert_almost_eq(surface.sink_depth, check[5], 0.0001, "%s sink" % check[1])


func test_grip_multipliers_for_both_archetypes() -> void:
	var table: GripTable = load("res://surfaces/grip_table.tres")
	for check: Array in [[&"deep_mud", 1.35, 1.0], [&"rock", 1.05, 1.0], [&"scree", 1.2, 0.95], [&"wet_rock", 1.1, 1.0]]:
		assert_almost_eq(table.multiplier(&"offroad", check[0]), check[1], 0.0001, "offroad/%s" % check[0])
		assert_almost_eq(table.multiplier(&"rally", check[0]), check[2], 0.0001, "rally/%s" % check[0])
	assert_almost_eq(table.multiplier(&"offroad", &"mud"), 1.35, 0.0001, "existing entries untouched")
	assert_almost_eq(table.multiplier(&"rally", &"asphalt"), 1.1, 0.0001)


func test_each_new_surface_has_its_feel() -> void:
	var deep_mud: SurfaceFeel = FEELS.feels.get(&"deep_mud")
	var rock: SurfaceFeel = FEELS.feels.get(&"rock")
	var scree: SurfaceFeel = FEELS.feels.get(&"scree")
	var wet_rock: SurfaceFeel = FEELS.feels.get(&"wet_rock")
	for feel: SurfaceFeel in [deep_mud, rock, scree, wet_rock]:
		assert_not_null(feel)
	if deep_mud == null or rock == null or scree == null or wet_rock == null:
		return
	assert_eq(deep_mud.spray, SurfaceFeel.SprayKind.CLODS)
	assert_eq(deep_mud.rolling, SurfaceFeel.RollingSound.MUD)
	assert_false(deep_mud.skids)
	assert_eq(rock.spray, SurfaceFeel.SprayKind.NONE)
	assert_eq(rock.rolling, SurfaceFeel.RollingSound.ROCK)
	assert_true(rock.skids)
	assert_almost_eq(rock.skid_volume, 0.7, 0.0001)
	assert_eq(scree.spray, SurfaceFeel.SprayKind.DUST)
	assert_eq(scree.rolling, SurfaceFeel.RollingSound.GRAVEL)
	assert_true(scree.skids)
	assert_almost_eq(scree.skid_volume, 0.6, 0.0001)
	assert_true(scree.spray_color.is_equal_approx(Color(0.66, 0.5, 0.4)))
	assert_eq(wet_rock.spray, SurfaceFeel.SprayKind.SPLASH)
	assert_eq(wet_rock.rolling, SurfaceFeel.RollingSound.ROCK)
	assert_true(wet_rock.skids)
	assert_almost_eq(wet_rock.skid_volume, 0.5, 0.0001)


func test_rock_rolls_its_own_loop_quieter_than_gravel_at_speed() -> void:
	var wheel := {"feel": FEELS.feels[&"rock"], "ground_speed": 25.0, "slip_speed": 0.0, "sliding": false}
	var rock_mix := TyreSoundLogic.mix([wheel, wheel, wheel, wheel])
	assert_almost_eq(rock_mix["rock"], TyreSoundLogic.ROCK_MAX, 0.001)
	assert_eq(rock_mix["gravel"], 0.0)
	assert_eq(rock_mix["road"], 0.0)
	wheel["feel"] = FEELS.feels[&"dirt"]
	var gravel_mix := TyreSoundLogic.mix([wheel, wheel, wheel, wheel])
	assert_lt(rock_mix["rock"], gravel_mix["gravel"], "the level is slow, so rock stays under gravel")
	assert_eq(gravel_mix["rock"], 0.0)


func test_splash_needs_a_little_speed_and_grows_with_wheelspin() -> void:
	var kind := SurfaceFeel.SprayKind.SPLASH
	assert_eq(SprayLogic.intensity(kind, 0.5, 0.0, false), 0.0, "a creeping wheel throws no water")
	assert_gt(SprayLogic.intensity(kind, 8.0, 0.0, false), 0.5)
	assert_gt(SprayLogic.intensity(kind, 8.0, 4.0, false), SprayLogic.intensity(kind, 8.0, 0.0, false))
	assert_eq(SprayLogic.intensity(kind, 40.0, 40.0, true), 1.0, "capped at 1")


func test_a_wheel_spray_configures_itself_for_splash() -> void:
	var spray := WheelSpray.new()
	add_child_autofree(spray)
	spray.update(FEELS.feels[&"wet_rock"], 1.0, 0.016)
	assert_eq(spray.kind, SurfaceFeel.SprayKind.SPLASH)
	assert_true(spray.emitting)
	assert_gt(spray.initial_velocity_max, 6.0, "a wide, fast sheet")
	assert_true(spray.color.is_equal_approx(Color(FEELS.feels[&"wet_rock"].spray_color, WheelSpray.MAX_ALPHA)))


func test_the_new_sounds_loop_and_the_car_plays_rock() -> void:
	for sound_name: StringName in [&"rock", &"waterfall"]:
		assert_true(SoundSynth.NAMES.has(sound_name), sound_name)
		var wav := SoundSynth.sound(sound_name)
		assert_not_null(wav, sound_name)
		assert_eq(wav.loop_mode, AudioStreamWAV.LOOP_FORWARD, sound_name)
	assert_almost_eq(SoundSynth.sound(&"rock").get_length(), 1.3, 0.01)
	assert_almost_eq(SoundSynth.sound(&"waterfall").get_length(), 3.0, 0.01)
	assert_true(CarAudio.LOOPS.has(&"rock"))
