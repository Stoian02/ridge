class_name WaterCourse
extends Node3D
## Raised, closed water comparisons behind the existing Test Ground courses.
## Calm/current share geometry; currents and water never add solid collision.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const SHALLOW_X := 60.0
const CALM_X := 105.0
const CURRENT_X := 155.0
const START_Z := 30.0
const SHALLOW_LENGTH := 100.0
const POOL_LENGTH := 192.0
const SHALLOW_WIDTH := 8.0
const POOL_WIDTH := 32.0
const SHALLOW_LEVEL := 0.37
const POOL_LEVEL := 2.82
const POOL_RIM := 2.92
const BASE := 0.02
const CURRENT := Vector3(0.75, 0.0, 0.0)
const SHALLOW_DEPTHS: Array[float] = [0.05, 0.15, 0.30, 0.35]
const BAY_STARTS: Array[float] = [20.0, 40.0, 60.0, 80.0]
const DEPTH_LABELS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0, 2.5, 2.8]
const POOL_PROFILE: Array[Vector2] = [Vector2(0.0, BASE), Vector2(24.0, POOL_RIM),
	Vector2(28.0, POOL_LEVEL), Vector2(84.0, BASE), Vector2(108.0, BASE),
	Vector2(164.0, POOL_LEVEL), Vector2(168.0, POOL_RIM), Vector2(192.0, BASE)]
## Sample at <=1 m; merge only when all intermediate colour checks stay below
## this tighter bound. The 0.01 acceptance bound leaves float/interpolation room.
const COLOR_ERROR := 0.008
const LABEL_RANGE := 48.0
const TITLE_RANGE := 150.0

static var _cached_pool_rows := PackedFloat32Array()
static var _cached_pool_heights := PackedFloat32Array()

class ColoredFaces:
	var faces := PackedVector3Array()
	var colors := PackedColorArray()

var water_world := WaterWorld.new()
var build_seconds := 0.0
var pool_floor_faces := PackedVector3Array()
var pool_water_faces := PackedVector3Array()
var pool_water_colors := PackedColorArray()
var shallow_floor_faces := PackedVector3Array()
var geometry_primitives := 0
## Opt-in acceptance instrumentation; does not change geometry or animation.
var trace_enabled := false
var trace_usec := 0

var _materials: Array[StandardMaterial3D] = []
var _currents: Array[Vector3] = []


func _ready() -> void:
	build()


func _exit_tree() -> void:
	water_world.clear()


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec() if trace_enabled else 0
	for i: int in _materials.size():
		WaterAppearance.advance(_materials[i], _currents[i], delta)
	if trace_enabled:
		trace_usec = Time.get_ticks_usec() - started


