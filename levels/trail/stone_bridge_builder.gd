class_name StoneBridgeBuilder
extends Node3D
## Closed masonry vault, smooth asphalt deck and colliding low parapets.
## Two batched meshes/colliders per bridge; no loose bodies or water registry.

const ASPHALT := preload("res://surfaces/asphalt.tres")
const ROCK := preload("res://surfaces/rock.tres")
const STEP := 0.5


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for bridge: StoneBridgeDef in trail.stone_bridges:
		_build_bridge(sampler, profile, field, trail, bridge)


func _build_bridge(sampler: RoadSampler, profile: RoadProfile, field: TerrainField,
		trail: TrailDef, bridge: StoneBridgeDef) -> void:
	var deck := StructureMesh.new()
	var stone := StructureMesh.new()
	var half := bridge.clear_width * 0.5
	var rows := PackedFloat32Array([bridge.start, bridge.arch_start(), bridge.arch_end(), bridge.end()])
	for i in range(1, ceili(bridge.length / STEP)):
		rows.append(minf(bridge.start + i * STEP, bridge.end()))
	rows.sort()
	# Exact boundaries may duplicate a regular row; do not emit degenerate faces.
	var unique := PackedFloat32Array()
	for at: float in rows:
		if unique.is_empty() or not is_equal_approx(at, unique[-1]):
			unique.append(at)
	for row in unique.size() - 1:
		var a := unique[row]
		var b := unique[row + 1]
		_deck_strip(deck, sampler, profile, trail, a, b, half)
		var arch := (a + b) * 0.5 > bridge.arch_start() and (a + b) * 0.5 < bridge.arch_end()
		var a_bottom := _bottom(sampler, profile, bridge, a, arch)
		var b_bottom := _bottom(sampler, profile, bridge, b, arch)
		var a_outer := _outer_width(trail, bridge, a)
		var b_outer := _outer_width(trail, bridge, b)
		var a_right := sampler.right(a)
		var b_right := sampler.right(b)
		# The vault underside and solid abutment footings have real collision.
		stone.quad(a_bottom - a_right * a_outer, a_bottom + a_right * a_outer,
			b_bottom + b_right * b_outer, b_bottom - b_right * b_outer, bridge.stone_color.darkened(0.14))
		for side: float in [-1.0, 1.0]:
			var a_top := sampler.surface_point(a, side * a_outer, profile)
			var b_top := sampler.surface_point(b, side * b_outer, profile)
			stone.quad(a_bottom + a_right * side * a_outer, b_bottom + b_right * side * b_outer,
				b_top, a_top, bridge.stone_color)
			stone.quad(sampler.surface_point(a, side * half, profile), a_top, b_top,
				sampler.surface_point(b, side * half, profile), bridge.stone_color.lightened(0.07))
			_parapet(stone, sampler, profile, bridge, a, b, side)
	# Close the arch's vertical spring faces and both external ends. These faces
	# are absent in the central aperture, never a rectangular plug under the arch.
	for at: float in [bridge.start, bridge.arch_start(), bridge.arch_end(), bridge.end()]:
		var outer := _outer_width(trail, bridge, at)
		var across := sampler.right(at) * outer
		var bottom := _bottom(sampler, profile, bridge, at, false)
		var top := sampler.surface_point(at, 0.0, profile)
		if at == bridge.arch_start() or at == bridge.arch_end():
			top = _bottom(sampler, profile, bridge, at, true)
		stone.quad(bottom - across, bottom + across, top + across, top - across, bridge.stone_color.darkened(0.07))
	# End faces of the parapets remain outside the full clear roadway.
	for at: float in [bridge.start, bridge.end()]:
		for side: float in [-1.0, 1.0]:
			var inner := sampler.surface_point(at, side * half, profile)
			var outer := sampler.surface_point(at, side * (half + bridge.parapet_width), profile)
			stone.quad(inner, outer, outer + Vector3.UP * bridge.parapet_height,
				inner + Vector3.UP * bridge.parapet_height, bridge.stone_color)
	var deck_node := deck.add_to(self, "StoneDeck%d" % roundi(bridge.start), ASPHALT)
	var stone_node := stone.add_to(self, "Masonry%d" % roundi(bridge.start), ROCK)
	deck_node.visibility_range_end = trail.road_view_distance
	stone_node.visibility_range_end = trail.road_view_distance
	# The field is already cut before any collision commits. Keep the argument
	# explicit like the other builders, without constructing a B2 bed registry.
	assert(field != null)


func _deck_strip(mesh: StructureMesh, sampler: RoadSampler, profile: RoadProfile,
		trail: TrailDef, a: float, b: float, half: float) -> void:
	var outer_line := half - trail.line_inset
	var inner_line := outer_line - trail.line_width
	var stations: Array[float] = [-half, -outer_line, -inner_line, inner_line, outer_line, half]
	for i in stations.size() - 1:
		var color := trail.line_color if trail.painted_lines and (i == 1 or i == 3) else trail.asphalt_color
		mesh.quad(sampler.surface_point(a, stations[i], profile), sampler.surface_point(b, stations[i], profile),
			sampler.surface_point(b, stations[i + 1], profile), sampler.surface_point(a, stations[i + 1], profile), color)


func _parapet(mesh: StructureMesh, sampler: RoadSampler, profile: RoadProfile,
		bridge: StoneBridgeDef, a: float, b: float, side: float) -> void:
	var inner := side * bridge.clear_width * 0.5
	var outer := inner + side * bridge.parapet_width
	var p := sampler.surface_point(a, inner, profile)
	var q := sampler.surface_point(b, inner, profile)
	var r := sampler.surface_point(a, outer, profile)
	var s := sampler.surface_point(b, outer, profile)
	var up := Vector3.UP * bridge.parapet_height
	# Alternating subtle colour blocks read as masonry without per-block nodes,
	# cracks in the collision or coplanar mortar overlays.
	var shade := 0.94 if int((a - bridge.start) / 1.5) % 2 == 0 else 1.04
	var color := bridge.stone_color * Color(shade, shade, shade, 1.0)
	mesh.quad(p, q, q + up, p + up, color)
	mesh.quad(r, s, s + up, r + up, color)
	mesh.quad(p + up, q + up, s + up, r + up, color.lightened(0.1))


func _outer_width(trail: TrailDef, bridge: StoneBridgeDef, at: float) -> float:
	var half := bridge.clear_width * 0.5 + bridge.parapet_width
	var reach := maxf(half, trail.half_total_width_at(at))
	var weight := minf(smoothstep(bridge.start, bridge.arch_start(), at),
		1.0 - smoothstep(bridge.arch_end(), bridge.end(), at))
	return lerpf(reach, half, weight)


func _bottom(sampler: RoadSampler, profile: RoadProfile, bridge: StoneBridgeDef,
		at: float, arch: bool) -> Vector3:
	var point := sampler.surface_point(at, 0.0, profile)
	point.y -= bridge.height_offset(at)
	point.y += bridge.soffit_offset(at) if arch else -bridge.channel_depth - 0.4
	return point
