class_name StructureMesh
extends RefCounted
## Small flat-shaded procedural structures, merged into one mesh and collider.

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()


func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	vertices.append_array([a, b, c])
	normals.append_array([normal, normal, normal])
	colors.append_array([color, color, color])


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	triangle(a, b, c, color)
	triangle(a, c, d, color)


func box(transform: Transform3D, size: Vector3, color: Color) -> void:
	var p: Array[Vector3] = []
	for corner: Vector3 in [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1),
			Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]:
		p.append(transform * (corner * size * 0.5))
	for face: Array in [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]:
		quad(p[face[0]], p[face[1]], p[face[2]], p[face[3]], color)


func add_to(parent: Node3D, label: String, surface: SurfaceDef, shadows: bool = true) -> MeshInstance3D:
	if vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	if surface != null:
		var body := RoadBuilder._collision_body(vertices, surface)
		body.name = label + "Collision"
		parent.add_child(body)
	return instance
