extends GutTest
## TrailLevel assembles every builder from a Road curve and settings.

func _level() -> TrailLevel:
	var level := TrailLevel.new()
	level.trail = TrailDef.new()
	level.trail.checkpoint_distances = PackedFloat32Array([150.0])
	level.terrain = TerrainDef.new()
	level.terrain.margin = 60.0
	level.terrain.chunk_size = 64.0
	level.scatter = ScatterDef.new()
	var road := Path3D.new()
	road.name = "Road"
	road.curve = Curve3D.new()
	road.curve.bake_interval = 1.0
	road.curve.add_point(Vector3.ZERO)
	road.curve.add_point(Vector3(40.0, 10.0, -300.0))
	level.add_child(road)
	return level


func test_building_creates_every_part() -> void:
	var level := _level()
	add_child_autofree(level)  # builds in _ready
	for part in ["Generated/Road", "Generated/Shortcut", "Generated/Terrain", "Generated/Hedges",
			"Generated/Tunnels", "Generated/Bridges", "Generated/RockSteps", "Generated/Scatter", "Generated/Checkpoints"]:
		assert_not_null(level.get_node_or_null(part), part)
	assert_eq(level.checkpoints.reset_transforms.size(), 3)
	gut.p("small trail built in %.2f s" % level.build_seconds)


func test_start_transform_is_the_start_gate() -> void:
	var level := _level()
	add_child_autofree(level)
	assert_eq(level.start_transform(), level.checkpoints.reset_transforms[0])


func test_kill_height_is_below_all_terrain() -> void:
	var level := _level()
	add_child_autofree(level)
	assert_lt(level.kill_height(), level.field.lowest_height)


func test_rebuilding_replaces_the_generated_nodes_with_the_same_level() -> void:
	var level := _level()
	add_child_autofree(level)
	var first_heights := level.field.heights
	var first_gates := level.checkpoints.reset_transforms.duplicate()
	var first_counts := [level.scatter_builder.pine_count, level.scatter_builder.rock_count, level.scatter_builder.post_count]
	level.build()
	await wait_process_frames(1)
	assert_eq(level.get_children().filter(func(c: Node) -> bool: return c.name.begins_with("Generated")).size(), 1)
	assert_eq(level.field.heights, first_heights, "same settings, same terrain")
	assert_eq(level.checkpoints.reset_transforms, first_gates, "same checkpoint positions")
	assert_eq([level.scatter_builder.pine_count, level.scatter_builder.rock_count, level.scatter_builder.post_count],
			first_counts, "same scenery")
