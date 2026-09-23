extends SceneTree
## Records immutable pre-M6A water geometry; deliberately excludes materials.
## Existing water appearance may change, but vertices/indices/UVs/colors may not.

const LEVELS: Array[String] = ["rally_road", "muddy_valley", "frozen_pass", "rock_canyon"]


func _process(_delta: float) -> bool:
	for id: String in LEVELS:
		print("water geometry %s: %s" % [id, fingerprint(get_root(), id)])
	return true


static func fingerprint(parent: Node, id: String) -> Dictionary:
	var scene: PackedScene = load("res://levels/%s/%s.tscn" % [id, id])
	var root := scene.instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	parent.add_child(trail)
	var ribbons: Array = []
	for child: Node in trail.ford_builder.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Water") \
				and not String(child.name).begins_with("Waterfall"):
			ribbons.append(mesh_data(child))
	var result := {"creek": hash(mesh_data(trail.creek_builder)),
		"ruts": hash(mesh_data(trail.rut_water_builder)), "fords": hash(ribbons)}
	parent.remove_child(trail)
	trail.free()
	return result


## Ordered value data only: material changes and new non-mesh children are ignored.
static func mesh_data(node: Node) -> Array:
	var result: Array = []
	if node is Node3D:
		result.append(node.transform)
	if node is MeshInstance3D:
		for index: int in node.mesh.get_surface_count():
			result.append(node.mesh.surface_get_arrays(index))
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			result.append(mesh_data(child))
	return result
