extends SceneTree
## Additional pre-refactor fixtures: shoulder joins, shelf meshes/support hulls
## and terrain appearance. Does not replace or update the shipped road hashes.

const LEVELS: Array[String] = ["rally_road", "muddy_valley", "frozen_pass", "rock_canyon"]


func _process(_delta: float) -> bool:
	for id: String in LEVELS:
		print("build details %s: %s" % [id, fingerprint(get_root(), id)])
	return true


static func fingerprint(parent: Node, id: String) -> Dictionary:
	var scene: PackedScene = load("res://levels/%s/%s.tscn" % [id, id])
	var root := scene.instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	parent.add_child(trail)
	var result := {"joins": hash(tree_data(trail.road_blend_builder)),
		"shelf": hash(tree_data(trail.shelf_builder)),
		"terrain": hash(tree_data(trail.terrain_builder)), "strata": hash(trail.field.wall_strata)}
	parent.remove_child(trail)
	trail.free()
	return result


## Ordered value data only: no instance IDs, RIDs or auto-generated node names.
static func tree_data(node: Node) -> Array:
	var result: Array = [node.get_class()]
	if node is Node3D:
		result.append(node.transform)
	if node.has_meta(SurfaceLookup.META_KEY):
		var surface: SurfaceDef = node.get_meta(SurfaceLookup.META_KEY)
		result.append(surface.id)
	if node is MeshInstance3D:
		for index: int in node.mesh.get_surface_count():
			result.append(node.mesh.surface_get_arrays(index))
		result.append(node.visibility_range_begin)
		result.append(node.visibility_range_end)
		result.append(node.cast_shadow)
	if node is CollisionShape3D:
		var shape: Shape3D = node.shape
		result.append(shape.get_class())
		result.append(shape.margin)
		if shape is ConcavePolygonShape3D:
			result.append(shape.get_faces())
		elif shape is ConvexPolygonShape3D:
			result.append(shape.points)
		elif shape is HeightMapShape3D:
			result.append(shape.map_width)
			result.append(shape.map_depth)
			result.append(shape.map_data)
	for child: Node in node.get_children():
		result.append(tree_data(child))
	return result
