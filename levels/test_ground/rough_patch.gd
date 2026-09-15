class_name RoughPatch
extends StaticBody3D
## A drivable strip of uneven ground: a heightmap collision shape plus a matching
## mesh, both built from one height function. The strip rises from ground level to
## BASE_HEIGHT over its first and last few metres so cars can drive on and off;
## the features (potholes, bumps, ruts...) are carved into that raised base.
## Local axes: x across the strip, z along it. Cars enter at the +Z end.

enum Profile { ROUGH_ASPHALT, RUTTED_MUD, SIDE_SLOPE, TWISTER, WHOOPS }

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

# Side slope: drive along it; the ground rises across the strip toward -X, and its
# tilt grows from flat to SLOPE_MAX_DEG, to see where each car starts sliding down.
## Flat distance at the entry end (m).
const SLOPE_FLAT := 10.0
## Distance at the far end held at the steepest tilt (m).
const SLOPE_HOLD := 20.0
const SLOPE_MAX_DEG := 40.0

# Axle twister: round humps on alternating wheel lines, so one wheel at a time
# climbs while the others stay down.
const TWISTER_START := 8.0
const TWISTER_SPACING := 4.0
## Humps sit this far either side of the centre line, on a wheel line (m).
const TWISTER_OFFSET := 0.8
const TWISTER_HEIGHT := 0.35
const TWISTER_RADIUS := 1.4

# Whoops: rollers across the whole width, for bouncing and damping at speed.
const WHOOPS_START := 10.0
const WHOOP_WAVELENGTH := 5.0
const WHOOP_HEIGHT := 0.4

## Side walls reach this far below the ground (m), so no gap shows where they meet it.
const WALL_DEPTH := 0.05
## Side walls are the surface colour darkened by this factor.
const WALL_SHADE := 0.6
## A wall quad's corners are top a, top b, bottom a, bottom b; its triangles, facing each way.
const WALL_FRONT: Array[int] = [0, 1, 2, 1, 3, 2]
const WALL_BACK: Array[int] = [0, 2, 1, 1, 2, 3]

## How strongly features are shaded: colour x (1 + offset x this), so dips read
## darker and crests lighter from the driver's seat.
const SHADE_PER_METRE := 4.0

@export var surface: SurfaceDef
@export var profile: Profile = Profile.ROUGH_ASPHALT
## Width (x) and length (z) in metres.
@export var size := Vector2(10.0, 200.0)
## Metres between height samples; long, smooth strips can use coarser samples.
@export var spacing := SPACING


func _ready() -> void:
	set_meta(SurfaceLookup.META_KEY, surface)
	var columns := int(size.x / spacing) + 1
	var rows := int(size.y / spacing) + 1
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
	return maxf(0.0, (BASE_HEIGHT + feature_offset(which, point.x, along, patch_size)) * ramp)


## How far the features raise (+) or lower (-) the strip from BASE_HEIGHT.
static func feature_offset(which: Profile, x: float, along: float, patch_size: Vector2) -> float:
	match which:
		Profile.RUTTED_MUD:
			return rutted_mud_offset(x, along)
		Profile.SIDE_SLOPE:
			return (patch_size.x * 0.5 - x) * tan(deg_to_rad(slope_angle_deg(along, patch_size.y)))
		Profile.TWISTER:
			return twister_offset(x, along, patch_size.y)
		Profile.WHOOPS:
			return whoops_offset(along, patch_size.y)
		_:
			return rough_asphalt_offset(x, along)


## The side slope's tilt (degrees) `along` metres from the entry end of a strip `length` long.
static func slope_angle_deg(along: float, length: float) -> float:
	var rise := length - SLOPE_HOLD - SLOPE_FLAT
	return clampf((along - SLOPE_FLAT) / rise, 0.0, 1.0) * SLOPE_MAX_DEG


## Where along a side slope `length` long its tilt reaches `degrees` (for markers).
static func slope_distance_for(degrees: float, length: float) -> float:
	return SLOPE_FLAT + degrees / SLOPE_MAX_DEG * (length - SLOPE_HOLD - SLOPE_FLAT)


## Axle twister: domes on alternating wheel lines, left first, TWISTER_SPACING apart,
## kept TWISTER_START clear of both ends.
static func twister_offset(x: float, along: float, length: float) -> float:
	var nearest := roundi((along - TWISTER_START) / TWISTER_SPACING)
	var offset := 0.0
	for index in range(nearest - 1, nearest + 2):
		var hump_along := TWISTER_START + index * TWISTER_SPACING
		if index < 0 or hump_along > length - TWISTER_START:
			continue
		var side := -1.0 if index % 2 == 0 else 1.0
		var distance := Vector2(x - side * TWISTER_OFFSET, along - hump_along).length()
		offset += RoughShapes.pothole(distance, TWISTER_RADIUS, -TWISTER_HEIGHT)
	return offset


