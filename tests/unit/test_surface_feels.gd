extends GutTest
## How each surface looks and sounds (spec §3), and the pure rules for spray,
## engine, tyres and impacts (spec §4.1, §5.2-5.4).

const FEELS := preload("res://effects/surface_feel_table.tres")
const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")
const DAMP_DIRT := preload("res://levels/muddy_valley/damp_dirt.tres")
const SOFT_MUD := preload("res://levels/muddy_valley/soft_mud.tres")


func _feel(surface: SurfaceDef) -> SurfaceFeel:
	return FEELS.feel_for(surface)


func test_every_shipped_surface_has_its_feel() -> void:
	assert_eq(_feel(ASPHALT).spray, SurfaceFeel.SprayKind.SMOKE)
	assert_eq(_feel(ASPHALT).rolling, SurfaceFeel.RollingSound.ROAD)
	assert_true(_feel(ASPHALT).skids, "tyres squeal on asphalt")
	for surface: SurfaceDef in [DIRT, DAMP_DIRT]:
		assert_eq(_feel(surface).spray, SurfaceFeel.SprayKind.DUST, surface.id)
		assert_eq(_feel(surface).rolling, SurfaceFeel.RollingSound.GRAVEL, surface.id)
		assert_false(_feel(surface).skids, surface.id)
	for surface: SurfaceDef in [MUD, SOFT_MUD]:
		assert_eq(_feel(surface).spray, SurfaceFeel.SprayKind.CLODS, surface.id)
		assert_eq(_feel(surface).rolling, SurfaceFeel.RollingSound.MUD, surface.id)


func test_an_unknown_surface_gets_the_fallback_and_the_air_gets_none() -> void:
	var gravel := SurfaceDef.new()
	gravel.id = &"gravel_pit"
	assert_eq(_feel(gravel), FEELS.fallback)
	assert_null(_feel(null))


func test_clods_grow_with_wheelspin_and_speed() -> void:
	var kind := SurfaceFeel.SprayKind.CLODS
	assert_eq(SprayLogic.intensity(kind, 0.0, 0.0, false), 0.0, "a still wheel throws nothing")
	assert_gt(SprayLogic.intensity(kind, 0.0, 3.0, false), 0.4, "wheelspin alone throws mud")
	assert_gt(SprayLogic.intensity(kind, 0.0, 6.0, false), SprayLogic.intensity(kind, 0.0, 3.0, false))
	assert_gt(SprayLogic.intensity(kind, 15.0, 0.0, false), 0.4, "speed alone throws some")
	assert_eq(SprayLogic.intensity(kind, 40.0, 40.0, true), 1.0, "capped at 1")


func test_dust_needs_speed_and_smoke_needs_a_slide() -> void:
	assert_eq(SprayLogic.intensity(SurfaceFeel.SprayKind.DUST, 2.0, 0.0, false), 0.0, "no dust at a walking pace")
	assert_gt(SprayLogic.intensity(SurfaceFeel.SprayKind.DUST, 15.0, 0.0, false),
			SprayLogic.intensity(SurfaceFeel.SprayKind.DUST, 8.0, 0.0, false))
	assert_eq(SprayLogic.intensity(SurfaceFeel.SprayKind.SMOKE, 20.0, 5.0, false), 0.0, "no smoke without a slide")
	assert_gt(SprayLogic.intensity(SurfaceFeel.SprayKind.SMOKE, 20.0, 5.0, true), 0.5)
	assert_eq(SprayLogic.intensity(SurfaceFeel.SprayKind.NONE, 20.0, 5.0, true), 0.0)


func test_engine_pitch_follows_rpm_and_the_layers_cross_fade() -> void:
	var idle := EngineSoundLogic.layers(900.0, 0.0, false)
	var high := EngineSoundLogic.layers(6000.0, 1.0, false)
	assert_gt(high["low_pitch"], idle["low_pitch"])
	assert_gt(high["high_pitch"], idle["high_pitch"])
	assert_gt(idle["low_volume"], 0.3, "the low layer carries idle")
	assert_almost_eq(idle["high_volume"], 0.0, 0.001)
	assert_almost_eq(high["low_volume"], 0.0, 0.001)
	assert_gt(high["high_volume"], 0.9, "the high layer carries a full-throttle redline")
	for key: String in ["low_pitch", "high_pitch"]:
		assert_between(EngineSoundLogic.layers(300.0, 0.0, false)[key], 0.5, 2.0)
		assert_between(EngineSoundLogic.layers(9000.0, 0.0, false)[key], 0.5, 2.0)


