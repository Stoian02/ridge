extends GutTest
## Authored render policy must survive resource loading and reach actual nodes.
## This deliberately checks the real level, not just the builder's toggle.


func test_supported_valley_road_keeps_collision_but_skips_shadow_passes() -> void:
	var root: Node = load("res://levels/muddy_valley/muddy_valley.tscn").instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	add_child_autofree(trail)
	assert_false(trail.trail.casts_shadow(0.0, trail.sampler.length))
	var meshes := 0
	var colliders := 0
	for child: Node in trail.road_builder.get_children():
		if child is MeshInstance3D:
			meshes += 1
			assert_eq(child.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		elif child is StaticBody3D:
			colliders += 1
	assert_gt(meshes, 0)
	assert_gt(colliders, 0)
