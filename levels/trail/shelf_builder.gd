class_name ShelfBuilder
extends Node3D
## Closed, colliding left-hand rock cuts and fine gravel between movable stones.
## These are local additions; the terrain corridor still protects every road.

const ROCK := preload("res://surfaces/rock.tres")
const GRAVEL := preload("res://levels/trail/gravel_bed.gdshader")
const CHUNK_LENGTH := 40.0
const WALL_STEP := 2.0
const EDGE_GAP := 0.20
const VIEW_DISTANCE := 220.0

var wall_chunks := 0
var gravel_chunks := 0


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	wall_chunks = 0
	gravel_chunks = 0
	for section: Vector4 in trail.shelf_walls:
		var from := section.x
		var end := minf(section.x + section.y, sampler.length - 1.0)
		while from < end:
			var to := minf(from + CHUNK_LENGTH, end)
			_wall(sampler, profile, field, section, from, to)
			from = to
		_subsoil(sampler, field, section)
	for def: TalusDef in trail.talus:
		if def.gravel_bed:
			_gravel(sampler, profile, def)


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
			var color := Color(0.64, 0.41, 0.28).lightened(0.06 * sin(distance * 0.18 + i * 2.1))
			mesh.quad(before[i], after[i], after[j], before[j], color)
		before = after
	_cap(mesh, before, true)
	var instance := mesh.add_to(self, "LeftCut%d" % wall_chunks, ROCK, false)
	instance.visibility_range_end = VIEW_DISTANCE
	wall_chunks += 1


## A closed cross-section, from the buried road-facing toe to the hillside seam.
func _ring(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		section: Vector4, distance: float) -> PackedVector3Array:
	var half := sampler.road_half_width_at(distance)
	var toe := sampler.surface_point(distance, -half - EDGE_GAP, profile)
	var across := sampler.right(distance)
	var outward := -Vector3(across.x, 0.0, across.z).normalized()
	var weight := minf(smoothstep(section.x, section.x + 16.0, distance),
			1.0 - smoothstep(section.x + section.y - 16.0, section.x + section.y, distance))
	var height := section.z * weight * (1.0 + 0.12 * sin(distance * 0.09))
	var back := toe + outward * section.w
	back.y = field.height_at(back.x, back.z) + 0.03
	var floor := minf(minf(field.height_at(toe.x, toe.z), toe.y), back.y) - 1.0
	return PackedVector3Array([
		Vector3(toe.x, floor, toe.z), toe,
		toe + outward * 0.35 + Vector3.UP * height * 0.35,
		toe + outward * (2.0 + 0.3 * sin(distance * 0.17)) + Vector3.UP * height,
		back, Vector3(back.x, floor, back.z),
	])


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


func _gravel(sampler: RoadSampler, profile: RoadProfile, def: TalusDef) -> void:
	var mesh := StructureMesh.new()
	var supports: Dictionary = {}
	var from := def.start
	var end := minf(def.end(), sampler.length - 1.0)
	while from < end:
		var to := minf(from + 1.0, end)
		var a := sampler.road_half_width_at(from)
		var b := sampler.road_half_width_at(to)
		# Match the road's one-metre rows. There are no holes/steps in this bed.
		var left_a := sampler.surface_point(from, -a, profile) + sampler.up(from) * 0.006
		var right_a := sampler.surface_point(from, a, profile) + sampler.up(from) * 0.006
		var left_b := sampler.surface_point(to, -b, profile) + sampler.up(to) * 0.006
		var right_b := sampler.surface_point(to, b, profile) + sampler.up(to) * 0.006
		mesh.quad(left_a, left_b, right_b, right_a, Color(0.51, 0.42, 0.33))
		# Small bodies under tyre loads need a solid subgrade, not only a
		# zero-thickness triangle sheet. Its top stays BELOW the visible road;
		# this adds no invisible obstacle or extra tyre height.
		var surface := profile.surface_at((from + to) * 0.5)
		if not supports.has(surface):
			var body := StaticBody3D.new()
			body.name = "Subgrade%d_%s" % [gravel_chunks, surface.id]
			body.set_meta(SurfaceLookup.META_KEY, surface)
			supports[surface] = body
		var hull := ConvexPolygonShape3D.new()
		hull.margin = 0.002
		var points := PackedVector3Array()
		for point: Vector3 in [left_a, left_b, right_b, right_a]:
			points.append(point - Vector3.UP * 0.026)
			points.append(point - Vector3.UP * 1.0)
		hull.points = points
		var shape := CollisionShape3D.new()
		shape.shape = hull
		(supports[surface] as StaticBody3D).add_child(shape)
		from = to
	for body: StaticBody3D in supports.values():
		add_child(body)
	var instance := mesh.add_to(self, "GravelBed%d" % gravel_chunks, null, false)
	if instance == null:
		return
	var material := ShaderMaterial.new()
	material.shader = GRAVEL
	instance.material_override = material
	instance.visibility_range_end = VIEW_DISTANCE
	gravel_chunks += 1


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
