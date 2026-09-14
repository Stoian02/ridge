class_name CarBodyBuilder
extends RefCounted
## Builds a car's low-poly body (spec §6.1): one flat-shaded, vertex-coloured mesh
## sized to CarStats.body_size - a lower body with bevelled top edges, narrowed and
## lowered toward its nose and tail; a cabin with sloped windows and a darker window
## band; and the extras its CarBodyDef switches on. Forward is -Z.

## Share of the body's length over which the nose and the tail taper.
const TAPER_LENGTH := 0.22
## Height of the window band as a share of the cabin; the rest is roof.
const WINDOW_SHARE := 0.7
## The cabin's half width at its base and at its roof, as shares of the body's.
const CABIN_BASE_WIDTH := 0.92
const CABIN_ROOF_WIDTH := 0.78
## Faces of an eight-cornered solid whose corners are indexed like a box: bit 0 =
## +X side, bit 1 = top, bit 2 = +Z end.
const SOLID_FACES := [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]


static func build(body: CarBodyDef, stats: CarStats) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var size := stats.body_size
	var half := size * 0.5
	var bevel := minf(body.bevel, half.y * 0.5)
	_add_tapered_slab(tool, body, size, -half.y, half.y - bevel, half.x, body.body_color)
	_add_tapered_slab(tool, body, size, half.y - bevel, half.y, half.x - bevel, body.body_color)
	var base := _cabin_outline(body, size, 0.0)
	var band := _cabin_outline(body, size, WINDOW_SHARE)
	var roof := _cabin_outline(body, size, 1.0)
	_add_cabin_section(tool, base, band, half.y, half.y + body.cabin_height * WINDOW_SHARE, body.window_color)
	_add_cabin_section(tool, band, roof, half.y + body.cabin_height * WINDOW_SHARE, half.y + body.cabin_height, body.body_color)
	_add_extras(tool, body, stats)
	return tool.commit()


## The material every car body uses: its vertex colours, lit.
static func material() -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.vertex_color_use_as_albedo = true
	result.vertex_color_is_srgb = true
	result.roughness = 0.6
	return result


## A slab from `bottom` to `top` (m), `half_width` either side, along the body's
## length: full size in the middle, narrowed and lowered over the last TAPER_LENGTH
## toward the nose and the tail by the body's tapers.
static func _add_tapered_slab(tool: SurfaceTool, body: CarBodyDef, size: Vector3, bottom: float, top: float,
		half_width: float, color: Color) -> void:
	var floor := -size.y * 0.5
	var half_length := size.z * 0.5
	var taper_run := size.z * TAPER_LENGTH
	# Stations along the length as Vector2(z, taper): nose, end of nose taper, start of tail taper, tail.
	var stations: Array[Vector2] = [Vector2(-half_length, body.nose_taper), Vector2(-half_length + taper_run, 0.0),
			Vector2(half_length - taper_run, 0.0), Vector2(half_length, body.tail_taper)]
	for piece in 3:
		var corners: Array[Vector3] = []
		for station: Vector2 in [stations[piece], stations[piece + 1]]:
			for y: float in [bottom, top]:
				for side: float in [-1.0, 1.0]:
					corners.append(Vector3(side * half_width * (1.0 - station.y), y - (y - floor) * station.y, station.x))
		_add_solid(tool, corners, color)


## The cabin's outline `share` of the way from its base to its roof, as
## Vector3(front z, rear z, half width).
static func _cabin_outline(body: CarBodyDef, size: Vector3, share: float) -> Vector3:
	var base_front := -size.z * 0.5 + body.hood_length * size.z
	var roof_front := base_front + body.windscreen_slope * size.z
	var roof_rear := roof_front + body.cabin_length * size.z
	var base_rear := roof_rear + body.rear_window_slope * size.z
	return Vector3(lerpf(base_front, roof_front, share), lerpf(base_rear, roof_rear, share),
			size.x * 0.5 * lerpf(CABIN_BASE_WIDTH, CABIN_ROOF_WIDTH, share))