func build() -> void:
	var start := Time.get_ticks_usec()
	water_world.clear()
	for child: Node in get_children():
		child.free()
	_materials.clear()
	_currents.clear()
	geometry_primitives = 0
	var bed_material := StandardMaterial3D.new()
	bed_material.albedo_color = ASPHALT.debug_color
	bed_material.roughness = 0.9
	var calm_material := WaterAppearance.make_material(Color.WHITE, true)
	var current_material := WaterAppearance.make_material(Color.WHITE, true)
	_materials.assign([calm_material, current_material])
	_currents.assign([Vector3.ZERO, CURRENT])

	var pool_rows := _pool_rows()
	pool_floor_faces = _floor_faces(pool_rows, 6.0, 16.0, false)
	var pool_solid := _closed_faces(pool_floor_faces, 6.0, 16.0, POOL_LENGTH, false)
	var pool_bed_mesh := _mesh(pool_solid)
	var wet_rows := PackedFloat32Array()
	for row: float in pool_rows:
		if row >= 28.0 and row <= 164.0:
			wet_rows.append(row)
	var pool_data := _water_data(wet_rows, 6.0, 16.0, POOL_LEVEL, POOL_RIM, false)
	pool_water_faces = pool_data.faces
	pool_water_colors = pool_data.colors
	var pool_mesh := _mesh(pool_data.faces, pool_data.colors)
	for index: int in 2:
		var center_x: float = CALM_X if index == 0 else CURRENT_X
		var section_name: String = "Calm" if index == 0 else "Current"
		var offset := Vector3(center_x, 0.0, START_Z)
		_add_bed(section_name + "Bed", pool_bed_mesh, pool_solid, offset, bed_material)
		_add_mesh(section_name + "Water", pool_mesh,
			calm_material if index == 0 else current_material, offset)
		_register(StringName("test_" + section_name.to_lower()), pool_data.faces,
			pool_floor_faces, offset, Vector3.ZERO if index == 0 else CURRENT)

	var shallow_rows := PackedFloat32Array([0.0, 8.0])
	for index: int in BAY_STARTS.size():
		shallow_rows.append_array(_shallow_bay_rows(index))
	shallow_rows.append(SHALLOW_LENGTH)
	shallow_floor_faces = _floor_faces(shallow_rows, 3.8, 4.0, true)
	var shallow_solid := _closed_faces(shallow_floor_faces, 3.8, 4.0, SHALLOW_LENGTH, true)
	var shallow_offset := Vector3(SHALLOW_X, 0.0, START_Z)
	_add_bed("ShallowBed", _mesh(shallow_solid), shallow_solid, shallow_offset, bed_material)
	var shallow_data := ColoredFaces.new()
	for index: int in BAY_STARTS.size():
		var rows := _shallow_bay_rows(index)
		var data := _water_data(rows, 3.8, 4.0, SHALLOW_LEVEL, SHALLOW_LEVEL, true)
		shallow_data.faces.append_array(data.faces)
		shallow_data.colors.append_array(data.colors)
		_register(StringName("test_shallow_%d" % roundi(SHALLOW_DEPTHS[index] * 100.0)),
			data.faces, shallow_floor_faces, shallow_offset, Vector3.ZERO)
	_add_mesh("ShallowWater", _mesh(shallow_data.faces, shallow_data.colors),
		calm_material, shallow_offset)
	_add_markings()
	_add_signs()
	build_seconds = (Time.get_ticks_usec() - start) / 1000000.0


func _register(id: StringName, top: PackedVector3Array, bed: PackedVector3Array,
		offset: Vector3, current: Vector3) -> void:
	var def := WaterBodyDef.new()
	def.id = id
	def.current_velocity = current
	def.color = WaterAppearance.SHALLOW
	water_world.add_body(def, top, bed, global_transform * Transform3D(Basis.IDENTITY, offset))


## The exact centre-line profile before triangulation. One metre of easing on
## each side of a slope change makes its complete transition two metres long.
static func pool_center_height(along: float) -> float:
	var s := clampf(along, 0.0, POOL_LENGTH)
	for index: int in POOL_PROFILE.size() - 1:
		var a := POOL_PROFILE[index]
		var b := POOL_PROFILE[index + 1]
		if s > b.x:
			continue
		var length := b.x - a.x
		var distance := s - a.x
		var fraction := (distance - 0.5) / (length - 1.0)
		if distance < 1.0:
			fraction = distance * distance / (2.0 * (length - 1.0))
		elif distance > length - 1.0:
			fraction = 1.0 - (length - distance) * (length - distance) / (2.0 * (length - 1.0))
		return lerpf(a.y, b.y, fraction)
	return BASE


static func shallow_center_height(along: float) -> float:
	if along < 8.0:
		return lerpf(BASE, SHALLOW_LEVEL, clampf(along / 8.0, 0.0, 1.0))
	if along > 92.0:
		return lerpf(SHALLOW_LEVEL, BASE, clampf((along - 92.0) / 8.0, 0.0, 1.0))
	for index: int in BAY_STARTS.size():
		var distance := along - BAY_STARTS[index]
		if distance >= 0.0 and distance <= 12.0:
			var fraction := clampf(minf(distance, 12.0 - distance) / 3.0, 0.0, 1.0)
			return SHALLOW_LEVEL - SHALLOW_DEPTHS[index] * fraction
	return SHALLOW_LEVEL


