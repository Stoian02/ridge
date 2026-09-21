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


func after_each() -> void:
	get_tree().paused = false


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


## The activation window is what keeps the cost of a long loose field flat: on
## the phone, 485 stones awake at once cost 58 ms a frame, and 132 cost 2.5 ms.
func test_the_activation_window_freezes_stones_away_from_the_camera() -> void:
	def.active_distance = 30.0
	builder.build(sampler, profile, field, trail)
	var camera := Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(0.0, 2.0, -105.0)
	camera.make_current()
	await wait_physics_frames(TalusBuilder.WINDOW_FRAMES + 2)
	var frozen := 0
	for stone in builder.stones:
		var near := stone.global_position.distance_to(camera.global_position) <= def.active_distance
		assert_eq(stone.freeze, not near, "%s at %.1f m" % [stone.name,
				stone.global_position.distance_to(camera.global_position)])
		frozen += 1 if stone.freeze else 0
	assert_gt(frozen, 0, "the far end of the field is frozen")

	camera.global_position = Vector3(0.0, 2.0, -155.0)
	await wait_physics_frames(TalusBuilder.WINDOW_FRAMES + 2)
	for stone in builder.stones:
		var near := stone.global_position.distance_to(camera.global_position) <= def.active_distance
		assert_eq(stone.freeze, not near, "%s thaws as the camera returns" % stone.name)


## A frozen stone is static to the physics engine, whatever its sleeping flag says.
func test_frozen_stones_do_not_count_as_awake() -> void:
	builder.stones[0].freeze = true
	builder.stones[0].sleeping = false
	assert_eq(builder.awake_count(), 0)


func test_pausing_and_resuming_does_not_wake_untouched_stones() -> void:
	await wait_physics_frames(3)
	get_tree().paused = true
	await wait_process_frames(2)
	get_tree().paused = false
	await wait_physics_frames(3)
	assert_eq(builder.awake_count(), 0, "resuming is not a push")


func test_no_queued_transform_can_wake_a_new_stone() -> void:
	for stone in builder.stones:
		stone.force_update_transform()
		assert_true(PhysicsServer3D.body_get_state(stone.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING),
				"the backend is asleep too, not just the node's cached state")


func test_stones_rest_on_the_surface_instead_of_floating_above_it() -> void:
	for stone in builder.stones:
		var hull: ConvexPolygonShape3D = (stone.get_child(0) as CollisionShape3D).shape
		var lowest := INF
		for vertex in hull.points:
			lowest = minf(lowest, (stone.transform * vertex).y)
		assert_almost_eq(lowest, TalusBuilder.REST_GAP, 0.001)


func test_rebuilding_without_fields_clears_bodies_and_instances() -> void:
	trail.talus = []
	builder.build(sampler, profile, field, trail)
	assert_eq(builder.get_child_count(), 0)
	assert_true(builder.stones.is_empty())
	assert_true(builder.instance_transforms.is_empty())
	assert_eq(builder.awake_count(), 0)


func test_fields_beyond_the_road_are_skipped_and_crossing_fields_are_clamped() -> void:
	def.start = sampler.length + 5.0
	builder.build(sampler, profile, field, trail)
	assert_true(builder.stones.is_empty())
	def.start = sampler.length - 10.0
	builder.build(sampler, profile, field, trail)
	for stone in builder.stones:
		assert_gte(stone.position.z, -sampler.length + 1.0)
