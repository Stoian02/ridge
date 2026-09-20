class_name ShelfBuilder
extends Node3D
## Closed, colliding left-hand rock cuts and exposed roadbed sides.
## These are local additions; the terrain corridor still protects every road.

const ROCK := preload("res://surfaces/rock.tres")
const CHUNK_LENGTH := 40.0
const WALL_STEP := 2.0
const EDGE_GAP := 0.20
const VIEW_DISTANCE := 220.0
const STRATA_COLORS: Array[Color] = [Color(0.58, 0.35, 0.24), Color(0.65, 0.43, 0.30),
	Color(0.72, 0.49, 0.33), Color(0.57, 0.36, 0.27), Color(0.67, 0.44, 0.30)]

var wall_chunks := 0
var gravel_chunks := 0
var _rock_noise := FastNoiseLite.new()


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	wall_chunks = 0
	gravel_chunks = 0
	_rock_noise.seed = trail.seed + 1301
	_rock_noise.frequency = 0.13
	_rock_noise.fractal_octaves = 3
	for section: Vector4 in trail.shelf_walls:
		var from := section.x
		var end := minf(section.x + section.y, sampler.length - 1.0)
		while from < end:
			var to := minf(from + CHUNK_LENGTH, end)
			_wall(sampler, profile, field, section, from, to)
			from = to
		_subsoil(sampler, field, section)
	var has_gravel := false
	for def: TalusDef in trail.talus:
		has_gravel = has_gravel or def.gravel_bed
	if not has_gravel:
		return
	var rows := RoadBuilder.row_distances(sampler.length, profile, trail)
	var laterals: Array[float] = []
	for station: Vector2 in RoadBuilder.cross_section(trail):
		if int(station.y) == RoadBuilder.Part.ROAD and not laterals.has(station.x):
			laterals.append(station.x)
	for def: TalusDef in trail.talus:
		if def.gravel_bed:
			_roadbed(sampler, profile, field, def, rows, laterals)


func _wall(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		section: Vector4, from: float, to: float) -> void:
	var mesh := StructureMesh.new()
	var before := _ring(sampler, profile, field, section, from)
	_cap(mesh, before, false)
	var distance := from
	while distance < to:
		distance = minf(to, distance + WALL_STEP)
		var after := _ring(sampler, profile, field, section, distance)
		for i in before.size():
			var j := (i + 1) % before.size()
			var shade := _rock_noise.get_noise_2d(distance * 0.8, i * 11.0) * 0.10
			var color: Color = STRATA_COLORS[i % STRATA_COLORS.size()].lightened(shade)
			mesh.triangle(before[i], after[i], after[j], color)
			mesh.triangle(before[i], after[j], before[j], color.lightened(shade * 0.3))
		before = after
	_cap(mesh, before, true)
	var instance := mesh.add_to(self, "LeftCut%d" % wall_chunks, ROCK, false)
	instance.visibility_range_end = VIEW_DISTANCE
	wall_chunks += 1


## A closed cross-section, from the buried road-facing toe to the hillside seam.
func _ring(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		section: Vector4, distance: float) -> PackedVector3Array:
	var half := sampler.half_width_at(distance)
	var toe := sampler.surface_point(distance, -half - EDGE_GAP, profile)
	var across := sampler.right(distance)
	var outward := -Vector3(across.x, 0.0, across.z).normalized()
	var weight := minf(smoothstep(section.x, section.x + 16.0, distance),
			1.0 - smoothstep(section.x + section.y - 16.0, section.x + section.y, distance))
	var height := section.z * weight * (1.0 + 0.32 * _rock_noise.get_noise_2d(distance, 83.0))
	var back := toe + outward * section.w
	back.y = field.height_at(back.x, back.z) + 0.03
	var floor := minf(minf(field.height_at(toe.x, toe.z), toe.y), back.y) - 1.0
	var ring := PackedVector3Array([Vector3(toe.x, floor, toe.z), toe])
	# Broken sandstone beds: alternating faces, small ledges and recesses.
	# All relief stays outside the accepted driving width, including overhangs.
	var strata: Array[Vector2] = [Vector2(0.10, 0.25), Vector2(0.24, 0.40),
		Vector2(0.27, 0.95), Vector2(0.43, 1.10), Vector2(0.47, 0.80),
		Vector2(0.62, 1.65), Vector2(0.65, 2.15), Vector2(0.82, 2.25),
		Vector2(0.86, 1.95), Vector2(1.0, 3.10)]
	for i in strata.size():
		var noise := _rock_noise.get_noise_2d(distance, i * 17.0)
		var reach := maxf(0.10, strata[i].y + noise * (0.40 + strata[i].x))
		var elevation := height * strata[i].x + weight * noise * 0.20
		ring.append(toe + outward * reach + Vector3.UP * elevation)
	# Follow the actual mountain in several steps instead of one stretched roof.
	for reach: float in [5.0, 9.0, 15.0]:
		var point := toe + outward * reach
		var blend := inverse_lerp(3.1, section.w, reach)
		point.y = lerpf(toe.y + height, field.height_at(point.x, point.z) + 0.03, blend)
		point.y += weight * _rock_noise.get_noise_2d(distance, reach * 19.0) * 1.3
		ring.append(point)
	ring.append_array([back, Vector3(back.x, floor, back.z)])
	return ring


func _cap(mesh: StructureMesh, ring: PackedVector3Array, reverse: bool) -> void:
	var centre := Vector3.ZERO
	for point in ring:
		centre += point
	centre /= ring.size()
	for i in ring.size():
		var j := (i + 1) % ring.size()
		if reverse:
			mesh.triangle(centre, ring[j], ring[i], Color(0.60, 0.38, 0.26))
		else:
			mesh.triangle(centre, ring[i], ring[j], Color(0.60, 0.38, 0.26))