## Triangle-interpolated, not bilinear: this is the same diagonal and vertex
## heights as the rendered/colliding floor. Used for labels and verification.
static func pool_floor_height(across: float, along: float) -> float:
	var rows := _pool_rows()
	var low := 0
	var high := rows.size() - 1
	while high - low > 1:
		var middle := (low + high) / 2
		if along <= rows[middle]:
			high = middle
		else:
			low = middle
	return _row_height(across, along, rows[low], rows[high],
		_cached_pool_heights[low], _cached_pool_heights[high], 6.0, 16.0, POOL_RIM)


static func _pool_rows() -> PackedFloat32Array:
	if not _cached_pool_rows.is_empty():
		return _cached_pool_rows
	var rows := PackedFloat32Array([0.0, 0.5, 1.0, 23.0, 23.5, 24.0,
		24.5, 25.0, 27.0, 27.5, 28.0, 28.5])
	for station: int in range(29, 84):
		rows.append(float(station))
	rows.append_array([83.5, 84.0, 108.0, 108.5])
	for station: int in range(109, 164):
		rows.append(float(station))
	rows.append_array([163.5, 164.0, 164.5, 165.0, 167.0, 167.5,
		168.0, 168.5, 169.0, 191.0, 191.5, 192.0])
	# Exact 5 cm centre-depth stations are also vertices, so the centre strip
	# never stretches the shoreline fade over its entire first one-metre cell.
	var fade_station := 28.5 + 55.0 * 0.05 / 2.8
	rows.append_array([fade_station, POOL_LENGTH - fade_station])
	rows.sort()
	_cached_pool_rows = rows
	for station: float in rows:
		_cached_pool_heights.append(pool_center_height(station))
	return rows


static func _shallow_bay_rows(index: int) -> PackedFloat32Array:
	var start := BAY_STARTS[index]
	var fade_run := 3.0 * 0.05 / SHALLOW_DEPTHS[index]
	var source := PackedFloat32Array([start, start + 1.0, start + 2.0, start + 3.0,
		start + 9.0, start + 10.0, start + 11.0, start + 12.0,
		start + fade_run, start + 12.0 - fade_run])
	source.sort()
	var rows := PackedFloat32Array()
	for station: float in source:
		if rows.is_empty() or station - rows[rows.size() - 1] > 0.00001:
			rows.append(station)
	return rows


static func _center_height(along: float, shallow: bool) -> float:
	return shallow_center_height(along) if shallow else pool_center_height(along)


static func _edge_height(along: float, shallow: bool) -> float:
	if shallow:
		return SHALLOW_LEVEL if along >= 8.0 and along <= 92.0 else shallow_center_height(along)
	return POOL_RIM


static func _floor_faces(rows: PackedFloat32Array, flat: float, half: float,
		shallow: bool) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var across: Array[float] = [-half, -flat, flat, half]
	for row: int in rows.size() - 1:
		for column: int in [0, 2]:
			var x0 := across[column]
			var x1 := across[column + 1]
			var z0 := rows[row]
			var z1 := rows[row + 1]
			var a := Vector3(x0, _edge_height(z0, shallow) if column == 0 else _center_height(z0, shallow), z0)
			var b := Vector3(x1, _edge_height(z0, shallow) if column == 2 else _center_height(z0, shallow), z0)
			var c := Vector3(x0, _edge_height(z1, shallow) if column == 0 else _center_height(z1, shallow), z1)
			var d := Vector3(x1, _edge_height(z1, shallow) if column == 2 else _center_height(z1, shallow), z1)
			faces.append_array([a, b, c, b, d, c])
	# The central strip is flat across. Straight longitudinal sections are one
	# plane, so retain their endpoints and all easing/profile breaks instead of
	# redrawing the same plane once per bank-sampling row. The bank triangles stay
	# untouched; rendered and physical faces still come from this one array.
	var row := 0
	while row < rows.size() - 1:
		var last := row + 1
		var height := _center_height(rows[row], shallow)
		var slope := (_center_height(rows[last], shallow) - height) / (rows[last] - rows[row])
		while last + 1 < rows.size():
			var expected := height + slope * (rows[last + 1] - rows[row])
			if absf(_center_height(rows[last + 1], shallow) - expected) > 0.000000001:
				break
			last += 1
		var end_height := _center_height(rows[last], shallow)
		var a := Vector3(-flat, height, rows[row])
		var b := Vector3(flat, height, rows[row])
		var c := Vector3(-flat, end_height, rows[last])
		var d := Vector3(flat, end_height, rows[last])
		faces.append_array([a, b, c, b, d, c])
		row = last
	return faces


