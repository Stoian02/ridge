class_name ScatterBuilder
extends Node3D
## Places pines, rocks, roadside posts and broadleaf trees around a trail. Trees
## and rocks are scattered one per grid cell with a random offset, kept clear of
## the road and any creek, and off steep slopes; posts line shoulders where the
## ground drops away. Each kind is drawn as one MultiMesh per terrain chunk.

const DIRT := preload("res://surfaces/dirt.tres")

## How far outward from the shoulder edge the ground is checked for a drop (m).
const DROP_CHECK_DISTANCE := 10.0
## Nothing is placed closer than this to a creek's edge (m).
const CREEK_CLEARANCE := 2.0

## Counts of placed items, for tests and build reports.
var pine_count := 0
var rock_count := 0
var post_count := 0
var broadleaf_count := 0
## Where the roadside posts were placed. A MultiMesh's instance transforms cannot
## be read back in a headless run, so tests check the posts here.
var post_transforms: Array[Transform3D] = []


func build(field: TerrainField, sampler: RoadSampler, profile: RoadProfile, trail: TrailDef, def: ScatterDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	pine_count = 0
	rock_count = 0
	post_count = 0
	broadleaf_count = 0
	post_transforms.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.9
	var creek_clearance := trail.creek_width * 0.5 + CREEK_CLEARANCE

	var rock_collision := StaticBody3D.new()
	rock_collision.name = "RockCollision"
	rock_collision.set_meta(SurfaceLookup.META_KEY, DIRT)
	add_child(rock_collision)

	var pines := _scatter(field, def, def.pine_spacing, Vector2(0.8, 1.3), 0.0, creek_clearance, rng, true)
	pine_count = pines.size()
	_add_multimeshes(field, pines, LowPolyMeshes.pine(def.foliage_color, def.trunk_color), material,
			def.pine_view_distance, true)

	var rocks := _scatter(field, def, def.rock_spacing, Vector2(0.6, 1.6), 0.25, creek_clearance, rng)
	rock_count = rocks.size()
	_add_multimeshes(field, rocks, LowPolyMeshes.rock(def.rock_color, def.seed), material,
			def.rock_view_distance, false)
	for rock in rocks:
		if field.edge_distance_at(rock.origin.x, rock.origin.z) < def.rock_collision_distance:
			var sphere := SphereShape3D.new()
			sphere.radius = 0.8 * rock.basis.get_scale().x
			var shape := CollisionShape3D.new()
			shape.shape = sphere
			shape.position = rock.origin
			rock_collision.add_child(shape)

	post_transforms = _posts(field, sampler, profile, trail, def)
	post_count = post_transforms.size()
	_add_multimeshes(field, post_transforms, LowPolyMeshes.post(def.post_color, def.reflector_color), material,
			def.rock_view_distance, false)

	if def.broadleaf_spacing > 0.0:
		var trees := _scatter(field, def, def.broadleaf_spacing, Vector2(0.8, 1.3), 0.0, creek_clearance, rng)
		broadleaf_count = trees.size()
		_add_multimeshes(field, trees, LowPolyMeshes.broadleaf(def.broadleaf_color, def.trunk_color, def.seed),
				material, def.broadleaf_view_distance, true)


## One transform per grid cell of `spacing`, jittered, skipping cells too close
## to the road or a creek, or too steep. `sink` lowers each item by that share of its scale.
func _scatter(field: TerrainField, def: ScatterDef, spacing: float, scale_range: Vector2, sink: float,
		creek_clearance: float, rng: RandomNumberGenerator, pines: bool = false) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var width := (field.columns - 1) * field.spacing
	var depth := (field.rows - 1) * field.spacing
	var max_slope := deg_to_rad(def.max_slope_deg)
	var z := 0.0
	while z < depth:
		var x := 0.0
		while x < width:
			var world_x := field.origin.x + x + rng.randf() * spacing
			var world_z := field.origin.y + z + rng.randf() * spacing
			var yaw := rng.randf() * TAU
			var scale := rng.randf_range(scale_range.x, scale_range.y)
			x += spacing
			if field.edge_distance_at(world_x, world_z) < def.road_clearance:
				continue
			if field.creek_distance_at(world_x, world_z) < creek_clearance:
				continue
			if field.wear_at(world_x, world_z) > 0.0:
				continue
			if acos(clampf(field.normal_at(world_x, world_z).y, -1.0, 1.0)) > max_slope:
				continue
			var ground := field.height_at(world_x, world_z) - sink * scale
			if pines and def.pine_thinning_heights.y > def.pine_thinning_heights.x:
				var thinning := smoothstep(def.pine_thinning_heights.x, def.pine_thinning_heights.y, ground)
				if rng.randf() > lerpf(1.0, def.pine_high_density, thinning):
					continue
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale)
			transforms.append(Transform3D(basis, Vector3(world_x, ground, world_z)))
		z += spacing
	return transforms


## Posts every post_spacing along the road, on each side whose ground drops away.
func _posts(field: TerrainField, sampler: RoadSampler, profile: RoadProfile, trail: TrailDef,
		def: ScatterDef) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var distance := def.post_spacing * 0.5
	while distance < sampler.length:
		if profile.on_bridge(distance) or trail.tunnels.any(func(t: TunnelDef) -> bool: return t.contains(distance)):
			distance += def.post_spacing
			continue
		var half := trail.half_total_width_at(distance)
		var across := sampler.right(distance)
		var flat_across := Vector3(across.x, 0.0, across.z).normalized()
		for side: float in [-1.0, 1.0]:
			var edge := sampler.surface_point(distance, side * half, profile)
			var outside := edge + flat_across * side * DROP_CHECK_DISTANCE
			if edge.y - field.height_at(outside.x, outside.z) < def.post_drop:
				continue
			var spot := edge + flat_across * side * 0.3
			transforms.append(Transform3D(Basis.looking_at(sampler.forward(distance), Vector3.UP), spot))
		distance += def.post_spacing
	return transforms


func _add_multimeshes(field: TerrainField, transforms: Array[Transform3D], mesh: ArrayMesh,
		material: StandardMaterial3D, view_distance: float, casts_shadow: bool) -> void:
	var chunk_metres := field.cells_per_chunk * field.spacing
	var buckets := {}
	for transform in transforms:
		var key := Vector2i(floori((transform.origin.x - field.origin.x) / chunk_metres),
				floori((transform.origin.z - field.origin.y) / chunk_metres))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(transform)
	for key in buckets:
		var bucket: Array = buckets[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = bucket.size()
		for i in bucket.size():
			multimesh.set_instance_transform(i, bucket[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		instance.visibility_range_end = view_distance
		if not casts_shadow:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
