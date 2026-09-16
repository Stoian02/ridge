class_name TerrainBuilder
extends Node3D
## Turns a TerrainField into chunks, each with slope-coloured meshes and
## heightmap collision tagged as dirt. Chunks share their border samples, so
## there are no seams. Each chunk has a full-detail mesh near the camera and a
## coarse one (every second sample) further away.

const DIRT := preload("res://surfaces/dirt.tres")

## Slopes within this many degrees of the rock angle blend between dirt and rock colour.
const COLOR_BLEND_DEG := 5.0
## The far mesh uses every this-many-th height sample.
const COARSE_STEP := 2

## Build the chunks' mesh and collision data on worker threads (the phone has 8 cores
## and terrain is over half of a level's build). The nodes are still made on the main
## thread, in chunk order, so the result is the same either way.
@export var threaded := true

## Seconds the last build spent on each part: "data" (mesh and collision arrays),
## "meshes" (ArrayMesh and MeshInstance3D nodes) and "collision" (shapes and bodies).
var last_timings := {}

var _index_cache := {}
var _mesh_usec := 0
var _collision_usec := 0


func build(field: TerrainField) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	assert(field.cells_per_chunk % COARSE_STEP == 0, "chunk cells must divide by COARSE_STEP")
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	var cells := field.cells_per_chunk
	var size := cells + 1
	var chunks := field.chunk_count()
	var origins: Array[Vector2i] = []
	for chunk_row in chunks.y:
		for chunk_column in chunks.x:
			origins.append(Vector2i(chunk_column * cells, chunk_row * cells))
	var data_started := Time.get_ticks_usec()
	# Fill the index cache first, so the worker threads only ever read it.
	_grid_indices(size)
	_grid_indices((size - 1) / COARSE_STEP + 1)
	# One Dictionary per chunk, each filled by a single task.
	var results: Array[Dictionary] = []
	for i in origins.size():
		results.append({})
	var work := func(i: int) -> void:
		_chunk_data(field, origins[i].x, origins[i].y, size, results[i])
	if threaded:
		var task := WorkerThreadPool.add_group_task(work, origins.size(), -1, true, "Terrain chunks")
		WorkerThreadPool.wait_for_group_task_completion(task)
	else:
		for i in origins.size():
			work.call(i)
	var data_usec := Time.get_ticks_usec() - data_started
	_mesh_usec = 0
	_collision_usec = 0
	for i in origins.size():
		_add_chunk(field, origins[i].x, origins[i].y, size, results[i], material)
	last_timings = {"data": data_usec / 1000000.0, "meshes": _mesh_usec / 1000000.0,
			"collision": _collision_usec / 1000000.0}


## A chunk's near and far mesh arrays and its collision heights, into `into`. Reads the
## field only, so it is safe on a worker thread. The field's data is copied into locals
## rather than read through its methods: calling a shared object's methods from worker
## threads made them wait on each other (a probe measured 1.2x on 4 threads, against 2.8x
## for the same maths on locals).
func _chunk_data(field: TerrainField, first_column: int, first_row: int, size: int, into: Dictionary) -> void:
	into["near"] = _mesh_arrays(field, first_column, first_row, size, 1)
	into["far"] = _mesh_arrays(field, first_column, first_row, size, COARSE_STEP)
	var heights := field.heights
	var columns := field.columns
	var last_column := columns - 1
	var last_row := field.rows - 1
	var collision_heights := PackedFloat32Array()
	collision_heights.resize(size * size)
	for row in size:
		var row_offset := clampi(first_row + row, 0, last_row) * columns
		for column in size:
			collision_heights[row * size + column] = heights[row_offset + clampi(first_column + column, 0, last_column)]
	into["collision"] = collision_heights


