extends SceneTree
## Prints fingerprints of the shipped levels' generated geometry (road mesh
## vertices, collision faces, terrain heights, edge distances, gate distances)
## for tests/unit/test_geometry_fingerprints.gd. Run from the project root:
##   godot --headless -s tools/record_geometry.gd
## Paste the printed lines into the test's EXPECTED table only after a change
## that is meant to alter a level, never to make a regression pass.

const LEVELS: Array[String] = ["rally_road", "muddy_valley", "frozen_pass", "rock_canyon"]


## Runs on the first frame rather than in _init, because only then is the root
## inside the tree (so a level's _ready builds it) and are the autoloads up.
func _process(_delta: float) -> bool:
	for id in LEVELS:
		var result := fingerprint(get_root(), id)
		print("%s: heights %d, edges %d, gates %s, road %s" % [id, result["heights"], result["edges"],
				result["gates"], result["road"]])
	return true


## Builds level `id`'s Trail under `parent` and returns its fingerprints:
## {"heights": int, "edges": int, "road": PackedInt64Array, "gates": PackedFloat32Array}.
## The road array holds one hash per RoadBuilder child in order: mesh vertices
## for a MeshInstance3D, collision faces for a StaticBody3D.
static func fingerprint(parent: Node, id: String) -> Dictionary:
	var scene: PackedScene = load("res://levels/%s/%s.tscn" % [id, id])
	var root: Node = scene.instantiate()
	var trail: TrailLevel = root.get_node("Trail")
	root.remove_child(trail)
	root.free()
	parent.add_child(trail)  # builds in _ready
	var road := PackedInt64Array()
	for child in trail.road_builder.get_children():
		if child is MeshInstance3D:
			road.append(hash(child.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
		elif child is StaticBody3D:
			road.append(hash((child.get_child(0).shape as ConcavePolygonShape3D).get_faces()))
	var result := {"heights": hash(trail.field.heights), "edges": hash(trail.field.edge_distances),
			"road": road, "gates": trail.checkpoints.gate_distances.duplicate()}
	parent.remove_child(trail)
	trail.free()
	return result
