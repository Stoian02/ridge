class_name TrailEarthworks
extends RefCounted
## Height-field cuts and ridges around trail structures. The portal approach
## has holes in the heightmap where a sloping roof would block the opening;
## the road and the portal's retaining walls close that cut.


static func apply_tunnels(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	if trail.tunnels.is_empty():
		return
	field.portal_holes.resize(field.heights.size())
	for tunnel: TunnelDef in trail.tunnels:
		var half := tunnel.inner_width * 0.5
		var footprint := maxf(half, trail.half_total_width()) + field.spacing * 2.0
		var reach := footprint + 25.0
		var samples := nearest_samples(field, sampler, tunnel.start - tunnel.portal_length,
				tunnel.end() + tunnel.portal_length, reach)
		for i: int in samples:
			var sample: Vector4 = samples[i]
			var at := sample.y
			var outside := maxf(tunnel.start - at, at - tunnel.end())
			var along := 1.0 - smoothstep(0.0, tunnel.portal_length, maxf(outside, 0.0))
			var across := 1.0 - smoothstep(footprint, reach, sqrt(sample.x))
			var target := sample.z + tunnel.height + tunnel.cover + 0.15
			field.heights[i] = maxf(field.heights[i], lerpf(field.heights[i], target, along * across))
			# Keep two grid rows into the shell clear of heightfield triangles that
			# would otherwise span down through the driving opening at its ends.
			var portal := absf(at - tunnel.start) <= tunnel.portal_length and at < tunnel.start + field.spacing * 2.0
			portal = portal or (absf(at - tunnel.end()) <= tunnel.portal_length and at > tunnel.end() - field.spacing * 2.0)
			if portal and absf(sample.w) <= trail.half_total_width():
				field.portal_holes[i] = 1


## Nearest metre stamp in a structure's neighbourhood, keyed by field sample:
## (flat distance squared, road distance, road elevation, lateral offset).
static func apply_bridges(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	for bridge: BridgeDef in trail.bridges:
		var half := bridge.gorge_width * 0.5
		var samples := nearest_samples(field, sampler, bridge.start - 4.0,
				bridge.end() + bridge.ramp_length, half + 8.0)
		for i: int in samples:
			var sample: Vector4 = samples[i]
			var at := sample.y
			var lateral := absf(sample.w)
			if at >= bridge.start and at <= bridge.end():
				var weight := (1.0 - smoothstep(half, half + 6.0, lateral)) \
						* smoothstep(0.0, 4.0, minf(at - bridge.start, bridge.end() - at))
				field.heights[i] = lerpf(field.heights[i], sample.z - bridge.gorge_depth, weight)
			elif at > bridge.end() and at <= bridge.end() + bridge.ramp_length and lateral <= trail.half_total_width():
				field.heights[i] = minf(field.heights[i], sample.z + bridge.height_offset(at) - field.def.under_road_drop)


static func nearest_samples(field: TerrainField, sampler: RoadSampler, start: float,
		end: float, radius: float) -> Dictionary:
	var result := {}
	var reach := ceili(radius / field.spacing)
	var squared_radius := radius * radius
	var distance := start
	while distance <= end + 0.001:
		var point := sampler.position(distance)
		var right := sampler.right(distance)
		var forward := sampler.forward(distance)
		var flat_length := Vector2(forward.x, forward.z).length()
		var cx := roundi((point.x - field.origin.x) / field.spacing)
		var cz := roundi((point.z - field.origin.y) / field.spacing)
		for row in range(maxi(0, cz - reach), mini(field.rows, cz + reach + 1)):
			var dz := field.origin.y + row * field.spacing - point.z
			for column in range(maxi(0, cx - reach), mini(field.columns, cx + reach + 1)):
				var dx := field.origin.x + column * field.spacing - point.x
				var squared := dx * dx + dz * dz
				if squared > squared_radius:
					continue
				var i := row * field.columns + column
				var previous: Vector4 = result.get(i, Vector4(INF, 0, 0, 0))
				if squared < previous.x:
					# Project past the nearest stamp, especially at the search ends:
					# clamping there incorrectly extended a portal hole by the search radius.
					var along := (dx * forward.x + dz * forward.z) / maxf(flat_length, 0.001)
					result[i] = Vector4(squared, distance + along, point.y + along * forward.y,
							dx * right.x + dz * right.z)
		distance += 1.0
	return result
