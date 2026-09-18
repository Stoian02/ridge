class_name FallenTreeBuilder
extends Node3D
## One low-poly mesh and matching fixed collider per tree. No dynamic logs,
## hidden boxes or collision taller than the visible wood.

const SIDES := 10
const LOGS := preload("res://surfaces/logs.tres")


func build(sampler: RoadSampler, profile: RoadProfile, trail: TrailDef) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for tree: FallenTreeDef in trail.fallen_trees:
		var root_at := tree.road_point(0.0)
		var tip_at := tree.road_point(1.0)
		var root := sampler.surface_point(root_at.x, root_at.y, profile) - Vector3.UP * tree.burial
		var tip := sampler.surface_point(tip_at.x, tip_at.y, profile) - Vector3.UP * tree.burial
		var mesh := StructureMesh.new()
		_trunk(mesh, root, tip, tree.root_radius, tree.tip_radius, tree)
		# Broken roots outside the carriageway make its fallen origin readable,
		# without a branch spike in the chosen crossing lines.
		var outward := (root - tip).normalized()
		var side := outward.cross(Vector3.UP).normalized()
		for sign_value: float in [-1.0, 1.0]:
			var end := root + outward * 0.7 + side * sign_value * 0.9 + Vector3.UP * 0.45
			_trunk(mesh, root, end, tree.root_radius * 0.42, 0.055, tree)
		var instance := mesh.add_to(self, "FallenTree%d" % get_child_count(), LOGS)
		instance.visibility_range_end = 200.0


func _trunk(mesh: StructureMesh, from: Vector3, to: Vector3,
		from_radius: float, to_radius: float, tree: FallenTreeDef) -> void:
	var axis := (to - from).normalized()
	var right := axis.cross(Vector3.UP).normalized()
	var up := right.cross(axis).normalized()
	for i in SIDES:
		var a := TAU * float(i) / float(SIDES)
		var b := TAU * float(i + 1) / float(SIDES)
		var radial_a := up * cos(a) + right * sin(a)
		var radial_b := up * cos(b) + right * sin(b)
		var root_a := from + radial_a * from_radius
		var root_b := from + radial_b * from_radius
		var tip_a := to + radial_a * to_radius
		var tip_b := to + radial_b * to_radius
		var shade: float = 0.87 if i % 3 == 0 else 1.0
		var bark := Color(tree.bark_color.r * shade, tree.bark_color.g * shade, tree.bark_color.b * shade)
		mesh.quad(root_a, tip_a, tip_b, root_b, bark)
		mesh.triangle(from, root_a, root_b, tree.wood_color)
		mesh.triangle(to, tip_b, tip_a, tree.wood_color)
