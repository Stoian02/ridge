class_name BoulderBuilder
extends Node3D
## Fixed boulders and tilted slabs from each BoulderFieldDef (M5 spec §7.2):
## placed from the field's seed on the road surface or on the terrain beyond the
## shoulders, drawn as one MultiMesh per field, each with a convex hull tagged
## rock. Slabs are the same rock mesh stretched, flattened and rolled about the
## road's axis, so they lift one wheel and put the car off-camber.

const ROCK := preload("res://surfaces/rock.tres")
## Nothing is placed closer than this to a checkpoint gate's centre (m).
const GATE_CLEARANCE := 1.5
## A boulder's centre sits this share of its radius above the ground. At 0 the
## centre sits on the ground: the rock mesh's top sits 0.48-0.71 r above its
## centre, so a 0.45 m boulder stands 0.21-0.32 m and a 0.30 m one 0.14-0.21 m -
## above the rally cars' roughly 15 cm and under the 4x4's measured 35 cm
## clearance (spec §7.3). Kept as the single tuning point for that height.
const BURY := 0.0
## Slab shape relative to its radius: across, up, along the road.
const SLAB_SCALE := Vector3(1.1, 0.35, 1.6)
## Slabs are rolled about the road's axis by this range (degrees).
const SLAB_TILT_DEG := Vector2(8.0, 18.0)
const VIEW_DISTANCE := 200.0

## Per field (same order as trail.boulder_fields): the placed boulders' transforms.
var placed: Array[Array] = []
## Per field: whether each placed boulder is a slab.
var slabs: Array[Array] = []


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	placed.clear()
	slabs.clear()
	var gates := CheckpointPlacer.distances_for(sampler.length, trail)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = 0.95
	for i in trail.boulder_fields.size():
		_build_field(sampler, profile, field, trail.boulder_fields[i], gates, material, i)


func _build_field(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, def: BoulderFieldDef,
		gates: PackedFloat32Array, material: StandardMaterial3D, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = def.seed
	var mesh := LowPolyMeshes.rock(def.color, def.seed)
	var points := mesh.get_faces()
	var transforms: Array[Transform3D] = []
	var is_slab: Array[bool] = []
	var body := StaticBody3D.new()
	body.name = "Field%dCollision" % index
	body.set_meta(SurfaceLookup.META_KEY, ROCK)
	# Never draws past the road's sampled length, where RoadSampler.forward()
	# returns a zero vector and Basis.looking_at() would error for a slab.
	var end := minf(def.end(), sampler.length - 1.0)
	for n in (def.count if def.start < end else 0):
		# Every random draw happens before a boulder can be skipped, so the layout
		# of the others never depends on the gates.
		var distance := rng.randf_range(def.start, end)
		var side: float = -1.0 if n % 2 == 0 else 1.0
		var lateral := side * rng.randf_range(def.lateral_range.x, def.lateral_range.y)
		var slab := rng.randf() < def.slab_fraction
		var yaw := rng.randf() * TAU
		var tilt := deg_to_rad(rng.randf_range(SLAB_TILT_DEG.x, SLAB_TILT_DEG.y)) * (1.0 if rng.randf() < 0.5 else -1.0)
		var on_road := absf(lateral) <= sampler.half_width_at(distance)
		var sizes := def.size_range if on_road else def.off_road_size_range
		var radius := rng.randf_range(sizes.x, sizes.y)
		if Array(gates).any(func(gate: float) -> bool: return absf(gate - distance) < GATE_CLEARANCE):
			continue
		var origin: Vector3
		if on_road:
			origin = sampler.surface_point(distance, lateral, profile)
		else:
			origin = sampler.position(distance) + sampler.right(distance) * lateral
			origin.y = field.height_at(origin.x, origin.z)
		origin += Vector3.UP * radius * BURY
		var basis: Basis
		if slab:
			var along := sampler.forward(distance)
			basis = Basis.looking_at(along, Vector3.UP).rotated(along, tilt) * Basis.from_scale(SLAB_SCALE * radius)
		else:
			basis = Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * radius)
		transforms.append(Transform3D(basis, origin))
		is_slab.append(slab)
		var hull := ConvexPolygonShape3D.new()
		var local := PackedVector3Array()
		local.resize(points.size())
		for p in points.size():
			local[p] = basis * points[p]
		hull.points = local
		var shape := CollisionShape3D.new()
		shape.shape = hull
		shape.position = origin
		body.add_child(shape)
	add_child(body)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "Field%d" % index
	instance.multimesh = multimesh
	instance.material_override = material
	instance.visibility_range_end = VIEW_DISTANCE
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	placed.append(transforms)
	slabs.append(is_slab)
