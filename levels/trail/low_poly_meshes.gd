class_name LowPolyMeshes
extends RefCounted
## Small flat-shaded meshes for scenery, built in code with vertex colours:
## pine, broadleaf tree, rock, roadside post, gate post and gate banner. Every
## triangle is flat-shaded, wound and lit so it faces away from its shape's centre.

const ICOSAHEDRON_FACES := [
	[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
	[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5],
	[2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
]


## A pine about 4.7 m tall: a trunk and three stacked cones.
static func pine(foliage: Color, trunk: Color) -> ArrayMesh:
	var tool := _begin()
	_add_cylinder(tool, Vector3.ZERO, 0.15, 1.2, 6, trunk)
	# Only the lowest cone has a base; the upper bases are hidden inside the cone below.
	_add_cone(tool, Vector3(0.0, 0.8, 0.0), 1.6, 2.2, 7, foliage, true)
	_add_cone(tool, Vector3(0.0, 2.0, 0.0), 1.2, 1.9, 7, foliage.lightened(0.05), false)
	_add_cone(tool, Vector3(0.0, 3.1, 0.0), 0.8, 1.6, 7, foliage.lightened(0.1), false)
	return _finish(tool)


## A broadleaf tree about 5 m tall: a trunk and two lumpy leaf clumps (48 triangles).
static func broadleaf(foliage: Color, trunk: Color, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tool := _begin()
	_add_cylinder(tool, Vector3.ZERO, 0.18, 2.6, 4, trunk)
	_add_lumpy_ball(tool, Vector3(0.0, 3.4, 0.0), 1.8, 0.8, foliage, rng)
	_add_lumpy_ball(tool, Vector3(-0.5, 4.4, -0.3), 1.2, 0.8, foliage.lightened(0.08), rng)
	return _finish(tool)


## A rough, slightly flattened boulder about 2 m across.
static func rock(color: Color, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tool := _begin()
	_add_lumpy_ball(tool, Vector3.ZERO, 1.0, 0.7, color, rng)
	return _finish(tool)


## A dense, low bush about 2 m wide and 1.3 m tall for a hedgerow.
static func hedge_bush(color: Color, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var tool := _begin()
	_add_lumpy_ball(tool, Vector3(0.0, 0.65, 0.0), 1.0, 0.65, color, rng)
	return _finish(tool)


## A roadside post 1 m tall with a reflector band near the top.
static func post(body: Color, band: Color) -> ArrayMesh:
	var tool := _begin()
	_add_box(tool, Vector3(0.0, 0.5, 0.0), Vector3(0.12, 1.0, 0.12), body)
	_add_box(tool, Vector3(0.0, 0.8, 0.0), Vector3(0.14, 0.12, 0.14), band)
	return _finish(tool)


## One upright of a checkpoint gate.
static func gate_post(color: Color, height: float) -> ArrayMesh:
	var tool := _begin()
	_add_box(tool, Vector3(0.0, height * 0.5, 0.0), Vector3(0.3, height, 0.3), color)
	return _finish(tool)


## The banner across the top of a checkpoint gate.
static func banner(color: Color, width: float) -> ArrayMesh:
	var tool := _begin()
	_add_box(tool, Vector3.ZERO, Vector3(width, 0.8, 0.1), color)
	return _finish(tool)


static func _begin() -> SurfaceTool:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	return tool


static func _finish(tool: SurfaceTool) -> ArrayMesh:
	return tool.commit()


## Adds a flat-shaded triangle facing away from `centre` (Godot's front faces
## have (b - a) x (c - a) pointing into the shape). Normals are set per triangle
## rather than generated, because generated normals smooth shared corners.
static func _add_triangle(tool: SurfaceTool, centre: Vector3, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var outward := (a + b + c) / 3.0 - centre
	if (b - a).cross(c - a).dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
	tool.set_color(color)
	tool.set_normal(-(b - a).cross(c - a).normalized())
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


## A jittered icosahedron of about `radius`, squashed vertically by `flatten`,
## with each face shaded slightly differently.
static func _add_lumpy_ball(tool: SurfaceTool, centre: Vector3, radius: float, flatten: float, color: Color,
		rng: RandomNumberGenerator) -> void:
	var golden := (1.0 + sqrt(5.0)) * 0.5
	var corners: Array[Vector3] = [
		Vector3(-1, golden, 0), Vector3(1, golden, 0), Vector3(-1, -golden, 0), Vector3(1, -golden, 0),
		Vector3(0, -1, golden), Vector3(0, 1, golden), Vector3(0, -1, -golden), Vector3(0, 1, -golden),
		Vector3(golden, 0, -1), Vector3(golden, 0, 1), Vector3(-golden, 0, -1), Vector3(-golden, 0, 1),
	]
	for i in corners.size():
		var jittered := corners[i].normalized() * rng.randf_range(0.8, 1.2)
		corners[i] = centre + Vector3(jittered.x, jittered.y * flatten, jittered.z) * radius
	for face in ICOSAHEDRON_FACES:
		var shade := rng.randf_range(0.9, 1.05)
		_add_triangle(tool, centre, corners[face[0]], corners[face[1]], corners[face[2]],
				Color(color.r * shade, color.g * shade, color.b * shade))


static func _add_box(tool: SurfaceTool, centre: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(centre + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	for quad in [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]:
		_add_triangle(tool, centre, corners[quad[0]], corners[quad[1]], corners[quad[2]], color)
		_add_triangle(tool, centre, corners[quad[0]], corners[quad[2]], corners[quad[3]], color)


static func _add_cone(tool: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, color: Color,
		with_base: bool) -> void:
	var tip := base + Vector3(0.0, height, 0.0)
	var centre := base + Vector3(0.0, height * 0.25, 0.0)
	for i in sides:
		var a := base + Vector3(cos(TAU * i / sides), 0.0, sin(TAU * i / sides)) * radius
		var b := base + Vector3(cos(TAU * (i + 1) / sides), 0.0, sin(TAU * (i + 1) / sides)) * radius
		_add_triangle(tool, centre, a, b, tip, color)
		if with_base:
			_add_triangle(tool, centre, a, b, base, color.darkened(0.2))


static func _add_cylinder(tool: SurfaceTool, base: Vector3, radius: float, height: float, sides: int, color: Color) -> void:
	var centre := base + Vector3(0.0, height * 0.5, 0.0)
	var top := Vector3(0.0, height, 0.0)
	for i in sides:
		var a := base + Vector3(cos(TAU * i / sides), 0.0, sin(TAU * i / sides)) * radius
		var b := base + Vector3(cos(TAU * (i + 1) / sides), 0.0, sin(TAU * (i + 1) / sides)) * radius
		_add_triangle(tool, centre, a, b, b + top, color)
		_add_triangle(tool, centre, a, b + top, a + top, color)
