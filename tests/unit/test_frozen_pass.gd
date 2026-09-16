extends GutTest

const TRAIL := preload("res://levels/frozen_pass/frozen_pass_trail.tres")
const TERRAIN := preload("res://levels/frozen_pass/frozen_pass_terrain.tres")
const CURVE := preload("res://levels/frozen_pass/frozen_pass_curve.tres")

var sampler: RoadSampler
var profile: RoadProfile


func before_each() -> void:
	sampler = RoadSampler.new(CURVE, TRAIL.use_curve_banking)
	profile = RoadProfile.new(TRAIL, sampler.length)


func test_layout_has_snow_verges_unbanked_waves_and_required_structures() -> void:
	assert_between(sampler.length - TRAIL.end_margin, 2050.0, 2150.0)
	assert_eq(TRAIL.end_margin, 70.0)
	assert_eq(TRAIL.base_surface.id, &"snow")
	assert_eq(TRAIL.shoulder_surface.id, &"snow")
	assert_eq(TERRAIN.surface.id, &"snow")
	assert_ne(TRAIL.asphalt_color, TRAIL.shoulder_color, "packed road is distinct from snowy verges")
	assert_false(TRAIL.painted_lines)
	assert_eq(TRAIL.undulation_amplitude, 0.12)
	assert_true(profile.potholes.is_empty())
	assert_gte(TRAIL.rollers.size(), 4)
	for distance in range(5, int(sampler.length), 5):
		assert_almost_eq(sampler.right(distance).y, 0.0, 0.00001, "no unintended curve banking")
		assert_almost_eq(profile.height(distance, -3.0), profile.height(distance, 3.0), 0.00001, "bumps span the width")
	assert_eq(TRAIL.tunnels.size(), 1)
	assert_eq(TRAIL.tunnels[0].start, 1150.0)
	assert_eq(TRAIL.tunnels[0].length, 250.0)
	assert_eq(TRAIL.tunnels[0].height, 6.0)
	assert_eq(TRAIL.bridges.size(), 1)
	assert_eq(TRAIL.bridges[0].length, 30.0)
	assert_eq(TRAIL.bridges[0].drop, 0.7)


func test_ice_is_glossy_and_shoulders_keep_snow_in_both_build_modes() -> void:
	for threaded: bool in [true, false]:
		var road := RoadBuilder.new()
		road.threaded = threaded
		add_child(road)
		road.build(sampler, profile, TRAIL)
		await wait_physics_frames(2)
		var glossy := 0
		for child in road.get_children():
			if child is MeshInstance3D and child.material_override.roughness < 0.2:
				glossy += 1
		assert_eq(glossy, 6, "one glossy road chunk per ice patch")
		for distance: float in [540.0, 754.0, 1200.0, 1415.0, 1565.0, 1730.0, 1960.0]:
			for lateral: float in [0.0, -5.5, 5.5]:
				var point := sampler.surface_point(distance, lateral, profile)
				var hit := road.get_world_3d().direct_space_state.intersect_ray(
						PhysicsRayQueryParameters3D.create(point + Vector3.UP, point + Vector3.DOWN))
				assert_false(hit.is_empty(), "road and shoulder are continuous")
				if not hit.is_empty():
					var expected: StringName = profile.surface_at(distance).id if lateral == 0.0 else &"snow"
					assert_eq(SurfaceLookup.surface_of(hit["collider"]).id, expected)
		remove_child(road)
		road.queue_free()
		await wait_process_frames(1)


func test_integrated_tunnel_openings_walls_roof_and_bridge_floor() -> void:
	var level := TrailLevel.new()
	level.trail = TRAIL
	level.terrain = TERRAIN
	level.scatter = load("res://levels/frozen_pass/frozen_pass_scatter.tres")
	var path := Path3D.new()
	path.name = "Road"
	path.curve = CURVE
	level.add_child(path)
	add_child_autofree(level)
	await wait_physics_frames(2)
	var space := level.get_world_3d().direct_space_state
	var entry := sampler.position(1152.0) + Vector3.UP * 2.0
	var exit := sampler.position(1398.0) + Vector3.UP * 2.0
	assert_false(space.intersect_ray(PhysicsRayQueryParameters3D.create(entry, exit)).is_empty(),
			"the S-bend hides the exit from the entrance")
	for distance in range(1125, 1425):
		var point := sampler.position(distance) + Vector3.UP
		var next := sampler.position(distance + 1.0) + Vector3.UP
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, next))
		assert_true(hit.is_empty(), "clear passage at %d m" % distance)
	for distance: float in [1170.0, 1250.0, 1370.0]:
		var point := sampler.position(distance) + Vector3.UP * 2.0
		for side: float in [-1.0, 1.0]:
			var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + sampler.right(distance) * side * 8.0))
			assert_false(wall.is_empty(), "solid tunnel wall")
		var roof := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point + Vector3.UP * 8.0))
		assert_false(roof.is_empty(), "solid tunnel ceiling")
		assert_gte(level.field.height_at(point.x, point.z) - sampler.position(distance).y, 14.0, "8 m of rock above ceiling")
	for distance: float in [1144.0, 1406.0]:
		for lateral: float in [-7.5, 7.5]:
			var bank := sampler.position(distance) + sampler.right(distance) * lateral
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(bank + Vector3.UP * 20.0, bank + Vector3.DOWN))
			assert_false(hit.is_empty(), "closed snowy banks beside portal retaining walls")
	var floor_point := sampler.position(850.0) + sampler.right(850.0) * 12.0
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point, floor_point + Vector3.DOWN * 10.0))
	assert_false(floor_hit.is_empty())
	if not floor_hit.is_empty():
		assert_eq(SurfaceLookup.surface_of(floor_hit["collider"]).id, &"ice", "ice collision above underlying snowy terrain")
		assert_almost_eq(floor_hit["position"].y, sampler.position(850.0).y - 6.0, 0.15)