func _add_chunk(field: TerrainField, first_column: int, first_row: int, size: int, data: Dictionary,
		material: StandardMaterial3D) -> void:
	var mesh_started := Time.get_ticks_usec()
	var near := _add_mesh(data["near"], material)
	near.name = "Near"
	near.visibility_range_end = field.def.detail_distance
	var far := _add_mesh(data["far"], material)
	far.name = "Far"
	far.visibility_range_begin = field.def.detail_distance
	far.visibility_range_end = field.def.view_distance
	var collision_started := Time.get_ticks_usec()
	_mesh_usec += collision_started - mesh_started

	var collision_heights: PackedFloat32Array = data["collision"]
	var shape := HeightMapShape3D.new()
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = collision_heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# The shape puts samples 1 m apart around its centre; scaling sets the spacing.
	collision.scale = Vector3(field.spacing, 1.0, field.spacing)
	var body := StaticBody3D.new()
	body.set_meta(SurfaceLookup.META_KEY, field.def.surface)
	var middle := (size - 1) * 0.5
	body.position = Vector3(field.origin.x + (first_column + middle) * field.spacing, 0.0,
			field.origin.y + (first_row + middle) * field.spacing)
	body.add_child(collision)
	add_child(body)
	_collision_usec += Time.get_ticks_usec() - collision_started


## The mesh arrays of one chunk built from every `step`-th sample. Reads the field and
## the pre-filled index cache only, so it is safe on a worker thread. The field's data
## is copied into locals and its index, position and normal maths is done inline (see
## _chunk_data for why); the results match TerrainField's own methods.
func _mesh_arrays(field: TerrainField, first_column: int, first_row: int, size: int, step: int) -> Array:
	var heights := field.heights
	var wear := field.wear
	var has_wear := not wear.is_empty()
	var columns := field.columns
	var last_column := columns - 1
	var last_row := field.rows - 1
	var spacing := field.spacing
	var origin := field.origin
	var rock_deg := field.def.rock_slope_deg
	var dirt_color := field.def.dirt_color
	var rock_color := field.def.rock_color
	var wear_color := field.wear_color
	var mesh_size := (size - 1) / step + 1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	vertices.resize(mesh_size * mesh_size)
	normals.resize(mesh_size * mesh_size)
	colors.resize(mesh_size * mesh_size)
	for row in mesh_size:
		var grid_row := first_row + row * step
		var row_offset := clampi(grid_row, 0, last_row) * columns
		var above := clampi(grid_row - 1, 0, last_row) * columns
		var below := clampi(grid_row + 1, 0, last_row) * columns
		for column in mesh_size:
			var grid_column := first_column + column * step
			var center := clampi(grid_column, 0, last_column)
			var dx := heights[row_offset + clampi(grid_column - 1, 0, last_column)] \
					- heights[row_offset + clampi(grid_column + 1, 0, last_column)]
			var dz := heights[above + center] - heights[below + center]
			var normal := Vector3(dx, 2.0 * spacing, dz).normalized()
			var out := row * mesh_size + column
			vertices[out] = Vector3(origin.x + grid_column * spacing, heights[row_offset + center],
					origin.y + grid_row * spacing)
			normals[out] = normal
			var slope_deg := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
			var rockiness := smoothstep(rock_deg - COLOR_BLEND_DEG, rock_deg + COLOR_BLEND_DEG, slope_deg)
			var color := dirt_color.lerp(rock_color, rockiness)
			if has_wear:
				color = color.lerp(wear_color, wear[row_offset + center])
			colors[out] = color

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _index_cache[mesh_size]
	return arrays


## Adds a mesh made from `arrays` (see _mesh_arrays).
func _add_mesh(arrays: Array, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	# Terrain receives shadows but doesn't cast them: casting doubled the scene's
	# triangle count, because every chunk touching the shadow range is drawn whole.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance, true)
	return mesh_instance


## Triangle indices for a size x size vertex grid, facing up.
func _grid_indices(size: int) -> PackedInt32Array:
	if _index_cache.has(size):
		return _index_cache[size]
	var indices := PackedInt32Array()
	for row in size - 1:
		for column in size - 1:
			var i := row * size + column
			indices.append_array([i, i + 1, i + size, i + 1, i + size + 1, i + size])
	_index_cache[size] = indices
	return indices
