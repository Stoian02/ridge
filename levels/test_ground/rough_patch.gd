class_name RoughPatch
extends StaticBody3D
## A drivable strip of uneven ground: a heightmap collision shape plus a matching
## mesh, both built from one height function. The strip rises from ground level to
## BASE_HEIGHT over its first and last few metres so cars can drive on and off;
## the features (potholes, bumps, ruts...) are carved into that raised base.
## Local axes: x across the strip, z along it. Cars enter at the +Z end.

enum Profile { ROUGH_ASPHALT, RUTTED_MUD }

## Metres between height samples.
const SPACING := 0.25
## Top of the strip above the surrounding ground (m). Deep enough that potholes
## stay above the ground underneath.
const BASE_HEIGHT := 0.15
## Length of the entry and exit slopes (m).
const TAPER := 3.0

# Rough asphalt, by distance from the entry end.
const POTHOLE_DEPTH := 0.12
## Potholes as (x, distance along, radius), all in metres.
const POTHOLES: Array[Vector3] = [
	Vector3(-1.2, 10.0, 0.5), Vector3(0.8, 16.0, 0.6), Vector3(-0.4, 24.0, 0.45),
	Vector3(1.5, 31.0, 0.7), Vector3(-1.6, 38.0, 0.5), Vector3(0.3, 45.0, 0.55),
	Vector3(-0.8, 52.0, 0.65),
]
const BUMP_HEIGHT := 0.08
const BUMP_LENGTH := 0.9
## Speed bumps across the whole width, centred at these distances along.
const BUMPS: Array[float] = [70.0, 80.0, 90.0, 100.0, 110.0]
const WASHBOARD_START := 120.0
const WASHBOARD_END := 170.0
const WASHBOARD_AMPLITUDE := 0.025
const WASHBOARD_WAVELENGTH := 0.7

# Rutted mud.
## Rut centres match the Rally Car's wheel track (1.52 m).
const RUT_CENTERS: Array[float] = [-0.76, 0.76]
const RUT_HALF_WIDTH := 0.35
const RUT_DEPTH := 0.1
const MUD_WAVE_HEIGHT := 0.04

## How strongly features are shaded: colour x (1 + offset x this), so dips read
## darker and crests lighter from the driver's seat.
const SHADE_PER_METRE := 4.0

@export var surface: SurfaceDef
@export var profile: Profile = Profile.ROUGH_ASPHALT
## Width (x) and length (z) in metres.
@export var size := Vector2(10.0, 200.0)


func _ready() -> void:
	set_meta(SurfaceLookup.META_KEY, surface)
	var columns := int(size.x / SPACING) + 1
	var rows := int(size.y / SPACING) + 1
	var heights := PackedFloat32Array()
	heights.resize(columns * rows)
	for row in rows:
		for column in columns:
			heights[row * columns + column] = height_at(profile, _sample_position(column, row), size)
	_add_collision(columns, rows, heights)
	_add_mesh(columns, rows, heights)


## Height above the surrounding ground at a local (x, z) point of the strip.
static func height_at(which: Profile, point: Vector2, patch_size: Vector2) -> float:
	var along := patch_size.y * 0.5 - point.y  # distance from the entry end
	var ramp := smoothstep(0.0, TAPER, minf(along, patch_size.y - along))
	return maxf(0.0, (BASE_HEIGHT + feature_offset(which, point.x, along)) * ramp)


## How far the features raise (+) or lower (-) the strip from BASE_HEIGHT.
static func feature_offset(which: Profile, x: float, along: float) -> float:
	match which:
		Profile.RUTTED_MUD:
			return rutted_mud_offset(x, along)
		_:
			return rough_asphalt_offset(x, along)


## Rough asphalt: potholes, then speed bumps, then washboard ripples.
static func rough_asphalt_offset(x: float, along: float) -> float:
	var offset := 0.0
	for pothole in POTHOLES:
		var distance := Vector2(x - pothole.x, along - pothole.y).length()
		if distance < pothole.z:
			var t := distance / pothole.z
			offset -= POTHOLE_DEPTH * (1.0 - t * t)  # bowl-shaped
	for bump in BUMPS:
		var t := absf(along - bump) / (BUMP_LENGTH * 0.5)
		if t < 1.0:
			offset += BUMP_HEIGHT * (0.5 + 0.5 * cos(PI * t))
	if along >= WASHBOARD_START and along <= WASHBOARD_END:
		offset += WASHBOARD_AMPLITUDE * sin(TAU * (along - WASHBOARD_START) / WASHBOARD_WAVELENGTH)
	return offset


## Rutted mud: two ruts at wheel-track spacing plus slow waves along the strip.
static func rutted_mud_offset(x: float, along: float) -> float:
	var offset := MUD_WAVE_HEIGHT * sin(along * 0.9)
	for center in RUT_CENTERS:
		var t := absf(x - center) / RUT_HALF_WIDTH
		if t < 1.0:
			offset -= RUT_DEPTH * (0.5 + 0.5 * cos(PI * t))
	return offset


func _sample_position(column: int, row: int) -> Vector2:
	return Vector2(column * SPACING - size.x * 0.5, row * SPACING - size.y * 0.5)


func _add_collision(columns: int, rows: int, heights: PackedFloat32Array) -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = columns
	shape.map_depth = rows
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# The shape puts samples 1 m apart; scaling the node sets the real spacing.
	collision.scale = Vector3(SPACING, 1.0, SPACING)
	add_child(collision)


func _add_mesh(columns: int, rows: int, heights: PackedFloat32Array) -> void:
	var base_color := surface.debug_color
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows:
		for column in columns:
			var point := _sample_position(column, row)
			var along := size.y * 0.5 - point.y
			var shade := clampf(1.0 + feature_offset(profile, point.x, along) * SHADE_PER_METRE, 0.5, 1.3)
			tool.set_color(Color(base_color.r * shade, base_color.g * shade, base_color.b * shade))
			tool.add_vertex(Vector3(point.x, heights[row * columns + column], point.y))
	for row in rows - 1:
		for column in columns - 1:
			var i := row * columns + column
			tool.add_index(i)
			tool.add_index(i + 1)
			tool.add_index(i + columns)
			tool.add_index(i + 1)
			tool.add_index(i + columns + 1)
			tool.add_index(i + columns)
	tool.generate_normals()

	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true  # same colour space as the other surfaces' albedo
	material.roughness = 0.9
	mesh.material_override = material
	add_child(mesh)
