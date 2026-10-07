extends GutTest
## Approved additive tuning and opt-in road appearance; existing defaults stay exact.

const TRAIL := preload("res://levels/coastal_highway/coastal_highway_trail.tres")
const CURVE := preload("res://levels/coastal_highway/coastal_highway_curve.tres")
const GRIP := preload("res://surfaces/grip_table.tres")
const FEELS := preload("res://effects/surface_feel_table.tres")
const RECORDER := preload("res://tools/record_build_details.gd")
const OLD_GRIP := {
	"rally/asphalt": 1.1, "rally/dirt": 1.05, "rally/mud": 0.95,
	"offroad/asphalt": 0.95, "offroad/dirt": 1.1, "offroad/mud": 1.35,
	"rally/snow": 1.0, "rally/ice": 1.0, "rally/logs": 1.0,
	"offroad/snow": 1.3, "offroad/ice": 1.05, "offroad/logs": 1.1,
	"offroad/deep_mud": 1.35, "rally/deep_mud": 1.0,
	"offroad/rock": 1.05, "rally/rock": 1.0, "offroad/scree": 1.2,
	"rally/scree": 0.95, "offroad/wet_rock": 1.1, "rally/wet_rock": 1.0,
}


func test_new_values_and_grip_pairs_match_approval_without_retuning_existing_pairs() -> void:
	for row: Array in [["coastal_sand", 0.8, 0.045, 0.01, 1.05, 1.1],
			["soft_sand", 0.7, 0.07, 0.025, 1.05, 1.1], ["wet_asphalt", 0.9, 0.015, 0.0, 1.1, 0.95]]:
		var surface: SurfaceDef = load("res://surfaces/%s.tres" % row[0])
		assert_eq(String(surface.id), row[0])
		assert_eq(surface.grip, row[1])
		assert_eq(surface.rolling_resistance, row[2])
		assert_eq(surface.sink_depth, row[3])
		assert_eq(surface.drag, 0.0, "real water supplies drag, not these surfaces")
		assert_eq(GRIP.multiplier(&"rally", surface.id), row[4])
		assert_eq(GRIP.multiplier(&"offroad", surface.id), row[5])
	for key: String in OLD_GRIP:
		assert_eq(GRIP.multipliers[key], OLD_GRIP[key], key)
	assert_eq(GRIP.multipliers.size(), OLD_GRIP.size() + 6)


func test_feedback_is_dry_sand_dust_or_subdued_road_never_fake_water() -> void:
	for id: StringName in [&"coastal_sand", &"soft_sand"]:
		var feel: SurfaceFeel = FEELS.feels[id]
		assert_eq(feel.spray, SurfaceFeel.SprayKind.DUST)
		assert_eq(feel.rolling, SurfaceFeel.RollingSound.GRAVEL)
		assert_false(feel.skids)
	var wet: SurfaceFeel = FEELS.feels[&"wet_asphalt"]
	assert_eq(wet.spray, SurfaceFeel.SprayKind.NONE)
	assert_eq(wet.rolling, SurfaceFeel.RollingSound.ROAD)
	assert_true(wet.skids)
	assert_eq(wet.skid_volume, 0.65)


