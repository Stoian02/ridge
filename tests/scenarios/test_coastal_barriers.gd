extends GutTest
## Visible protection matches contact, while slow technical corners stay open.

const LEVEL := preload("res://levels/coastal_highway/coastal_highway.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	SaveSandbox.leave()


func test_visible_barriers_are_solid_and_leave_the_road_and_open_corners_clear() -> void:
	var level: RunLevel = LEVEL.instantiate()
	add_child_autofree(level)
	level.rig.car.freeze = true
	await wait_physics_frames(2)
	var trail := level.trail
	var space := level.get_world_3d().direct_space_state
	assert_eq(trail.barrier_builder.get_child_count(), 6, "one mesh/body per span")
	for span: RoadBarrierDef in trail.trail.barriers:
		for fraction: float in [0.05, 0.25, 0.5, 0.75, 0.95]:
			var at := span.start + span.length * fraction
			var lateral := span.lateral(trail.trail, at)
			var p := trail.sampler.surface_point(at, lateral, trail.profile)
			p.y += span.height * lerpf(0.35, 1.0, span.end_weight(at)) - 0.08
			var right := trail.sampler.right(at)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p - right, p + right))
			assert_false(hit.is_empty())
			if not hit.is_empty():
				assert_eq(hit.collider.get_parent(), trail.barrier_builder)
				assert_almost_eq(hit.position.distance_to(p), span.width * 0.5, 0.04, "visual beam matches contact")
	for at: float in [1050, 1200, 1500, 1850, 2380]:
		var centre := trail.sampler.surface_point(at, 0, trail.profile) + Vector3.UP * 0.6
		var edge := centre + trail.sampler.right(at) * (trail.trail.half_total_width_at(at) + 0.2)
		assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(centre, edge)).is_empty(), "technical edge is genuinely open")