static func _closed_faces(top: PackedVector3Array, flat: float, half: float,
		length: float, shallow: bool) -> PackedVector3Array:
	var faces := top.duplicate()
	var edge_rows: PackedFloat32Array = PackedFloat32Array([0.0, 8.0, 92.0, 100.0]) if shallow else PackedFloat32Array([0.0, length])
	for side: float in [-1.0, 1.0]:
		for row: int in edge_rows.size() - 1:
			var z0 := edge_rows[row]
			var z1 := edge_rows[row + 1]
			_quad_faces(faces, Vector3(side * half, 0.0, z0),
				Vector3(side * half, _edge_height(z0, shallow), z0),
				Vector3(side * half, _edge_height(z1, shallow), z1),
				Vector3(side * half, 0.0, z1), Vector3.RIGHT * side)
	var across: Array[float] = [-half, -flat, flat, half]
	for z: float in [0.0, length]:
		for column: int in 3:
			var x0 := across[column]
			var x1 := across[column + 1]
			_quad_faces(faces, Vector3(x0, 0.0, z), Vector3(x1, 0.0, z),
				Vector3(x1, _edge_height(z, shallow) if column == 2 else _center_height(z, shallow), z),
				Vector3(x0, _edge_height(z, shallow) if column == 0 else _center_height(z, shallow), z),
				Vector3.BACK if z > 0.0 else Vector3.FORWARD)
	_quad_faces(faces, Vector3(-half, 0.0, 0.0), Vector3(half, 0.0, 0.0),
		Vector3(half, 0.0, length), Vector3(-half, 0.0, length), Vector3.DOWN)
	return faces


static func _quad_faces(faces: PackedVector3Array, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, normal: Vector3) -> void:
	if (b - a).cross(c - a).dot(normal) > 0.0:
		faces.append_array([a, c, b, a, d, c])
	else:
		faces.append_array([a, b, c, a, c, d])


static func _row_height(x: float, z: float, z0: float, z1: float,
		h0: float, h1: float, flat: float, half: float, rim: float) -> float:
	var v := clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	if absf(x) <= flat:
		return lerpf(h0, h1, v)
	if x < 0.0:
		var u := (x + half) / (half - flat)
		return rim + (h0 - rim) * u if u + v <= 1.0 else h1 + (h0 - h1) * (1.0 - v) + (rim - h1) * (1.0 - u)
	var u := (x - flat) / (half - flat)
	return h0 + (rim - h0) * u + (h1 - h0) * v if u + v <= 1.0 else rim + (h1 - rim) * (1.0 - u)


static func _water_data(rows: PackedFloat32Array, flat: float, half: float,
		level: float, rim: float, shallow: bool) -> ColoredFaces:
	var data := ColoredFaces.new()
	var row := 0
	while row < rows.size() - 1:
		var end_row := row + 1
		var first := WaterAppearance.pool_color(level - _center_height(rows[row], shallow))
		if first == WaterAppearance.pool_color(level - _center_height(rows[end_row], shallow)):
			while end_row + 1 < rows.size() and first == WaterAppearance.pool_color(level - _center_height(rows[end_row + 1], shallow)):
				end_row += 1
		_append_rect(data, -flat, flat, rows[row], rows[end_row], level,
			[first, first, WaterAppearance.pool_color(level - _center_height(rows[end_row], shallow)),
			WaterAppearance.pool_color(level - _center_height(rows[end_row], shallow))])
		row = end_row
	var heights := PackedFloat32Array()
	for station: float in rows:
		heights.append(_center_height(station, shallow))
	for side: float in [-1.0, 1.0]:
		_bank_water(data, side, rows, heights, flat, half, level, rim)
	return data


