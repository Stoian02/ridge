extends GutTest
## Boulder fields (M5 spec §7): seeded layouts, on-road sizes, gate clearance,
## convex rock colliders, one MultiMesh per field and tilted slabs.

var trail: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var def: BoulderFieldDef
var builder: BoulderBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	trail.checkpoint_distances = PackedFloat32Array([150.0])
	def = BoulderFieldDef.new()
	def.start = 100.0
	def.length = 100.0
	def.count = 30
	def.seed = 5
	trail.boulder_fields = [def]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	builder = BoulderBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)


func test_the_same_seed_gives_the_same_layout_and_another_seed_differs() -> void:
	var again := BoulderBuilder.new()
	add_child_autofree(again)
	again.build(sampler, profile, field, trail)
	assert_eq(again.placed[0], builder.placed[0])
	def.seed = 6
	again.build(sampler, profile, field, trail)
	assert_ne(again.placed[0], builder.placed[0])
	assert_gt(builder.placed[0].size(), 20, "most of the 30 are placed (a few may sit on the gate)")


func test_boulders_on_the_road_keep_their_size_and_sides_alternate() -> void:
	var on_road := 0
	var left := 0
	var right := 0
	for i in builder.placed[0].size():
		var transform: Transform3D = builder.placed[0][i]
		var lateral := sampler.lateral_offset(transform.origin)
		if lateral < 0.0:
			left += 1
		else:
			right += 1
		if absf(lateral) <= trail.half_total_width() and not builder.slabs[0][i]:
			assert_between(transform.basis.get_scale().x, def.size_range.x, def.size_range.y, "on-road boulder %d" % i)
			on_road += 1
		elif absf(lateral) > trail.half_total_width() and not builder.slabs[0][i]:
			assert_between(transform.basis.get_scale().x, def.off_road_size_range.x, def.off_road_size_range.y, "off-road boulder %d" % i)
		assert_between(transform.origin.z, -200.0, -100.0, "inside the field")
	assert_gt(on_road, 3)
	assert_gt(left, 5)
	assert_gt(right, 5)


func test_no_boulder_sits_within_the_gate_clearance() -> void:
	for transform: Transform3D in builder.placed[0]:
		assert_gte(absf(sampler.closest_distance(transform.origin) - 150.0), BoulderBuilder.GATE_CLEARANCE - 0.05)


func test_each_boulder_has_a_convex_rock_collider_and_one_multimesh_per_field() -> void:
	var body: StaticBody3D = builder.get_node("Field0Collision")
	assert_eq(body.get_child_count(), builder.placed[0].size())
	assert_eq(SurfaceLookup.surface_of(body).id, &"rock")
	for shape in body.get_children():
		assert_true(shape.shape is ConvexPolygonShape3D)
	var instances := builder.get_children().filter(func(c: Node) -> bool: return c is MultiMeshInstance3D)
	assert_eq(instances.size(), 1)
	assert_eq(instances[0].multimesh.instance_count, builder.placed[0].size())
	await wait_physics_frames(2)
	var centre: Vector3 = builder.placed[0][0].origin
	var hit := builder.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(centre + Vector3.UP * 3.0, centre + Vector3.DOWN * 3.0))
	assert_false(hit.is_empty(), "a ray down through a boulder hits it")
	if not hit.is_empty():
		assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, &"rock")
		assert_gt(hit["position"].y, centre.y, "its top is above its centre")


func test_a_field_past_the_road_end_builds_without_errors() -> void:
	def.start = 280.0
	def.length = 70.0  # end() = 350, 50 m past the 300 m road
	builder.build(sampler, profile, field, trail)
	assert_gt(builder.placed[0].size(), 0, "some boulders still land before the road's end")
	for transform: Transform3D in builder.placed[0]:
		assert_lte(sampler.closest_distance(transform.origin), sampler.length - 1.0 + 0.01)


func test_slabs_are_tilted_across_the_road() -> void:
	def.slab_fraction = 1.0
	builder.build(sampler, profile, field, trail)
	assert_gt(builder.placed[0].size(), 20)
	for i in builder.placed[0].size():
		assert_true(builder.slabs[0][i])
		var transform: Transform3D = builder.placed[0][i]
		var up := transform.basis.y.normalized()
		assert_between(up.y, cos(deg_to_rad(BoulderBuilder.SLAB_TILT_DEG.y + 0.1)), cos(deg_to_rad(BoulderBuilder.SLAB_TILT_DEG.x - 0.1)), "slab %d tilt" % i)
		assert_lt(transform.basis.get_scale().y, transform.basis.get_scale().x, "flat")


func test_burial_lowers_visible_rocks_and_collision_together_without_reshuffling() -> void:
	var original: Array = builder.placed[0].duplicate()
	var body: StaticBody3D = builder.get_node("Field0Collision")
	var original_hull: PackedVector3Array = body.get_child(0).shape.points
	def.burial_depth = 0.23
	builder.build(sampler, profile, field, trail)
	assert_eq(builder.placed[0].size(), original.size())
	var buried_body: StaticBody3D = builder.get_node("Field0Collision")
	for i in original.size():
		var before: Transform3D = original[i]
		var after: Transform3D = builder.placed[0][i]
		assert_eq(after.basis, before.basis)
		assert_almost_eq(after.origin, before.origin - Vector3.UP * def.burial_depth, Vector3.ONE * 0.0001)
		assert_eq(buried_body.get_child(i).position, after.origin)
	var buried_hull: PackedVector3Array = buried_body.get_child(0).shape.points
	assert_eq(buried_hull, original_hull, "burial moves the complete hull, never scales only collision")