func test_blends_hide_lines_before_sand_tint_shoulders_and_preserve_physical_boundaries() -> void:
	var profile := RoadProfile.new(TRAIL, CURVE.get_baked_length())
	var builder := RoadBuilder.new()
	add_child_autofree(builder)
	var sampler := RoadSampler.new(CURVE, false, TRAIL)
	var rows := RoadBuilder.row_distances(sampler.length, profile, TRAIL)
	for stretch: SurfaceStretch in TRAIL.surface_stretches:
		assert_eq(stretch.surface.id, &"coastal_sand")
		assert_true(stretch.affects_shoulders)
		assert_eq(stretch.roughness, TRAIL.road_roughness, "no abrupt material seam or extra chunks")
		assert_true(rows.has(stretch.start))
		assert_true(rows.has(stretch.end()))
		assert_eq(profile.surface_at(stretch.start - 0.01).id, &"asphalt")
		assert_eq(profile.surface_at(stretch.start).id, &"coastal_sand")
		assert_eq(profile.surface_at(stretch.end() - 0.01).id, &"coastal_sand")
		assert_eq(profile.surface_at(stretch.end()).id, &"asphalt")
		assert_eq(profile.painted_line_weight(stretch.start - 8), 1.0)
		assert_eq(profile.painted_line_weight(stretch.start - 4), 0.5)
		assert_eq(profile.painted_line_weight(stretch.start), 0.0)
		assert_eq(profile.painted_line_weight(stretch.end()), 0.0)
		assert_eq(profile.painted_line_weight(stretch.end() + 4), 0.5)
		assert_eq(profile.painted_line_weight(stretch.end() + 8), 1.0)
		var middle := stretch.start + stretch.length * 0.5
		assert_eq(profile.surface_color(middle, TRAIL.asphalt_color), stretch.color)
		assert_eq(profile.surface_color(middle, TRAIL.shoulder_color, true), stretch.color * stretch.shoulder_tint)
		var line_lateral := TRAIL.road_width_at(middle) * 0.5 - TRAIL.line_inset
		assert_eq(builder._color(profile, TRAIL, middle, line_lateral, RoadBuilder.Part.LINE),
			builder._color(profile, TRAIL, middle, line_lateral, RoadBuilder.Part.ROAD), "no painted stripe inside sand")
		assert_eq(builder._color(profile, TRAIL, stretch.start - 8, line_lateral, RoadBuilder.Part.LINE), TRAIL.line_color)
		for boundary: float in [stretch.start, stretch.end()]:
			var left := profile.surface_color(boundary - 0.001, TRAIL.asphalt_color)
			var right := profile.surface_color(boundary + 0.001, TRAIL.asphalt_color)
			assert_lt(absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b), 0.001, "continuous color")
		for shoulder: bool in [false, true]:
			var base: Color = TRAIL.shoulder_color if shoulder else TRAIL.asphalt_color
			for at: float in [stretch.start - 8, stretch.start, middle, stretch.end(), stretch.end() + 8]:
				var before := profile.surface_color(at, base, shoulder)
				profile.cache_build_samples(true)
				assert_eq(profile.surface_color(at, base, shoulder), before)
				assert_eq(profile.surface_color(at, base, shoulder), before, "cached path")
				profile.cache_build_samples(false)
	var defaults := SurfaceStretch.new()
	defaults.surface = preload("res://surfaces/mud.tres")
	var legacy := TrailDef.new()
	legacy.surface_stretches = [defaults]
	var old_profile := RoadProfile.new(legacy, 100)
	assert_eq(defaults.shoulder_tint, Color.WHITE)
	assert_false(defaults.hide_painted_lines)
	assert_eq(old_profile.painted_line_weight(25), 1.0)
	assert_eq(defaults.color_for(true), defaults.color)


func test_small_damage_avoids_structures_and_never_adds_raised_asphalt_patches() -> void:
	var profile := RoadProfile.new(TRAIL, CURVE.get_baked_length())
	assert_true(profile.patches.is_empty())
	assert_between(profile.potholes.size(), 25, 50, "sparse damage on a three-km road")
	var off_centre := 0
	for hole: Vector4 in profile.potholes:
		assert_between(hole.z, 0.3, 0.8)
		assert_between(hole.w, 0.025, 0.08)
		if absf(hole.y) > hole.z:
			off_centre += 1
	assert_gt(off_centre, profile.potholes.size() / 2, "most holes miss the centre line")
	for at: float in [590, 610, 710, 730, 800, 815, 853, 871, 929, 990, 2045, 2054, 2074, 2085]:
		assert_eq(profile.local_undulation(at), 0.0)
		for lateral: float in [-3, -1, 0, 1, 3]:
			assert_eq(profile.rough_height(at, lateral) + profile.rut_height(at, lateral), 0.0)
	for stretch: SurfaceStretch in TRAIL.surface_stretches:
		assert_between(stretch.rut_depth, 0.02, 0.05)
		assert_eq(stretch.water_rut_depth, 0.0)


func test_serial_and_snapshot_colors_geometry_and_collisions_match_with_opt_ins() -> void:
	var trail := TrailDef.new()
	trail.terrain_blend_width = 3.0
	trail.surface_color_blend = 8.0
	var stretch: SurfaceStretch = TRAIL.surface_stretches[0].duplicate()
	stretch.start = 35.25
	stretch.length = 50.0
	trail.surface_stretches = [stretch]
	var damage := RoadDamageDef.new()
	damage.start = 5
	damage.length = 80
	damage.density = Vector2(5, 5)
	damage.depth_range = Vector2(0.025, 0.05)
	trail.damage_sections = [damage]
	var curve := Curve3D.new()
	curve.add_point(Vector3(0, 3, 0))
	curve.add_point(Vector3(0, 4, -120))
	var sampler := RoadSampler.new(curve, false, trail)
	var profile := RoadProfile.new(trail, sampler.length)
	var field := TerrainField.generate(sampler, trail, TerrainDef.new(), true, profile)
	for kind in 2:
		var expected: Array = []
		for threaded: bool in [false, true]:
			var builder: Node3D = RoadBuilder.new() if kind == 0 else RoadBlendBuilder.new()
			builder.set("threaded", threaded)
			add_child_autofree(builder)
			if kind == 0:
				(builder as RoadBuilder).build(sampler, profile, trail)
			else:
				(builder as RoadBlendBuilder).build(sampler, profile, field, trail)
			var data: Array = RECORDER.tree_data(builder)
			if not threaded:
				expected = data
			else:
				assert_eq(data, expected, "all arrays, colors, normals and hulls")