static func _bank_water(data: ColoredFaces, side: float, rows: PackedFloat32Array,
		heights: PackedFloat32Array, flat: float, half: float, level: float, rim: float) -> void:
	var start_x: float = -half if side < 0.0 else flat
	var end_x: float = -flat if side < 0.0 else half
	var x := start_x
	while x < end_x - 0.00001:
		var end := minf(x + 1.0, end_x)
		var row := 0
		while row < rows.size() - 1:
			var z0 := rows[row]
			var z1 := rows[row + 1]
			var h0 := heights[row]
			var h1 := heights[row + 1]
			var depths: Array[float] = []
			for point: Vector2 in [Vector2(x, z0), Vector2(end, z0), Vector2(x, z1), Vector2(end, z1)]:
				depths.append(level - _row_height(point.x, point.y, z0, z1, h0, h1, flat, half, rim))
			if depths.max() <= 0.000001:
				row += 1
				continue
			if depths.min() < 0.05:
				_shore_cell(data, x, end, side, z0, z1, h0, h1, flat, half, level, rim)
				row += 1
				continue
			# Longitudinal simplification keeps the exact clipped shoreline cells
			# and all solid bed triangles. Every original <=1m row, plus interior
			# sub-samples, must fit the same 0.008 RGBA bound before a span merges.
			var last := row + 1
			if _grid_rectangle_fits(x, end, rows, heights, row, last, flat, half, level, rim):
				for span: int in [2, 4, 8, 16]:
					var candidate := mini(row + span, rows.size() - 1)
					if candidate == last:
						break
					if not _grid_rectangle_fits(x, end, rows, heights, row, candidate, flat, half, level, rim):
						break
					last = candidate
				_water_rect(data, x, end, z0, rows[last], h0, heights[last], flat, half, level, rim)
			else:
				var middle := (x + end) * 0.5
				_water_rect(data, x, middle, z0, z1, h0, h1, flat, half, level, rim)
				_water_rect(data, middle, end, z0, z1, h0, h1, flat, half, level, rim)
			row = last
		x = end


static func _grid_rectangle_fits(x0: float, x1: float, rows: PackedFloat32Array,
		heights: PackedFloat32Array, first: int, last: int, flat: float, half: float,
		level: float, rim: float) -> bool:
	var colors := _rect_colors(x0, x1, rows[first], rows[last], heights[first], heights[last], flat, half, level, rim)
	for row: int in range(first, last):
		for u: float in [0.0, 0.5, 1.0]:
			var x := lerpf(x0, x1, u)
			for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
				var z := lerpf(rows[row], rows[row + 1], fraction)
				var depth := level - _row_height(x, z, rows[row], rows[row + 1], heights[row], heights[row + 1], flat, half, rim)
				if depth < 0.05 - 0.000001:
					return false
				var v := (z - rows[first]) / (rows[last] - rows[first])
				var expected := WaterAppearance.pool_color(depth)
				var interpolated: Color = colors[0] + (colors[1] - colors[0]) * u + (colors[2] - colors[0]) * v if u + v <= 1.0 else colors[3] + (colors[1] - colors[3]) * (1.0 - v) + (colors[2] - colors[3]) * (1.0 - u)
				if _color_error(expected, interpolated) > COLOR_ERROR:
					return false
	return true


static func _color_error(a: Color, b: Color) -> float:
	return maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), maxf(absf(a.b - b.b), absf(a.a - b.a)))


static func _rect_colors(x0: float, x1: float, z0: float, z1: float, h0: float,
		h1: float, flat: float, half: float, level: float, rim: float) -> Array[Color]:
	var colors: Array[Color] = []
	for point: Vector2 in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x0, z1), Vector2(x1, z1)]:
		colors.append(WaterAppearance.pool_color(level - _row_height(point.x, point.y, z0, z1, h0, h1, flat, half, rim)))
	return colors


