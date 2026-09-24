class_name WaterWaveBake
extends Resource
## Packaged, offline-generated topology. Not a user cache or alternate geometry.
## Regenerate with tools/bake_water_waves.gd after changing the source/profile.

const REVISION := 1

@export var revision: int = REVISION
@export var source_fingerprint: String
@export var vertices: PackedVector3Array
@export var indices: PackedInt32Array
@export var colors: PackedColorArray
@export var limits: PackedFloat32Array
@export var limit_gradients: PackedVector2Array
@export var cells: Dictionary
@export var mesh: ArrayMesh
@export var pitch: float
@export var level: float


static func fingerprint(top: PackedVector3Array, bed: PackedVector3Array,
		top_colors: PackedColorArray, profile: WaterWaveProfile) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	# Ordered values, no object IDs, mutable resources, or dictionary iteration.
	context.update(var_to_bytes([REVISION, top, bed, top_colors, profile.mesh_pitch,
		profile.maximum_offset, profile.depth_fraction, profile.shore_distance]))
	return context.finish().hex_encode()


func capture(data: WaterWaveMesh, fingerprint_value: String) -> void:
	source_fingerprint = fingerprint_value
	vertices = data.vertices
	indices = data.indices
	colors = data.colors
	limits = data.limits
	limit_gradients = data.limit_gradients
	cells = data._cells.duplicate()
	mesh = data.mesh
	pitch = data.pitch
	level = data.level


func matches(expected: String) -> bool:
	return revision == REVISION and source_fingerprint == expected and expected.length() == 64 \
		and mesh != null and mesh.get_surface_count() == 1 and not vertices.is_empty() \
		and indices.size() > 0 and indices.size() % 3 == 0 \
		and colors.size() == vertices.size() and limits.size() == vertices.size() \
		and limit_gradients.size() == vertices.size() and not cells.is_empty() \
		and is_finite(pitch) and pitch > 0.0 and is_finite(level)
