extends GutTest

const ASPHALT := preload("res://surfaces/asphalt.tres")
const DIRT := preload("res://surfaces/dirt.tres")
const MUD := preload("res://surfaces/mud.tres")
const GRIP_TABLE := preload("res://surfaces/grip_table.tres")


func test_surface_files_have_ids() -> void:
	assert_eq(ASPHALT.id, &"asphalt")
	assert_eq(DIRT.id, &"dirt")
	assert_eq(MUD.id, &"mud")


func test_grip_order_is_asphalt_then_dirt_then_mud() -> void:
	assert_gt(ASPHALT.grip, DIRT.grip)
	assert_gt(DIRT.grip, MUD.grip)


func test_mud_sinks_and_resists_more_than_asphalt() -> void:
	assert_gt(MUD.sink_depth, ASPHALT.sink_depth)
	assert_gt(MUD.rolling_resistance, ASPHALT.rolling_resistance)
	assert_gt(MUD.drag, ASPHALT.drag)


func test_lookup_returns_tagged_surface() -> void:
	var body: StaticBody3D = autofree(StaticBody3D.new())
	body.set_meta(SurfaceLookup.META_KEY, MUD)
	assert_eq(SurfaceLookup.surface_of(body), MUD)


func test_lookup_falls_back_to_dirt_when_untagged() -> void:
	var body: StaticBody3D = autofree(StaticBody3D.new())
	assert_eq(SurfaceLookup.surface_of(body).id, &"dirt")


func test_lookup_falls_back_for_null_and_wrong_meta() -> void:
	assert_eq(SurfaceLookup.surface_of(null).id, &"dirt")
	var body: StaticBody3D = autofree(StaticBody3D.new())
	body.set_meta(SurfaceLookup.META_KEY, "not a surface")
	assert_eq(SurfaceLookup.surface_of(body).id, &"dirt")


func test_grip_table_lookup_and_default() -> void:
	assert_almost_eq(GRIP_TABLE.multiplier(&"rally", &"mud"), 1.1, 0.0001)
	assert_almost_eq(GRIP_TABLE.multiplier(&"unknown", &"mud"), 1.0, 0.0001)