static func _water_rect(data: ColoredFaces, x0: float, x1: float, z0: float,
		z1: float, h0: float, h1: float, flat: float, half: float, level: float, rim: float) -> void:
	_append_rect(data, x0, x1, z0, z1, level,
		_rect_colors(x0, x1, z0, z1, h0, h1, flat, half, level, rim))


static func _append_rect(data: ColoredFaces, x0: float, x1: float, z0: float,
		z1: float, level: float, colors: Array[Color]) -> void:
	var points: Array[Vector3] = [Vector3(x0, level, z0), Vector3(x1, level, z0),
		Vector3(x0, level, z1), Vector3(x1, level, z1)]
	for index: int in [0, 1, 2, 1, 3, 2]:
		data.faces.append(points[index])
		data.colors.append(colors[index])


## Only shoreline cells need this more detailed path. Clipping the actual bed
## triangles preserves the exact bank/bed intersections and the 5 cm alpha fade,
## even where the bank's two planes meet. It never expands onto dry asphalt.
static func _shore_cell(data: ColoredFaces, x0: float, x1: float, side: float,
		z0: float, z1: float, h0: float, h1: float, flat: float, half: float,
		level: float, rim: float) -> void:
	var left: float = -half if side < 0.0 else flat
	var right: float = -flat if side < 0.0 else half
	var a := Vector3(left, rim if side < 0.0 else h0, z0)
	var b := Vector3(right, h0 if side < 0.0 else rim, z0)
	var c := Vector3(left, rim if side < 0.0 else h1, z1)
	var d := Vector3(right, h1 if side < 0.0 else rim, z1)
	for triangle: PackedVector3Array in [PackedVector3Array([a, b, c]), PackedVector3Array([b, d, c])]:
		var clipped := _clip(_clip(triangle, 0, x0, false), 0, x1, true)
		for limits: Vector2 in [Vector2(0.0, 0.05), Vector2(0.05, 0.20), Vector2(0.20, 100.0)]:
			var band := _clip(_clip(clipped, 1, level - limits.x, true), 1, level - limits.y, false)
			for index: int in range(1, band.size() - 1):
				var p := band[0]
				var q := band[index]
				var r := band[index + 1]
				if absf((q.x - p.x) * (r.z - p.z) - (q.z - p.z) * (r.x - p.x)) < 0.000001:
					continue
				for vertex: Vector3 in [p, q, r]:
					data.faces.append(Vector3(vertex.x, level, vertex.z))
					data.colors.append(WaterAppearance.pool_color(level - vertex.y))


static func _clip(polygon: PackedVector3Array, axis: int, bound: float,
		keep_less: bool) -> PackedVector3Array:
	var result := PackedVector3Array()
	if polygon.is_empty():
		return result
	var previous := polygon[polygon.size() - 1]
	var was_inside: bool = previous[axis] <= bound if keep_less else previous[axis] >= bound
	for point: Vector3 in polygon:
		var inside: bool = point[axis] <= bound if keep_less else point[axis] >= bound
		if inside != was_inside:
			result.append(previous.lerp(point, (bound - previous[axis]) / (point[axis] - previous[axis])))
		if inside:
			result.append(point)
		previous = point
		was_inside = inside
	return result