func test_throttle_makes_the_engine_louder_and_a_shift_dips_it() -> void:
	var off: float = EngineSoundLogic.layers(1500.0, 0.0, false)["low_volume"]
	var on: float = EngineSoundLogic.layers(1500.0, 1.0, false)["low_volume"]
	var shifting: float = EngineSoundLogic.layers(1500.0, 1.0, true)["low_volume"]
	assert_gt(on, off)
	assert_lt(shifting, on)


func _wheel(surface: SurfaceDef, ground_speed: float, slip_speed := 0.0, sliding := false) -> Dictionary:
	return {"feel": _feel(surface), "ground_speed": ground_speed, "slip_speed": slip_speed, "sliding": sliding}


func test_each_surface_feeds_its_own_rolling_sound() -> void:
	var dirt_mix := TyreSoundLogic.mix([_wheel(DIRT, 20.0), _wheel(DIRT, 20.0), _wheel(DIRT, 20.0), _wheel(DIRT, 20.0)])
	assert_gt(dirt_mix["gravel"], 0.7)
	assert_eq(dirt_mix["mud"], 0.0)
	assert_eq(dirt_mix["road"], 0.0)
	var mud_mix := TyreSoundLogic.mix([_wheel(MUD, 2.0, 6.0), _wheel(MUD, 2.0, 6.0)])
	assert_gt(mud_mix["mud"], 0.3, "wheelspin in mud squelches even when slow")
	var air: Array[Dictionary] = [{"feel": null, "ground_speed": 30.0, "slip_speed": 10.0, "sliding": true}]
	assert_eq(TyreSoundLogic.mix(air), {"road": 0.0, "gravel": 0.0, "mud": 0.0, "skid": 0.0})


func test_only_sliding_on_asphalt_squeals_and_totals_are_capped() -> void:
	assert_eq(TyreSoundLogic.mix([_wheel(ASPHALT, 20.0, 1.0, false)])["skid"], 0.0)
	assert_gt(TyreSoundLogic.mix([_wheel(ASPHALT, 20.0, 4.0, true)])["skid"], 0.1)
	assert_eq(TyreSoundLogic.mix([_wheel(DIRT, 20.0, 4.0, true)])["skid"], 0.0, "no squeal on dirt")
	var eight: Array[Dictionary] = []
	for i in 8:
		eight.append(_wheel(MUD, 40.0, 40.0, true))
	assert_eq(TyreSoundLogic.mix(eight)["mud"], 1.0)


func test_impacts_count_only_hard_hits_and_the_bump_stop() -> void:
	assert_eq(ImpactLogic.strength(0.5, false), 0.0, "an ordinary bump is silent")
	assert_gt(ImpactLogic.strength(3.0, false), ImpactLogic.strength(2.0, false))
	assert_eq(ImpactLogic.strength(10.0, false), 1.0)
	assert_gte(ImpactLogic.strength(0.0, true), 0.6, "bottoming out always thumps")
	assert_true(ImpactLogic.is_bottomed_out(0.32, 0.35))
	assert_false(ImpactLogic.is_bottomed_out(0.2, 0.35))


func test_wheel_motion_tells_rolling_from_spinning_and_sliding() -> void:
	var forward := Vector3(0.0, 0.0, -1.0)
	var rolling := WheelMotion.motion(true, Vector3(0.0, 0.0, -10.0), Vector3.UP, forward, 10.0, 0.0, 0.0)
	assert_almost_eq(rolling["ground_speed"], 10.0, 0.001)
	assert_almost_eq(rolling["slip_speed"], 0.0, 0.001)
	assert_false(rolling["sliding"])
	var spinning := WheelMotion.motion(true, Vector3.ZERO, Vector3.UP, forward, 8.0, 1.0, 0.0)
	assert_almost_eq(spinning["slip_speed"], 8.0, 0.001)
	assert_false(spinning["sliding"], "a burnout from rest isn't a slide")
	var sideways := WheelMotion.motion(true, Vector3(4.0, 0.0, -9.0), Vector3.UP, forward, 9.0, 0.0, deg_to_rad(20.0))
	assert_true(sideways["sliding"])
	var air := WheelMotion.motion(false, Vector3(0.0, 0.0, -10.0), Vector3.UP, forward, 10.0, 0.0, 0.0)
	assert_eq(air, {"in_contact": false, "ground_speed": 0.0, "slip_speed": 0.0, "sliding": false})
