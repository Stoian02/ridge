class_name CheckpointPlacer
extends Node3D
## Creates the checkpoint gates along a trail. Each gate is an Area3D across the
## road and shoulders, two posts with a banner, and the transform a reset puts
## the car at. Gate 0 is the start and the last gate is the finish.

signal gate_entered(index: int, body: Node3D)

## Gate size across, up and along the road (m).
const GATE_SIZE := Vector3(12.0, 6.0, 2.0)
## Reset transforms sit this far above the road surface (m).
const RESET_HEIGHT := 1.0
const POST_HEIGHT := 4.6
const GATE_COLOR := Color(0.93, 0.92, 0.88)
const BANNER_COLOR := Color(0.95, 0.45, 0.1)

var gate_distances := PackedFloat32Array()
var reset_transforms: Array[Transform3D] = []


## The start gate, every checkpoint between the start and the finish, and the finish gate.
static func distances_for(length: float, def: TrailDef) -> PackedFloat32Array:
	var finish := length - def.end_margin
	var inner := Array(def.checkpoint_distances).filter(
			func(d: float) -> bool: return d > def.start_distance and d < finish)
	inner.sort()
	var result := PackedFloat32Array([def.start_distance])
	result.append_array(PackedFloat32Array(inner))
	result.append(finish)
	return result


static func label_for(index: int, count: int) -> String:
	if index == 0:
		return "START"
	if index == count - 1:
		return "FINISH"
	return "CP %d" % index


## A gate's width across the road at `distance`: the road and shoulders plus a
## metre each side, but never wider than GATE_SIZE.x, which every existing level keeps.
static func gate_width_at(def: TrailDef, distance: float) -> float:
	return minf(GATE_SIZE.x, 2.0 * def.half_total_width_at(distance) + 2.0)


func build(sampler: RoadSampler, profile: RoadProfile, def: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	gate_distances = distances_for(sampler.length, def)
	reset_transforms.clear()
	var post_mesh := LowPolyMeshes.gate_post(GATE_COLOR, POST_HEIGHT)
	# Gates of the same width share one banner mesh.
	var banner_meshes := {}
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	for i in gate_distances.size():
		var distance := gate_distances[i]
		var width := gate_width_at(def, distance)
		reset_transforms.append(sampler.transform_at(distance, RESET_HEIGHT, profile))
		var gate := Node3D.new()
		gate.name = "Gate%d" % i
		gate.transform = sampler.transform_at(distance, 0.0, profile)
		add_child(gate)

		var area := Area3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(width, GATE_SIZE.y, GATE_SIZE.z)
		var shape := CollisionShape3D.new()
		shape.shape = box
		shape.position = Vector3(0.0, GATE_SIZE.y * 0.5, 0.0)
		area.add_child(shape)
		area.body_entered.connect(_on_body_entered.bind(i))
		gate.add_child(area)

		for side: float in [-1.0, 1.0]:
			var upright := MeshInstance3D.new()
			upright.mesh = post_mesh
			upright.material_override = material
			upright.position = Vector3(side * (width * 0.5 + 0.5), 0.0, 0.0)
			gate.add_child(upright)
		if not banner_meshes.has(width):
			banner_meshes[width] = LowPolyMeshes.banner(BANNER_COLOR, width + 1.0)
		var banner_mesh: ArrayMesh = banner_meshes[width]
		var banner := MeshInstance3D.new()
		banner.mesh = banner_mesh
		banner.material_override = material
		banner.position = Vector3(0.0, POST_HEIGHT - 0.4, 0.0)
		gate.add_child(banner)
		var text := Label3D.new()
		text.text = label_for(i, gate_distances.size())
		text.font_size = 96
		text.pixel_size = 0.01
		text.position = Vector3(0.0, POST_HEIGHT - 0.4, 0.06)
		gate.add_child(text)


func _on_body_entered(body: Node3D, index: int) -> void:
	gate_entered.emit(index, body)