static func _mesh(faces: PackedVector3Array, colors: PackedColorArray = PackedColorArray()) -> ArrayMesh:
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	normals.resize(faces.size())
	uvs.resize(faces.size())
	for index: int in range(0, faces.size(), 3):
		var normal := (faces[index + 2] - faces[index]).cross(faces[index + 1] - faces[index]).normalized()
		for corner: int in 3:
			normals[index + corner] = normal
			uvs[index + corner] = Vector2(faces[index + corner].x, faces[index + corner].z) * WaterAppearance.TEXTURE_SCALE
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_bed(node_name: String, mesh: ArrayMesh, faces: PackedVector3Array,
		offset: Vector3, material: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = offset
	body.set_meta(SurfaceLookup.META_KEY, ASPHALT)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	collision.shape = shape
	body.add_child(collision)
	var instance := MeshInstance3D.new()
	instance.name = "Ground"
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(instance)
	add_child(body)
	geometry_primitives += faces.size() / 3


func _add_mesh(node_name: String, mesh: ArrayMesh, material: StandardMaterial3D,
		offset: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	geometry_primitives += mesh.get_faces().size() / 3


func _add_markings() -> void:
	var faces := PackedVector3Array()
	for center: float in [CALM_X, CURRENT_X]:
		for index: int in range(1, 13):
			var depth := minf(index * 0.25, 2.8)
			var along := _depth_station(depth)
			var x := center - 15.7
			var y := pool_floor_height(-15.7, along) + 0.015
			_quad_faces(faces, Vector3(x - 0.18, y, START_Z + along - 0.06),
				Vector3(x + 0.18, y, START_Z + along - 0.06),
				Vector3(x + 0.18, y, START_Z + along + 0.06),
				Vector3(x - 0.18, y, START_Z + along + 0.06), Vector3.UP)
	# Painted current arrow lies on the dry rim, not floating over the driving line.
	var arrow := Vector3(CURRENT_X - 15.1, POOL_RIM + 0.02, START_Z + 24.0)
	_quad_faces(faces, arrow + Vector3(0.0, 0.0, -0.16), arrow + Vector3(2.0, 0.0, -0.16),
		arrow + Vector3(2.0, 0.0, 0.16), arrow + Vector3(0.0, 0.0, 0.16), Vector3.UP)
	faces.append_array([arrow + Vector3(2.0, 0.0, -0.55), arrow + Vector3(2.8, 0.0, 0.0),
		arrow + Vector3(2.0, 0.0, 0.55)])
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.90, 0.62)
	material.roughness = 0.9
	_add_mesh("DepthTicksAndFlowArrow", _mesh(faces), material, Vector3.ZERO)


func _add_signs() -> void:
	_label("WATER TESTS\nBehind + right of spawn", Vector3(12.0, 2.7, 12.0), 48, 45.0)
	_label("SHALLOW BAYS", Vector3(SHALLOW_X + 6.0, 2.4, START_Z + 6.0), 72, TITLE_RANGE)
	# Visible on the approach, over the bank rather than outside the camera's
	# view at the full 32 m basin width. No sign sits over the central lane.
	_label("CALM POOL", Vector3(CALM_X - 10.0, 4.0, START_Z + 6.0), 96, TITLE_RANGE)
	_label("CURRENT POOL\n0.75 m/s cross-current", Vector3(CURRENT_X - 10.0, 4.0, START_Z + 6.0), 80, TITLE_RANGE)
	for index: int in BAY_STARTS.size():
		_label("%.2f m" % SHALLOW_DEPTHS[index],
			Vector3(SHALLOW_X + 5.5, 1.3, START_Z + BAY_STARTS[index] + 6.0), 48, LABEL_RANGE)
	for center: float in [CALM_X, CURRENT_X]:
		_label("CENTRE DEPTH", Vector3(center - 17.5, 3.8, START_Z + 26.0), 36, LABEL_RANGE)
		for depth: float in DEPTH_LABELS:
			_label("%s m" % str(depth), Vector3(center - 17.5, 3.6, START_Z + _depth_station(depth)), 42, LABEL_RANGE)


static func _depth_station(depth: float) -> float:
	if depth >= 2.8:
		return 84.0
	var low := 28.0
	var high := 84.0
	for _step: int in 20:
		var middle := (low + high) * 0.5
		if POOL_LEVEL - pool_center_height(middle) < depth:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


func _label(text: String, at: Vector3, size: int, distance: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.01
	label.outline_size = 8
	label.modulate = Color(1.0, 0.95, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.visibility_range_end = distance
	label.position = at
	add_child(label)