## Whoops: whole rollers from WHOOPS_START, ending at least WHOOPS_START before the far end.
static func whoops_offset(along: float, length: float) -> float:
	var rollers := floori((length - 2.0 * WHOOPS_START) / WHOOP_WAVELENGTH)
	var into := along - WHOOPS_START
	if into < 0.0 or into > rollers * WHOOP_WAVELENGTH:
		return 0.0
	return WHOOP_HEIGHT * 0.5 * (1.0 - cos(TAU * into / WHOOP_WAVELENGTH))


## Rough asphalt: potholes, then speed bumps, then washboard ripples.
static func rough_asphalt_offset(x: float, along: float) -> float:
	var offset := 0.0
	for pothole in POTHOLES:
		var distance := Vector2(x - pothole.x, along - pothole.y).length()
		offset += RoughShapes.pothole(distance, pothole.z, POTHOLE_DEPTH)
	for bump in BUMPS:
		offset += RoughShapes.bump(along - bump, BUMP_LENGTH, BUMP_HEIGHT)
	if along >= WASHBOARD_START and along <= WASHBOARD_END:
		offset += RoughShapes.washboard(along - WASHBOARD_START, WASHBOARD_AMPLITUDE, WASHBOARD_WAVELENGTH)
	return offset


## Rutted mud: two ruts at wheel-track spacing plus slow waves along the strip.
static func rutted_mud_offset(x: float, along: float) -> float:
	var offset := MUD_WAVE_HEIGHT * sin(along * 0.9)
	for center in RUT_CENTERS:
		offset += RoughShapes.rut(x - center, RUT_HALF_WIDTH, RUT_DEPTH)
	return offset


func _sample_position(column: int, row: int) -> Vector2:
	return Vector2(column * spacing - size.x * 0.5, row * spacing - size.y * 0.5)


func _add_collision(columns: int, rows: int, heights: PackedFloat32Array) -> void:
	var shape := HeightMapShape3D.new()
	shape.map_width = columns
	shape.map_depth = rows
	shape.map_data = heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# The shape puts samples 1 m apart; scaling the node sets the real spacing.
	collision.scale = Vector3(spacing, 1.0, spacing)
	add_child(collision)


func _add_mesh(columns: int, rows: int, heights: PackedFloat32Array) -> void:
	var base_color := surface.debug_color
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in rows:
		for column in columns:
			var point := _sample_position(column, row)
			var along := size.y * 0.5 - point.y
			# A side slope's height is its tilt, not a feature, so it isn't shaded by it.
			var feature := 0.0 if profile == Profile.SIDE_SLOPE else feature_offset(profile, point.x, along, size)
			var shade := clampf(1.0 + feature * SHADE_PER_METRE, 0.5, 1.3)
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
	_add_walls(tool, columns, rows, heights, Color(base_color.r * WALL_SHADE, base_color.g * WALL_SHADE,
			base_color.b * WALL_SHADE))
	tool.generate_normals()

	var mesh := MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true  # same colour space as the other surfaces' albedo
	material.roughness = 0.9
	mesh.material_override = material
	add_child(mesh)


## Solid walls down every raised edge of the strip, from its top to just below the
## ground, so its sides never show a gap. Each wall is built facing both ways, with
## its own vertices, so it is lit from either side.
func _add_walls(tool: SurfaceTool, columns: int, rows: int, heights: PackedFloat32Array, color: Color) -> void:
	var next_vertex := columns * rows
	var edges: Array[Array] = []
	for row: int in [0, rows - 1]:
		var edge: Array[Vector2i] = []
		for column in columns:
			edge.append(Vector2i(column, row))
		edges.append(edge)
	for column: int in [0, columns - 1]:
		var edge: Array[Vector2i] = []
		for row in rows:
			edge.append(Vector2i(column, row))
		edges.append(edge)
	for edge: Array in edges:
		for k in edge.size() - 1:
			var a: Vector2i = edge[k]
			var b: Vector2i = edge[k + 1]
			var a_height := heights[a.y * columns + a.x]
			var b_height := heights[b.y * columns + b.x]
			if a_height <= 0.001 and b_height <= 0.001:
				continue
			var a_point := _sample_position(a.x, a.y)
			var b_point := _sample_position(b.x, b.y)
			var corners: Array[Vector3] = [Vector3(a_point.x, a_height, a_point.y), Vector3(b_point.x, b_height, b_point.y),
					Vector3(a_point.x, -WALL_DEPTH, a_point.y), Vector3(b_point.x, -WALL_DEPTH, b_point.y)]
			# One quad per facing: top a, top b, bottom a, bottom b.
			for facing in 2:
				for corner in corners:
					tool.set_color(color)
					tool.add_vertex(corner)
				for offset: int in (WALL_FRONT if facing == 0 else WALL_BACK):
					tool.add_index(next_vertex + offset)
				next_vertex += 4
