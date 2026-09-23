extends GutTest
## Captured from unchanged builders at 9d21b78, before the build-speed refactor.
## Protects meshes/colours/normals, collision hulls and strata not covered by
## test_geometry_fingerprints.gd. Never refresh these to hide refactor drift.

const RECORDER := preload("res://tools/record_build_details.gd")
const EXPECTED := {
	"rally_road": {"joins": 629536886, "shelf": 629536886, "terrain": 971242508, "strata": 873697370},
	"muddy_valley": {"joins": 629536886, "shelf": 629536886, "terrain": 284567941, "strata": 873697370},
	"frozen_pass": {"joins": 629536886, "shelf": 629536886, "terrain": 670577213, "strata": 873697370},
	"rock_canyon": {"joins": 96751995, "shelf": 2451838484, "terrain": 1316812257, "strata": 2238006750},
}


func test_joins_shelf_and_terrain_appearance_match_pre_refactor() -> void:
	for id: String in EXPECTED:
		var actual: Dictionary = RECORDER.fingerprint(self, id)
		for part: String in EXPECTED[id]:
			assert_eq(actual[part], EXPECTED[id][part], "%s %s" % [id, part])


func test_threaded_joins_match_serial_including_rebuild() -> void:
	var trail: TrailDef = load("res://levels/rock_canyon/rock_canyon_trail.tres")
	var terrain: TerrainDef = load("res://levels/rock_canyon/rock_canyon_terrain.tres")
	var curve: Curve3D = load("res://levels/rock_canyon/rock_canyon_curve.tres")
	var sampler := RoadSampler.new(curve, true, trail)
	var profile := RoadProfile.new(trail, sampler.length)
	var field := TerrainField.generate(sampler, trail, terrain, true, profile)
	var serial := RoadBlendBuilder.new()
	var parallel := RoadBlendBuilder.new()
	add_child_autofree(serial)
	add_child_autofree(parallel)
	serial.threaded = false
	serial.build(sampler, profile, field, trail)
	var expected: Array = RECORDER.tree_data(serial)
	for repeat in 2:
		parallel.build(sampler, profile, field, trail)
		assert_eq(RECORDER.tree_data(parallel), expected, "complete arrays and hulls in original order")


func test_cached_build_keeps_exact_boulder_and_loose_stone_placement() -> void:
	var scene: PackedScene = load("res://levels/rock_canyon/rock_canyon.tscn")
	var root := scene.instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	add_child_autofree(trail)
	var curve: Curve3D = trail.get_node("Road").curve
	var sampler := RoadSampler.new(curve, trail.trail.use_curve_banking, trail.trail)
	var profile := RoadProfile.new(trail.trail, sampler.length)
	var reference_boulders := BoulderBuilder.new()
	var reference_stones := TalusBuilder.new()
	# TalusBuilder calls force_update_transform, so it requires a live tree.
	# No awaits: compare and free both references before a physics frame runs.
	add_child(reference_boulders)
	add_child(reference_stones)
	reference_boulders.build(sampler, profile, trail.field, trail.trail)
	reference_stones.build(sampler, profile, trail.field, trail.trail, reference_boulders)
	assert_eq(trail.boulder_builder.placed, reference_boulders.placed)
	assert_eq(trail.talus_builder._rest_transforms, reference_stones._rest_transforms)
	assert_eq(trail.talus_builder._scales, reference_stones._scales)
	assert_eq(trail.talus_builder.stones.size(), reference_stones.stones.size())
	for i in reference_stones.stones.size():
		var actual := trail.talus_builder.stones[i]
		var expected := reference_stones.stones[i]
		assert_eq(actual.mass, expected.mass)
		assert_eq(actual.get_child(0).shape.points, expected.get_child(0).shape.points)
	assert_false(trail.sampler._building)
	assert_false(trail.profile._building)
	reference_stones.free()
	reference_boulders.free()
