class_name TrailEarthworks
extends RefCounted
## Height-field cuts and ridges around trail structures. The portal approach
## has holes in the heightmap where a sloping roof would block the opening;
## the road and the portal's retaining walls close that cut.

## Ford banks rise alongside the river, then blend outside its water ribbon.
const FORD_BANK := 4.0
## River ends and the upstream ledge blend into the surrounding ground.
const FORD_TAPER := 8.0


## Clear every heightmap corner under a gravel road cell. Smoothed terrain can
## otherwise poke through a twisting bank, especially its widening shoulders.
## Both possible heightmap diagonals must remain below the visible road.
static func apply_gravel_clearance(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	var has_gravel := false
	for talus: TalusDef in trail.talus:
		has_gravel = has_gravel or talus.gravel_bed
	if not has_gravel:
		return
	var profile := RoadProfile.new(trail, sampler.length)
	var rows := RoadBuilder.row_distances(sampler.length, profile, trail)
	var stations := RoadBuilder.cross_section(trail)
	var before := PackedVector3Array()
	for row in rows.size() - 1:
		if not profile.gravel_at((rows[row] + rows[row + 1]) * 0.5):
			before.clear()
			continue
		if before.is_empty():
			before = _road_row(sampler, profile, stations, rows[row])
		var after := _road_row(sampler, profile, stations, rows[row + 1])
		for column in stations.size() - 1:
			if is_equal_approx(stations[column].x, stations[column + 1].x):
				continue
			var bounds := AABB(before[column], Vector3.ZERO)
			for point: Vector3 in [before[column + 1], after[column], after[column + 1]]:
				bounds = bounds.expand(point)
			var from_x := floori((bounds.position.x - field.origin.x) / field.spacing)
			var to_x := ceili((bounds.end.x - field.origin.x) / field.spacing)
			var from_z := floori((bounds.position.z - field.origin.y) / field.spacing)
			var to_z := ceili((bounds.end.z - field.origin.y) / field.spacing)
			var ceiling := bounds.position.y - field.def.under_road_drop
			for z in range(maxi(0, from_z), mini(field.rows - 1, to_z) + 1):
				for x in range(maxi(0, from_x), mini(field.columns - 1, to_x) + 1):
					var i := field.index(x, z)
					field.heights[i] = minf(field.heights[i], ceiling)
		before = after


static func _road_row(sampler: RoadSampler, profile: RoadProfile,
		stations: Array[Vector2], distance: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var centre := sampler.position(distance)
	var right := sampler.right(distance)
	var up := sampler.up(distance)
	var scales := RoadBuilder.width_scales(profile.def, distance)
	for station: Vector2 in stations:
		var lateral := RoadBuilder.station_lateral(station, profile.def.road_width * 0.5, scales.x, scales.y)
		points.append(centre + right * lateral + up * profile.height(distance, lateral))
	return points


## Lower every grid corner supporting a damaged road cell. Sampling only at
## hole centres leaves coarse terrain triangles bridging the depression. Sum
## overlapping depths conservatively; the road mesh still supplies the floor.
static func apply_road_damage(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	if trail.damage_sections.is_empty() and trail.cross_ruts.is_empty():
		return
	var profile := RoadProfile.new(trail, sampler.length)
	var cuts := {}
	var diagonal := field.spacing * sqrt(2.0)
	for hole: Vector4 in profile.damage_potholes:
		var centre := sampler.position(hole.x) + sampler.right(hole.x) * hole.y
		var reach := hole.z + diagonal
		var cells := ceili(reach / field.spacing)
		var cx := roundi((centre.x - field.origin.x) / field.spacing)
		var cz := roundi((centre.z - field.origin.y) / field.spacing)
		for row in range(maxi(0, cz - cells), mini(field.rows, cz + cells + 1)):
			var dz := field.origin.y + row * field.spacing - centre.z
			for column in range(maxi(0, cx - cells), mini(field.columns, cx + cells + 1)):
				var dx := field.origin.x + column * field.spacing - centre.x
				if dx * dx + dz * dz <= reach * reach:
					var i := row * field.columns + column
					var previous: float = cuts.get(i, 0.0)
					cuts[i] = previous + hole.w
	for rut: CrossRutDef in trail.cross_ruts:
		var span := rut.bounds()
		var reach := maxf(absf(rut.lateral_from), absf(rut.lateral_to)) + diagonal
		var samples := nearest_samples(field, sampler, span.x - diagonal, span.y + diagonal, reach)
		for i: int in samples:
			var sample: Vector4 = samples[i]
			# Expand by the whole grid diagonal, including skew, so every corner
			# of a triangle below a channel is cleared, not just its centre.
			if sample.w < rut.lateral_from - diagonal or sample.w > rut.lateral_to + diagonal:
				continue
			if absf(sample.y - rut.distance - sample.w * rut.skew) > rut.width * 0.5 + diagonal * (1.0 + absf(rut.skew)):
				continue
			var previous: float = cuts.get(i, 0.0)
			cuts[i] = previous + rut.depth
	for i: int in cuts:
		var depth: float = cuts[i]
		field.heights[i] -= depth


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


## Cuts the river through high ground and supports it across low ground. Under
## the road only lowering is permitted, preserving every road-mesh depression.
## The falls get an upstream ledge; FordBuilder closes its exposed rock face.
static func apply_fords(field: TerrainField, sampler: RoadSampler, trail: TrailDef) -> void:
	if trail.fords.is_empty():
		return
	var profile := RoadProfile.new(trail, sampler.length)
	for ford: FordDef in trail.fords:
		var centre := sampler.position(ford.distance)
		var floor := ford.floor_height(sampler, profile)
		var across := ford.across(sampler)
		var along := Vector3.UP.cross(across)
		var near := minf(ford.waterfall_offset, ford.river_reach)
		var far := maxf(ford.waterfall_offset, ford.river_reach)
		var water_half := ford.water_half_width()
		var bank_end := maxf(water_half, ford.half_width() + FORD_BANK)
		var reach := maxf(absf(near), absf(far)) + FORD_TAPER * 2.0 + bank_end + FORD_BANK
		var cx := roundi((centre.x - field.origin.x) / field.spacing)
		var cz := roundi((centre.z - field.origin.y) / field.spacing)
		var cells := ceili(reach / field.spacing)
		var half_road := sampler.half_width_at(ford.distance) + field.spacing
		var bank_height := floor + maxf(ford.depth, ford.water_depth + 0.05)
		var upstream_sign := signf(ford.waterfall_offset - ford.river_reach)
		for row in range(maxi(0, cz - cells), mini(field.rows, cz + cells + 1)):
			var dz := field.origin.y + row * field.spacing - centre.z
			for column in range(maxi(0, cx - cells), mini(field.columns, cx + cells + 1)):
				var dx := field.origin.x + column * field.spacing - centre.x
				var lateral := dx * across.x + dz * across.z
				var offset := absf(dx * along.x + dz * along.z)
				if lateral < near - FORD_TAPER * 2.0 or lateral > far + FORD_TAPER * 2.0 or offset > bank_end + FORD_BANK:
					continue
				var i := row * field.columns + column
				var natural := field.heights[i]
				var bank := smoothstep(ford.half_width(), ford.half_width() + FORD_BANK, offset)
				var taper := minf(smoothstep(near - FORD_TAPER, near, lateral),
						1.0 - smoothstep(far, far + FORD_TAPER, lateral))
				var outer := 1.0 - smoothstep(bank_end, bank_end + FORD_BANK, offset)
				var target := lerpf(floor, maxf(natural, bank_height), bank)
				var shaped := lerpf(natural, target, taper * outer)
				if absf(lateral) <= half_road:
					shaped = minf(natural, shaped)
				# A plateau behind the falls supports the top of the rock return.
				# Its blend extends past the grid interpolation footprint, so the
				# narrow waterfall does not stand on an unsupported grid sample.
				var upstream := (lateral - ford.waterfall_offset) * upstream_sign
				if upstream > 0.0:
					var side := ford.waterfall_width * 0.5 + FordDef.ROCK_MARGIN + field.spacing
					var ledge := smoothstep(0.0, field.spacing, upstream) \
							* (1.0 - smoothstep(FordDef.LEDGE_RUN + field.spacing,
									FordDef.LEDGE_RUN + field.spacing + FORD_TAPER, upstream)) \
							* (1.0 - smoothstep(side, side + FORD_BANK, offset))
					shaped = maxf(shaped, lerpf(shaped, floor + ford.waterfall_height, ledge))
				field.heights[i] = shaped