func _roadbed(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		def: TalusDef, rows: PackedFloat32Array, laterals: Array[float]) -> void:
	var sides := StructureMesh.new()
	var supports: Dictionary = {}
	var before := PackedVector3Array()
	for row in range(rows.bsearch(def.start), mini(rows.bsearch(def.end()), rows.size() - 1)):
		var from := rows[row]
		var to := rows[row + 1]
		if before.is_empty():
			before = _support_row(sampler, profile, from, laterals)
		var after := _support_row(sampler, profile, to, laterals)
		var surface := profile.surface_at((from + to) * 0.5)
		if not supports.has(surface):
			var body := StaticBody3D.new()
			body.name = "Subgrade%d_%s" % [gravel_chunks, surface.id]
			body.set_meta(SurfaceLookup.META_KEY, surface)
			supports[surface] = body
		# The same rows, columns and diagonal as the actual RoadBuilder mesh.
		# Extruding triangles avoids a convex quad bridging a twisting bank.
		for column in laterals.size() - 1:
			var left_a := before[column]
			var right_a := before[column + 1]
			var left_b := after[column]
			var right_b := after[column + 1]
			for triangle: Array in [[left_a, left_b, right_a], [right_a, left_b, right_b]]:
				var hull := ConvexPolygonShape3D.new()
				hull.margin = 0.002
				var points := PackedVector3Array()
				for point: Vector3 in triangle:
					points.append(point - Vector3.UP * 0.002)
					points.append(point - Vector3.UP * 1.0)
				hull.points = points
				var shape := CollisionShape3D.new()
				shape.shape = hull
				(supports[surface] as StaticBody3D).add_child(shape)
		for side: float in [-1.0, 1.0]:
			var near := sampler.surface_point(from, side * sampler.half_width_at(from), profile)
			var far := sampler.surface_point(to, side * sampler.half_width_at(to), profile)
			var near_base := Vector3(near.x, minf(near.y - 0.10, field.height_at(near.x, near.z) - 0.10), near.z)
			var far_base := Vector3(far.x, minf(far.y - 0.10, field.height_at(far.x, far.z) - 0.10), far.z)
			sides.quad(near, far, far_base, near_base, Color(0.52, 0.36, 0.25))
		before = after
	for body: StaticBody3D in supports.values():
		add_child(body)
	var instance := sides.add_to(self, "RoadbedSides%d" % gravel_chunks, ROCK, false)
	if instance != null:
		instance.visibility_range_end = VIEW_DISTANCE
	gravel_chunks += 1


## Sample a road frame once per row, instead of four times per triangle pair.
## Identical vertex arithmetic preserves the visual/collision agreement.
func _support_row(sampler: RoadSampler, profile: RoadProfile, distance: float,
		laterals: Array[float]) -> PackedVector3Array:
	var centre := sampler.position(distance)
	var right := sampler.right(distance)
	var up := sampler.up(distance)
	var scale := RoadBuilder.width_scales(profile.def, distance).x
	var points := PackedVector3Array()
	for lateral: float in laterals:
		var across := lateral * scale
		points.append(centre + right * across + up * profile.height(distance, across))
	return points


## Extrude the existing terrain triangles near the shelf. These buried solids
## catch small stones leaving the road as well; a heightmap alone can lose them
## under a sudden wheel load. Top vertices sit 2 cm below the terrain mesh.
func _subsoil(sampler: RoadSampler, field: TerrainField, section: Vector4) -> void:
	var cells: Dictionary = {}
	var distance := section.x
	while distance <= section.x + section.y:
		var centre := sampler.position(distance)
		var column := roundi((centre.x - field.origin.x) / field.spacing)
		var row := roundi((centre.z - field.origin.y) / field.spacing)
		var reach := ceili(10.0 / field.spacing)
		for x in range(column - reach, column + reach + 1):
			for z in range(row - reach, row + reach + 1):
				if x >= 0 and x < field.columns - 1 and z >= 0 and z < field.rows - 1:
					cells[Vector2i(x, z)] = true
		distance += 4.0
	var bodies: Dictionary = {}
	for cell: Vector2i in cells:
		var key := Vector2i(floori(cell.x / 8.0), floori(cell.y / 8.0))
		if not bodies.has(key):
			var chunk := StaticBody3D.new()
			chunk.name = "ShelfSubsoil%d_%d" % [key.x, key.y]
			chunk.set_meta(SurfaceLookup.META_KEY, field.def.surface)
			bodies[key] = chunk
		var body: StaticBody3D = bodies[key]
		var a := field.sample_position(cell.x, cell.y) - Vector3.UP * 0.02
		var b := field.sample_position(cell.x + 1, cell.y) - Vector3.UP * 0.02
		var c := field.sample_position(cell.x, cell.y + 1) - Vector3.UP * 0.02
		var d := field.sample_position(cell.x + 1, cell.y + 1) - Vector3.UP * 0.02
		for triangle: Array in [[a, b, c], [b, d, c]]:
			var points := PackedVector3Array()
			for point: Vector3 in triangle:
				points.append(point)
				points.append(point - Vector3.UP * 2.0)
			var hull := ConvexPolygonShape3D.new()
			hull.margin = 0.002
			hull.points = points
			var shape := CollisionShape3D.new()
			shape.shape = hull
			body.add_child(shape)
	# Register bounded compounds once each, not once per triangle. A single
	# giant compound makes every wheel cast inspect the whole 400 m of ground.
	for body: StaticBody3D in bodies.values():
		add_child(body)
