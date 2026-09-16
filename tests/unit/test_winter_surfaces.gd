extends GutTest
## Approved winter surface values and feedback, including the quieter ice skid.


func test_winter_physics_and_mud_changes_match_the_spec() -> void:
	var checks: Array[Array] = [
		["res://surfaces/snow.tres", &"snow", 0.4, 0.04, 10.0, 0.03],
		["res://surfaces/ice.tres", &"ice", 0.15, 0.01, 0.0, 0.0],
		["res://surfaces/logs.tres", &"logs", 0.7, 0.03, 0.0, 0.0],
		["res://surfaces/mud.tres", &"mud", 0.6, 0.1, 40.0, 0.06],
		["res://levels/muddy_valley/soft_mud.tres", &"soft_mud", 0.7, 0.08, 25.0, 0.04],
	]
	for check: Array in checks:
		assert_true(ResourceLoader.exists(check[0]), check[0])
		if not ResourceLoader.exists(check[0]):
			continue
		var surface: SurfaceDef = load(check[0])
		assert_eq(surface.id, check[1])
		assert_almost_eq(surface.grip, check[2], 0.0001)
		assert_almost_eq(surface.rolling_resistance, check[3], 0.0001)
		assert_almost_eq(surface.drag, check[4], 0.0001)
		assert_almost_eq(surface.sink_depth, check[5], 0.0001)


func test_winter_grip_multipliers() -> void:
	var table: GripTable = load("res://surfaces/grip_table.tres")
	for check: Array in [[&"snow", 1.3], [&"ice", 1.05], [&"logs", 1.1]]:
		assert_almost_eq(table.multiplier(&"rally", check[0]), 1.0, 0.0001)
		assert_almost_eq(table.multiplier(&"offroad", check[0]), check[1], 0.0001)


func test_snow_rolls_and_sprays_while_ice_skids_at_half_volume() -> void:
	var table: SurfaceFeelTable = load("res://effects/surface_feel_table.tres")
	var snow: SurfaceFeel = table.feels.get(&"snow")
	var ice: SurfaceFeel = table.feels.get(&"ice")
	var logs: SurfaceFeel = table.feels.get(&"logs")
	assert_not_null(snow)
	assert_not_null(ice)
	assert_not_null(logs)
	if snow == null or ice == null or logs == null:
		return
	assert_eq(snow.spray, SurfaceFeel.SprayKind.DUST)
	assert_gt(snow.spray_color.r, 0.9)
	assert_false(snow.skids)
	assert_eq(ice.spray, SurfaceFeel.SprayKind.NONE)
	assert_eq(ice.rolling, SurfaceFeel.RollingSound.NONE)
	assert_eq(logs.spray, SurfaceFeel.SprayKind.NONE)
	assert_eq(logs.rolling, SurfaceFeel.RollingSound.GRAVEL)
	var wheel := {"feel": snow, "ground_speed": 25.0, "slip_speed": 12.0, "sliding": true}
	var snow_mix := TyreSoundLogic.mix([wheel])
	assert_almost_eq(float(snow_mix.get("snow", 0.0)), 0.25, 0.001)
	assert_eq(snow_mix["skid"], 0.0)
	wheel["feel"] = ice
	var ice_mix := TyreSoundLogic.mix([wheel])
	wheel["feel"] = table.feels[&"asphalt"]
	var asphalt_mix := TyreSoundLogic.mix([wheel])
	assert_almost_eq(ice_mix["skid"], asphalt_mix["skid"] * 0.5, 0.001)
