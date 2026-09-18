extends GutTest
## The talus field (M5 spec §8): the right count of stones, all asleep on build,
## each a rigid body with a convex hull, drawn from one MultiMesh that follows
## the stones that wake.

var trail: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var def: TalusDef
var builder: TalusBuilder


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -300.0))
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	trail.painted_lines = false
	def = TalusDef.new()
	def.start = 100.0
	def.length = 60.0
	def.count = 12
	def.seed = 3
	trail.talus = [def]
	sampler = RoadSampler.new(curve, true, trail)
	profile = RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 40.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	builder = TalusBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)


func test_the_right_count_all_asleep_with_convex_hulls_and_matching_instances() -> void:
	assert_eq(builder.stones.size(), 12)
	for stone in builder.stones:
		assert_true(stone.sleeping, stone.name)
		assert_between(stone.mass, def.mass_range.x, def.mass_range.y)
		assert_true(stone.get_child(0).shape is ConvexPolygonShape3D)
		assert_eq(SurfaceLookup.surface_of(stone).id, &"rock")
		assert_between(stone.position.z, -160.0, -100.0, "inside the field")
		assert_lte(absf(stone.position.x), def.lateral_range.y + 0.01)
		assert_almost_eq(stone.physics_material_override.friction, TalusBuilder.FRICTION, 0.0001)
		assert_almost_eq(stone.physics_material_override.bounce, TalusBuilder.BOUNCE, 0.0001)
	await wait_physics_frames(3)
	assert_eq(builder.awake_count(), 0, "untouched stones stay asleep")
	var instance: MultiMeshInstance3D = builder.get_node("Talus0")
	assert_eq(instance.multimesh.instance_count, 12)
	# get_instance_transform() is not reliable in headless Godot, so the
	# comparison reads through the TalusBuilder.instance_transforms test seam,
	# which mirrors exactly what was last written into the MultiMesh instance.
	assert_almost_eq(builder.instance_transforms[0].origin.distance_to(builder.stones[0].position), 0.0, 0.001)


func test_the_same_seed_gives_the_same_field() -> void:
	var again := TalusBuilder.new()
	add_child_autofree(again)
	again.build(sampler, profile, field, trail)
	for i in builder.stones.size():
		assert_almost_eq(again.stones[i].position.distance_to(builder.stones[i].position), 0.0, 0.0001)


func test_a_pushed_stone_wakes_and_its_instance_follows_it() -> void:
	var stone := builder.stones[0]
	# get_instance_transform() is not reliable in headless Godot, so this reads
	# through the TalusBuilder.instance_transforms test seam instead, which
	# mirrors exactly what was last written into the MultiMesh instance.
	var before := builder.instance_transforms[0].origin
	stone.apply_central_impulse(Vector3(0.0, 0.0, -stone.mass * 3.0))
	await wait_physics_frames(2)
	assert_gt(builder.awake_count(), 0, "the impulse woke it")
	await wait_physics_frames(30)
	await wait_process_frames(1)
	var after := builder.instance_transforms[0].origin
	assert_gt(before.distance_to(after), 0.2, "the drawn stone moved with the body")
	assert_almost_eq(after.distance_to(stone.global_position), 0.0, 0.01)
