class_name RutWaterBuilder
extends Node3D
## Opt-in shallow standing water in wheel ruts. Seeded pools follow the road's
## bends, but each has a level water surface bounded by both lips and the lowest
## configured fill height. Only drawing changes; road collision is untouched.

const POOL_LENGTH := Vector2(6.0, 12.0)
const DRY_GAP := Vector2(3.0, 6.0)
const STEP := 0.5
const END_FADE := 1.0
const LIP_CLEARANCE := 0.004
const MIN_DEPTH := 0.002
const CHUNK_LENGTH := 64.0
const VIEW_DISTANCE := 180.0
const ALPHA := 0.8

## Drawn cross-sections: (road distance, left lateral, right lateral, water Y).
var water_rows: Array[Vector4] = []
## Authored pools with visible water: (start, end, rut centre lateral).
var puddle_ranges: Array[Vector3] = []


func build(sampler: RoadSampler, profile: RoadProfile, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	water_rows.clear()
	puddle_ranges.clear()
	for i in trail.surface_stretches.size():
		var stretch := trail.surface_stretches[i]
		if stretch.water_rut_depth <= 0.0 or stretch.rut_depth <= LIP_CLEARANCE or stretch.rut_width <= 0.0:
			continue
		_build_stretch(sampler, profile, trail, stretch, i)


func _build_stretch(sampler: RoadSampler, profile: RoadProfile, trail: TrailDef,
		stretch: SurfaceStretch, index: int) -> void:
	var margin := maxf(stretch.blend_length, stretch.transition_length) + END_FADE
	var start := maxf(stretch.start + margin, 0.0)
	var end := minf(stretch.end() - margin, sampler.length - END_FADE)
	var rng := RandomNumberGenerator.new()
	rng.seed = trail.seed + roundi(stretch.start) * 31 + index
	var chunks := {}
	for side: float in [-1.0, 1.0]:
		var centre := side * stretch.rut_spacing * 0.5
		var at := start + rng.randf_range(0.0, DRY_GAP.x)
		while at + POOL_LENGTH.x <= end:
			var length := minf(rng.randf_range(POOL_LENGTH.x, POOL_LENGTH.y), end - at)
			var chunk := floori((at - start) / CHUNK_LENGTH)
			_add_pool(sampler, profile, stretch, at, at + length, centre, chunks, chunk)
			at += length + rng.randf_range(DRY_GAP.x, DRY_GAP.y)
	var material := StandardMaterial3D.new()
	material.albedo_color = stretch.color.lerp(Color(0.5, 0.42, 0.3), 0.2)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.12
	material.metallic_specular = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for key: int in chunks:
		var tool: SurfaceTool = chunks[key]
		var instance := MeshInstance3D.new()
		instance.name = "RutWater%d_%d" % [index, key]
		instance.mesh = tool.commit()
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = VIEW_DISTANCE
		add_child(instance)


func _add_pool(sampler: RoadSampler, profile: RoadProfile, stretch: SurfaceStretch,
		start: float, end: float, centre: float, chunks: Dictionary, chunk: int) -> void:
	var count := maxi(2, ceili((end - start) / STEP))
	var half_width := stretch.rut_width * 0.5
	var fill := minf(stretch.water_rut_depth, stretch.rut_depth - LIP_CLEARANCE)
	var level := INF
	for row in count + 1:
		var at := lerpf(start, end, row / float(count))
		if absf(centre) + half_width >= sampler.road_half_width_at(at) or profile.on_bridge(at):
			return
		var floor := sampler.surface_point(at, centre, profile).y
		level = minf(level, floor + fill)
		for side: float in [-1.0, 1.0]:
			var lip := sampler.surface_point(at, centre + side * half_width, profile).y
			level = minf(level, lip - LIP_CLEARANCE)
	var previous_laid := false
	var previous_left := Vector3.ZERO
	var previous_right := Vector3.ZERO
	var previous_alpha := 0.0
	var quads := 0
	for row in count + 1:
		var at := lerpf(start, end, row / float(count))
		var depth := level - sampler.surface_point(at, centre, profile).y
		if depth <= MIN_DEPTH:
			previous_laid = false
			continue
		var left := _edge(sampler, profile, at, centre, -half_width, level)
		var right := _edge(sampler, profile, at, centre, half_width, level)
		var left_point := sampler.surface_point(at, left, profile)
		var right_point := sampler.surface_point(at, right, profile)
		left_point.y = level
		right_point.y = level
		var fade := minf(smoothstep(start, start + END_FADE, at),
				1.0 - smoothstep(end - END_FADE, end, at))
		var alpha := ALPHA * fade * clampf(depth / 0.02, 0.0, 1.0)
		if previous_laid:
			if not chunks.has(chunk):
				var fresh := SurfaceTool.new()
				fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
				chunks[chunk] = fresh
			var tool: SurfaceTool = chunks[chunk]
			_vertex(tool, previous_left, previous_alpha)
			_vertex(tool, left_point, alpha)
			_vertex(tool, previous_right, previous_alpha)
			_vertex(tool, previous_right, previous_alpha)
			_vertex(tool, left_point, alpha)
			_vertex(tool, right_point, alpha)
			quads += 1
		water_rows.append(Vector4(at, left, right, level))
		previous_left = left_point
		previous_right = right_point
		previous_alpha = alpha
		previous_laid = true
	if quads > 0:
		puddle_ranges.append(Vector3(start, end, centre))


## Locate each bank independently: the down-camber edge is not symmetric.
static func _edge(sampler: RoadSampler, profile: RoadProfile, at: float,
		centre: float, offset: float, level: float) -> float:
	var low := 0.0
	var high := 1.0
	for iteration in 10:
		var middle := (low + high) * 0.5
		if sampler.surface_point(at, centre + offset * middle, profile).y < level:
			low = middle
		else:
			high = middle
	return centre + offset * (low + high) * 0.5


static func _vertex(tool: SurfaceTool, point: Vector3, alpha: float) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_color(Color(1.0, 1.0, 1.0, alpha))
	tool.add_vertex(point)
