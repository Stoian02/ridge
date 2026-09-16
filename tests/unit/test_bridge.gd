extends GutTest

var sampler: RoadSampler
var trail: TrailDef
var bridge: BridgeDef
var profile: RoadProfile
var field: TerrainField


func before_each() -> void:
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0, 0, -160))
	sampler = RoadSampler.new(curve)
	trail = TrailDef.new()
	trail.undulation_amplitude = 0.0
	bridge = BridgeDef.new()
	bridge.start = 50.0
	trail.bridges = [bridge]
	profile = RoadProfile.new(trail, sampler.length)
	var terrain := TerrainDef.new()
	terrain.surface = load("res://surfaces/snow.tres")
	terrain.margin = 40.0
	terrain.noise_amplitude = 0.0
	field = TerrainField.generate(sampler, trail, terrain)


func test_profile_steps_down_then_eases_back_up_and_reports_logs() -> void:
	assert_eq(profile.bridge_height(64.9), 0.0)
	assert_almost_eq(profile.bridge_height(65.0), -0.7, 0.0001)
	assert_almost_eq(profile.bridge_height(80.0), -0.7, 0.0001)
	assert_almost_eq(profile.bridge_height(90.0), -0.35, 0.0001)
	assert_eq(profile.bridge_height(100.0), 0.0)
	assert_eq(profile.surface_at(60.0).id, &"logs")


func test_no_road_mesh_or_collision_spans_the_bridge_in_either_build_mode() -> void:
	for threaded: bool in [false, true]:
		var road := RoadBuilder.new()
		road.threaded = threaded
		add_child_autofree(road)
		road.build(sampler, profile, trail)
		await wait_physics_frames(2)
		var hit := road.get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(Vector3(0, 3, -60), Vector3(0, -3, -60)))
		assert_true(hit.is_empty(), "road collision omitted over bridge")
		for child in road.get_children():
			if child is MeshInstance3D:
				var a: Array = child.mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
				for i in range(0, indices.size(), 3):
					var centre := (vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0
					if centre.z < -50.001 and centre.z > -79.999:
						fail_test("road triangle covers the bridge at %s" % centre)
		road.queue_free()
		await wait_process_frames(1)


func test_logs_span_the_road_far_half_is_lower_and_gorge_is_ice() -> void:
	var builder := BridgeBuilder.new()
	add_child_autofree(builder)
	builder.build(sampler, profile, field, trail)
	assert_gt(builder.log_tops.size(), 80)
	assert_gt(builder.log_width, trail.road_width)
	var first := builder.log_tops[10]
	var second := builder.log_tops[builder.log_tops.size() - 10]
	assert_almost_eq(first.y - second.y, bridge.drop, 0.06)
	assert_almost_eq(field.height_at(0.0, -65.0), -bridge.gorge_depth, 0.05)
	assert_lt(field.kill_height(), -bridge.gorge_depth - 10.0)
	await wait_physics_frames(2)
	var space := builder.get_world_3d().direct_space_state
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(12, 2, -65), Vector3(12, -10, -65)))
	assert_eq(SurfaceLookup.surface_of(floor_hit["collider"]).id, &"ice")
	var log_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(first + Vector3.UP, first + Vector3.DOWN))
	assert_eq(SurfaceLookup.surface_of(log_hit["collider"]).id, &"logs")
