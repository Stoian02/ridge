extends GutTest
## ScatterBuilder and CheckpointPlacer on a small generated trail.

var trail: TrailDef
var terrain: TerrainDef
var scatter: ScatterDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 15.0, -300.0))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.checkpoint_distances = PackedFloat32Array([200.0, 100.0, 400.0])
	terrain = TerrainDef.new()
	terrain.margin = 80.0
	terrain.chunk_size = 64.0
	scatter = ScatterDef.new()
	profile = RoadProfile.new(trail, sampler.length)
	field = TerrainField.generate(sampler, trail, terrain)


func test_scenery_keeps_clear_of_the_road() -> void:
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, profile, trail, scatter)
	assert_gt(builder.pine_count, 20)
	assert_gt(builder.rock_count, 5)
	for child in builder.get_children():
		if child is MultiMeshInstance3D and child.multimesh.mesh.get_faces().size() > 300:  # pines and rocks, not posts
			for i in child.multimesh.instance_count:
				var spot: Vector3 = child.multimesh.get_instance_transform(i).origin
				assert_gte(field.edge_distance_at(spot.x, spot.z), scatter.road_clearance - field.spacing)


func test_scenery_is_drawn_with_a_view_distance() -> void:
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, profile, trail, scatter)
	var instances := builder.get_children().filter(func(c: Node) -> bool: return c is MultiMeshInstance3D)
	assert_gt(instances.size(), 0)
	# Pines are added first.
	assert_almost_eq(instances[0].visibility_range_end, scatter.pine_view_distance, 0.001)


func test_zero_spacing_disables_a_kind_and_rebuild_clears_counts() -> void:
	var builder := ScatterBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, profile, trail, scatter)
	assert_gt(builder.pine_count, 0)
	assert_gt(builder.rock_count, 0)
	scatter.pine_spacing = 0.0
	scatter.rock_spacing = 0.0
	scatter.broadleaf_spacing = 0.0
	builder.build(field, sampler, profile, trail, scatter)
	assert_eq(builder.pine_count, 0)
	assert_eq(builder.rock_count, 0)
	assert_eq(builder.broadleaf_count, 0)
	assert_eq(builder.get_node("RockCollision").get_child_count(), 0)


func test_checkpoint_distances_add_start_and_finish_in_order() -> void:
	var distances := CheckpointPlacer.distances_for(sampler.length, trail)
	assert_eq(distances.size(), 4, "start, 100, 200, finish (400 is past the end)")
	assert_almost_eq(distances[0], trail.start_distance, 0.001, "the start leaves road behind the car")
	assert_almost_eq(distances[1], 100.0, 0.001)
	assert_almost_eq(distances[-1], sampler.length - trail.end_margin, 0.001, "the finish leaves road after it")


func test_gate_labels() -> void:
	assert_eq(CheckpointPlacer.label_for(0, 4), "START")
	assert_eq(CheckpointPlacer.label_for(2, 4), "CP 2")
	assert_eq(CheckpointPlacer.label_for(3, 4), "FINISH")


func test_reset_transforms_sit_above_the_road_facing_along_it() -> void:
	var placer := CheckpointPlacer.new()
	add_child_autofree(placer)
	placer.build(sampler, profile, trail)
	assert_eq(placer.reset_transforms.size(), 4)
	var reset := placer.reset_transforms[1]
	var road_surface := sampler.surface_point(100.0, 0.0, profile)
	assert_almost_eq(reset.origin.distance_to(road_surface), CheckpointPlacer.RESET_HEIGHT, 0.01)
	assert_gt((-reset.basis.z).dot(sampler.forward(100.0)), 0.999)


func test_gate_reports_a_body_entering_it() -> void:
	var placer := CheckpointPlacer.new()
	add_child_autofree(placer)
	placer.build(sampler, profile, trail)
	watch_signals(placer)
	var ball := RigidBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	ball.add_child(shape)
	ball.position = placer.reset_transforms[2].origin + Vector3(0.0, 1.0, 0.0)
	add_child_autofree(ball)
	await wait_physics_frames(10)
	assert_signal_emitted_with_parameters(placer, "gate_entered", [2, ball])


func test_gate_text_reads_correctly_from_an_approaching_car() -> void:
	var placer := CheckpointPlacer.new()
	add_child_autofree(placer)
	placer.build(sampler, profile, trail)
	for i in placer.gate_distances.size():
		var label: Label3D = placer.get_node("Gate%d" % i).find_children("*", "Label3D", false, false)[0]
		# A Label3D reads correctly from its +Z side. The car arrives from behind the gate,
		# driving along the road, so the label's +Z must point back against the road direction.
		assert_lt(label.global_basis.z.dot(sampler.forward(placer.gate_distances[i])), -0.999, "gate %d" % i)