static func _add_cabin_section(tool: SurfaceTool, lower: Vector3, upper: Vector3, lower_y: float, upper_y: float,
		color: Color) -> void:
	var corners: Array[Vector3] = []
	for end in 2:
		for level in 2:
			var outline := lower if level == 0 else upper
			var y := lower_y if level == 0 else upper_y
			for side: float in [-1.0, 1.0]:
				corners.append(Vector3(side * outline.z, y, outline.x if end == 0 else outline.y))
	_add_solid(tool, corners, color)


## Adds a convex eight-cornered solid, each face lit away from its centre.
static func _add_solid(tool: SurfaceTool, corners: Array[Vector3], color: Color) -> void:
	var centre := Vector3.ZERO
	for corner in corners:
		centre += corner
	centre /= corners.size()
	for quad: Array in SOLID_FACES:
		LowPolyMeshes._add_triangle(tool, centre, corners[quad[0]], corners[quad[1]], corners[quad[2]], color)
		LowPolyMeshes._add_triangle(tool, centre, corners[quad[0]], corners[quad[2]], corners[quad[3]], color)


static func _add_extras(tool: SurfaceTool, body: CarBodyDef, stats: CarStats) -> void:
	var size := stats.body_size
	var half := size * 0.5
	var roof_y := half.y + body.cabin_height
	if body.rear_spoiler:
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y + 0.1, half.z - 0.18), Vector3(size.x * 0.8, 0.05, 0.28), body.body_color)
	if body.big_wing:
		for side: float in [-1.0, 1.0]:
			LowPolyMeshes._add_box(tool, Vector3(side * size.x * 0.32, half.y + 0.16, half.z - 0.22), Vector3(0.06, 0.32, 0.12), body.trim_color)
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y + 0.34, half.z - 0.24), Vector3(size.x * 0.96, 0.05, 0.38), body.body_color)
	if body.hood_scoop:
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y + 0.04, -half.z + body.hood_length * size.z * 0.55),
				Vector3(size.x * 0.3, 0.08, 0.36), body.trim_color)
	if body.roof_rack:
		var roof := _cabin_outline(body, size, 1.0)
		var rack_length := (roof.y - roof.x) * 0.9
		var rack_z := (roof.x + roof.y) * 0.5
		for side: float in [-1.0, 1.0]:
			LowPolyMeshes._add_box(tool, Vector3(side * roof.z * 0.8, roof_y + 0.07, rack_z), Vector3(0.05, 0.06, rack_length), body.trim_color)
		for end: float in [-0.35, 0.35]:
			LowPolyMeshes._add_box(tool, Vector3(0.0, roof_y + 0.11, rack_z + end * rack_length), Vector3(roof.z * 1.7, 0.04, 0.05), body.trim_color)
	if body.bull_bar:
		LowPolyMeshes._add_box(tool, Vector3(0.0, -half.y * 0.1, -half.z - 0.1), Vector3(size.x * 0.82, size.y * 0.7, 0.08), body.trim_color)
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y * 0.55, -half.z - 0.05), Vector3(size.x * 0.6, 0.08, 0.14), body.trim_color)
	if body.spare_wheel:
		LowPolyMeshes._add_box(tool, Vector3(0.0, half.y * 0.2, half.z + 0.12),
				Vector3(stats.wheel_radius * 1.6, stats.wheel_radius * 1.6, 0.24), body.trim_color)
	if body.fender_flares:
		for axle_z: float in [-stats.wheelbase * 0.5, stats.wheelbase * 0.5]:
			for side: float in [-1.0, 1.0]:
				LowPolyMeshes._add_box(tool, Vector3(side * (half.x + 0.05), -half.y * 0.35, axle_z),
						Vector3(0.1, size.y * 0.35, stats.wheel_radius * 2.4), body.trim_color)
