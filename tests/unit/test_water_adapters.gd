extends GutTest
## Existing water registers its actual generated faces, without moving the road,
## bank or seeded puddles. Standalone builders remove their own registrations.

var trail: TrailDef
var sampler: RoadSampler
var profile: RoadProfile
var field: TerrainField
var road: RoadBuilder
var world: WaterWorld


func before_each() -> void:
	trail = TrailDef.new()
	trail.painted_lines = false
	trail.undulation_amplitude = 0.0
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -240.0))
	sampler = RoadSampler.new(curve, false, trail)
	world = WaterWorld.new()


func _build_ground() -> void:
	profile = RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.margin = 64.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	field = TerrainField.generate(sampler, trail, terrain)
	road = RoadBuilder.new()
	add_child_autofree(road)
	road.build(sampler, profile, trail)


func test_ford_uses_actual_road_bed_dry_banks_and_downstream_current() -> void:
	var ford := FordDef.new()
	ford.distance = 120.0
	ford.current_speed = 0.5
	trail.fords = [ford]
	_build_ground()
	var builder := FordBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)
	var water: MeshInstance3D = builder.get_node("Water0")
	var faces := water.mesh.get_faces()
	builder.register_water(world, field, [road])
	assert_eq(world.bodies.size(), 1, "waterfall sheet and mist are not liquid volumes")
	assert_eq(water.mesh.get_faces(), faces)
	var sample := WaterSample.new()
	var centre := sampler.surface_point(ford.distance, 0.0, profile)
	world.sample(centre + Vector3.UP * 0.1, sample)
	assert_true(sample.valid)
	assert_almost_eq(sample.surface_y - sample.bed_y, 0.30, 0.00001)
	assert_almost_eq(sample.bed_y, centre.y, 0.00001, "not the terrain lowered beneath the road")
	assert_lt(sample.current.distance_to(Vector3.RIGHT * 0.5), 0.00001)
	var bank := sampler.surface_point(ford.distance + 16.0, 0.0, profile)
	world.sample(bank + Vector3.UP, sample)
	assert_false(sample.valid, "solid approach masks the ribbon laid underneath it")
	world.sample(centre - Vector3.UP * 30.0, sample)
	assert_false(sample.valid)
	assert_eq((water.material_override as StandardMaterial3D).albedo_color.a, 0.50)


func test_creek_follows_sloped_drawn_triangles_and_leaves_the_bank_dry() -> void:
	trail.creek_start = 40.0
	trail.creek_length = 160.0
	trail.creek_current_speed = 0.35
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, -8.0, -240.0))
	sampler = RoadSampler.new(curve, false, trail)
	_build_ground()
	var builder := CreekBuilder.new()
	add_child_autofree(builder)
	builder.build(field, sampler, trail)
	builder.register_water(world, field, [road])
	assert_eq(world.bodies.size(), 1)
	var water: MeshInstance3D = builder.get_node("Water")
	var faces := water.mesh.get_faces()
	var sample := WaterSample.new()
	var wet := 0
	for index in faces.size() / 3:
		var point := (faces[index * 3] + faces[index * 3 + 1] + faces[index * 3 + 2]) / 3.0
		world.sample(point, sample)
		if not sample.valid:
			continue
		wet += 1
		assert_almost_eq(sample.surface_y, point.y, 0.0001)
		assert_almost_eq(sample.current.length(), 0.35, 0.00001)
		assert_lt(sample.current.z, 0.0, "toward the lower end, not up the road")
	assert_gt(wet, 20)
	var bank := TerrainField.creek_point(sampler, trail, 120.0)
	world.sample(Vector3(bank.x + 5.0, 20.0, bank.y), sample)
	assert_false(sample.valid)
	assert_almost_eq((water.material_override as StandardMaterial3D).albedo_color.a, 0.55, 0.0000001)


func test_rut_pieces_have_real_road_depth_and_dry_gaps() -> void:
	var stretch := SurfaceStretch.new()
	stretch.start = 20.0
	stretch.length = 190.0
	stretch.surface = preload("res://surfaces/deep_mud.tres")
	stretch.rut_depth = 0.18
	stretch.rut_width = 0.9
	stretch.rut_spacing = 1.6
	stretch.water_rut_depth = 0.09
	stretch.blend_length = 12.0
	trail.surface_stretches = [stretch]
	_build_ground()
	var builder := RutWaterBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, trail)
	builder.register_water(world, field, [road])
	assert_gt(world.bodies.size(), 0)
	var sample := WaterSample.new()
	var previous: Dictionary = {}
	var gaps := 0
	for puddle: Vector3 in builder.puddle_ranges:
		var at := (puddle.x + puddle.y) * 0.5
		var point := sampler.surface_point(at, puddle.z, profile)
		world.sample(point + Vector3.UP * 0.03, sample, 0.05)
		assert_true(sample.valid)
		if sample.valid:
			assert_almost_eq(sample.surface_y - sample.bed_y, 0.09, 0.002)
			assert_eq(sample.current, Vector3.ZERO)
		if previous.has(puddle.z):
			var gap_at := (float(previous[puddle.z]) + puddle.x) * 0.5
			var gap := sampler.surface_point(gap_at, puddle.z, profile)
			world.sample(gap + Vector3.UP * 0.03, sample, 0.05)
			assert_false(sample.valid, "unlaid seeded gap is dry")
			gaps += 1
		previous[puddle.z] = puddle.y
	assert_gt(gaps, 5)
	world.sample(sampler.surface_point(110.0, 0.0, profile), sample, 0.5)
	assert_false(sample.valid, "the dry middle between wheel ruts is not water")


func test_rebuild_and_builder_exit_unregister_instead_of_retaining_stale_water() -> void:
	trail.creek_start = 30.0
	trail.creek_length = 180.0
	_build_ground()
	var builder := CreekBuilder.new()
	add_child(builder)
	builder.build(field, sampler, trail)
	builder.register_water(world, field, [road])
	assert_eq(world.bodies.size(), 1)
	builder.register_water(world, field, [road])
	assert_eq(world.bodies.size(), 1)
	trail.creek_length = 0.0
	builder.build(field, sampler, trail)
	assert_eq(world.bodies.size(), 0)
	trail.creek_length = 180.0
	builder.build(field, sampler, trail)
	builder.register_water(world, field, [road])
	assert_eq(world.bodies.size(), 1)
	remove_child(builder)
	builder.free()
	assert_eq(world.bodies.size(), 0)


func test_authored_current_values_are_explicit_and_do_not_change_old_surface_stats() -> void:
	var canyon: TrailDef = load("res://levels/rock_canyon/rock_canyon_trail.tres")
	var valley: TrailDef = load("res://levels/muddy_valley/muddy_valley_trail.tres")
	assert_eq(canyon.fords[0].current_speed, 0.5)
	assert_eq(valley.creek_current_speed, 0.35)
	var count := 0
	for stretch: SurfaceStretch in canyon.surface_stretches:
		if stretch.water_rut_depth > 0.0:
			assert_eq(stretch.water_current_velocity, Vector3.ZERO)
			count += 1
	assert_eq(count, 1)
