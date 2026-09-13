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

var _index_cache := {}


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
	var chunks := field.chunk_count()
	for chunk_row in chunks.y:
		for chunk_column in chunks.x:
			_add_chunk(field, chunk_column * cells, chunk_row * cells, cells + 1, material)


func _add_chunk(field: TerrainField, first_column: int, first_row: int, size: int,
		material: StandardMaterial3D) -> void:
	var near := _add_mesh(field, first_column, first_row, size, 1, material)
	near.name = "Near"
	near.visibility_range_end = field.def.detail_distance
	var far := _add_mesh(field, first_column, first_row, size, COARSE_STEP, material)
	far.name = "Far"
	far.visibility_range_begin = field.def.detail_distance
	far.visibility_range_end = field.def.view_distance

	var collision_heights := PackedFloat32Array()
	for row in size:
		for column in size:
			collision_heights.append(field.heights[field.index(first_column + column, first_row + row)])
	var shape := HeightMapShape3D.new()
	shape.map_width = size
	shape.map_depth = size
	shape.map_data = collision_heights
	var collision := CollisionShape3D.new()
	collision.shape = shape
	# The shape puts samples 1 m apart around its centre; scaling sets the spacing.
	collision.scale = Vector3(field.spacing, 1.0, field.spacing)
	var body := StaticBody3D.new()
	body.set_meta(SurfaceLookup.META_KEY, DIRT)
	var middle := (size - 1) * 0.5
	body.position = Vector3(field.origin.x + (first_column + middle) * field.spacing, 0.0,
			field.origin.y + (first_row + middle) * field.spacing)
	body.add_child(collision)
	add_child(body)


## Adds a mesh of one chunk built from every `step`-th sample.
func _add_mesh(field: TerrainField, first_column: int, first_row: int, size: int, step: int,
		material: StandardMaterial3D) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var rock_deg := field.def.rock_slope_deg
	var mesh_size := (size - 1) / step + 1
	for row in mesh_size:
		for column in mesh_size:
			var grid_column := first_column + column * step
			var grid_row := first_row + row * step
			var normal := field.normal_at_index(grid_column, grid_row)
			vertices.append(field.sample_position(grid_column, grid_row))
			normals.append(normal)
			var slope_deg := rad_to_deg(acos(clampf(normal.y, -1.0, 1.0)))
			var rockiness := smoothstep(rock_deg - COLOR_BLEND_DEG, rock_deg + COLOR_BLEND_DEG, slope_deg)
			colors.append(field.def.dirt_color.lerp(field.def.rock_color, rockiness))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _grid_indices(mesh_size)
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
