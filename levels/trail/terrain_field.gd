class_name TerrainField
extends RefCounted
## The mountainside around a trail as a grid of height samples, generated once.
## The natural ground is a plane fitted to the road's overall climb plus noise.
## Near the road, the ground follows a smoothed road elevation and is carved to
## meet the shoulders (see Corridor). A creek, if the trail has one, is cut as a
## shallow channel beside the road.
## Grid rows run along +Z and columns along +X; index = row * columns + column.

## Sentinel edge distance for samples far from any road.
const FAR := 1.0e6
## A creek's banks rise from its floor to the ground over this width (m).
const CREEK_BANK := 3.0
## A creek's channel deepens from nothing over this distance at each end (m).
const CREEK_TAPER := 10.0
## A creek's bed is kept level with its lowest point within this distance either side (m).
const CREEK_SMOOTHING := 5.0
## The creek's water sits this far below the lowest ground across its channel (m).
const CREEK_BELOW_GROUND := 0.15
## Beyond a creek's banks, raised ground falls back to the natural ground over this width (m).
const CREEK_LEVEE := 4.0

var def: TerrainDef
## World X/Z of sample (column 0, row 0).
var origin := Vector2.ZERO
var spacing := 2.0
var columns := 0
var rows := 0
## Samples per chunk side minus one (chunks share their border samples).
var cells_per_chunk := 64
var heights := PackedFloat32Array()
## Metres outside the nearest shoulder edge (negative under the road).
var edge_distances := PackedFloat32Array()
## Metres from the creek's centre line; FAR away from any creek.
var creek_distances := PackedFloat32Array()
## The creek's water heights, one per metre along the road from creek_start.
var creek_start := 0.0
var creek_levels := PackedFloat32Array()
## How strongly each sample is tinted toward wear_color (0..1); empty where nothing wears the ground.
var wear := PackedFloat32Array()
var wear_color := Color.WHITE
var lowest_height := 0.0


static func generate(sampler: RoadSampler, trail: TrailDef, terrain: TerrainDef) -> TerrainField:
	var field := TerrainField.new()
	field.def = terrain
	field.spacing = terrain.sample_spacing
	field.cells_per_chunk = maxi(1, roundi(terrain.chunk_size / terrain.sample_spacing))

	# Road stamps every metre: position, flat right direction, and banking slope.
	var stamps: Array[Vector3] = []
	var rights: Array[Vector2] = []
	var bank_slopes := PackedFloat32Array()
	var distance := 0.0
	while distance <= sampler.length:
		var point := sampler.position(distance)
		var across := sampler.right(distance)
		var flat := Vector2(across.x, across.z)
		stamps.append(point)
		rights.append(flat.normalized())
		bank_slopes.append(across.y / maxf(flat.length(), 0.0001))
		distance += 1.0

	field._size_grid(stamps, terrain.margin)
	field._fill_natural(stamps, terrain)
	field._carve(stamps, rights, bank_slopes, trail, terrain)
	field._cut_creek(sampler, trail)
	return field


## World X/Z of the creek's centre line beside the road at `distance`.
static func creek_point(sampler: RoadSampler, trail: TrailDef, distance: float) -> Vector2:
	var point := sampler.position(distance)
	var across := sampler.right(distance)
	return Vector2(point.x, point.z) + Vector2(across.x, across.z).normalized() * trail.creek_offset


func chunk_count() -> Vector2i:
	return Vector2i((columns - 1) / cells_per_chunk, (rows - 1) / cells_per_chunk)


func index(column: int, row: int) -> int:
	return clampi(row, 0, rows - 1) * columns + clampi(column, 0, columns - 1)


func sample_position(column: int, row: int) -> Vector3:
	return Vector3(origin.x + column * spacing, heights[index(column, row)], origin.y + row * spacing)


## Bilinear height at a world X/Z.
func height_at(x: float, z: float) -> float:
	var fx := clampf((x - origin.x) / spacing, 0.0, columns - 1.001)
	var fz := clampf((z - origin.y) / spacing, 0.0, rows - 1.001)
	var column := int(fx)
	var row := int(fz)
	var tx := fx - column
	var tz := fz - row
	var near := lerpf(heights[index(column, row)], heights[index(column + 1, row)], tx)
	var far := lerpf(heights[index(column, row + 1)], heights[index(column + 1, row + 1)], tx)
	return lerpf(near, far, tz)


## Edge distance at the nearest sample to a world X/Z.
func edge_distance_at(x: float, z: float) -> float:
	return edge_distances[index(roundi((x - origin.x) / spacing), roundi((z - origin.y) / spacing))]


## Distance from the creek's centre line at the nearest sample to a world X/Z.
func creek_distance_at(x: float, z: float) -> float:
	return creek_distances[index(roundi((x - origin.x) / spacing), roundi((z - origin.y) / spacing))]


## Wear at the nearest sample to a world X/Z; 0 where nothing wears the ground.
func wear_at(x: float, z: float) -> float:
	if wear.is_empty():
		return 0.0
	return wear[index(roundi((x - origin.x) / spacing), roundi((z - origin.y) / spacing))]


## Surface normal at a sample, from its neighbours.
func normal_at_index(column: int, row: int) -> Vector3:
	var dx := heights[index(column - 1, row)] - heights[index(column + 1, row)]
	var dz := heights[index(column, row - 1)] - heights[index(column, row + 1)]
	return Vector3(dx, 2.0 * spacing, dz).normalized()


func normal_at(x: float, z: float) -> Vector3:
	return normal_at_index(roundi((x - origin.x) / spacing), roundi((z - origin.y) / spacing))


## Falling below this height counts as falling off the map.
func kill_height() -> float:
	return lowest_height - def.kill_depth


func _size_grid(stamps: Array[Vector3], margin: float) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for stamp in stamps:
		low = low.min(Vector2(stamp.x, stamp.z))
		high = high.max(Vector2(stamp.x, stamp.z))
	low -= Vector2(margin, margin)
	high += Vector2(margin, margin)
	var chunk_metres := cells_per_chunk * spacing
	var chunks := Vector2i(ceili((high.x - low.x) / chunk_metres), ceili((high.y - low.y) / chunk_metres))
	origin = Vector2(floorf(low.x / spacing) * spacing, floorf(low.y / spacing) * spacing)
	columns = chunks.x * cells_per_chunk + 1
	rows = chunks.y * cells_per_chunk + 1
	heights.resize(columns * rows)
	edge_distances.resize(columns * rows)
	creek_distances.resize(columns * rows)
	creek_distances.fill(FAR)


## Natural ground: a plane fitted to the road's elevations, plus fractal noise.
func _fill_natural(stamps: Array[Vector3], terrain: TerrainDef) -> void:
	var centre := Vector3.ZERO
	for stamp in stamps:
		centre += stamp
	centre /= stamps.size()
	var sxx := 0.0
	var sxz := 0.0
	var szz := 0.0
	var sxe := 0.0
	var sze := 0.0
	for stamp in stamps:
		var dx := stamp.x - centre.x
		var dz := stamp.z - centre.z
		var de := stamp.y - centre.y
		sxx += dx * dx
		sxz += dx * dz
		szz += dz * dz
		sxe += dx * de
		sze += dz * de
	# A little regularisation keeps a straight road (all points on one line) from
	# making the fit degenerate: the slope along it is kept, none is assumed across it.
	var ridge := (sxx + szz) * 0.001 + 0.000001
	sxx += ridge
	szz += ridge
	var determinant := sxx * szz - sxz * sxz
	var slope := Vector2.ZERO
	if absf(determinant) > 0.0001:
		slope = Vector2((sxe * szz - sze * sxz) / determinant, (sze * sxx - sxe * sxz) / determinant)

	var noise := FastNoiseLite.new()
	noise.seed = terrain.seed
	noise.frequency = 1.0 / terrain.noise_wavelength
	noise.fractal_octaves = terrain.noise_octaves
	for row in rows:
		var z := origin.y + row * spacing
		for column in columns:
			var x := origin.x + column * spacing
			var plane := centre.y + slope.x * (x - centre.x) + slope.y * (z - centre.z)
			heights[row * columns + column] = plane + noise.get_noise_2d(x, z) * terrain.noise_amplitude


## Near the road, blend the natural ground toward a smoothed road elevation.
func _carve(stamps: Array[Vector3], rights: Array[Vector2], bank_slopes: PackedFloat32Array,
		trail: TrailDef, terrain: TerrainDef) -> void:
	var cell_count := columns * rows
	var weight_sums := PackedFloat32Array()
	var height_sums := PackedFloat32Array()
	weight_sums.resize(cell_count)
	height_sums.resize(cell_count)
	edge_distances.fill(FAR)

	var half_width := trail.half_total_width()
	var radius := half_width + terrain.corridor_blend + 2.0
	var radius_squared := radius * radius
	var sigma_squared := terrain.smoothing_radius * terrain.smoothing_radius
	var reach := ceili(radius / spacing)
	for s in stamps.size():
		var stamp := stamps[s]
		var across := rights[s]
		var bank := bank_slopes[s]
		var centre_column := roundi((stamp.x - origin.x) / spacing)
		var centre_row := roundi((stamp.z - origin.y) / spacing)
		for row in range(maxi(0, centre_row - reach), mini(rows, centre_row + reach + 1)):
			var dz := origin.y + row * spacing - stamp.z
			for column in range(maxi(0, centre_column - reach), mini(columns, centre_column + reach + 1)):
				var dx := origin.x + column * spacing - stamp.x
				var squared := dx * dx + dz * dz
				if squared > radius_squared:
					continue
				var i := row * columns + column
				var weight := exp(-squared / sigma_squared)
				var lateral := dx * across.x + dz * across.y
				weight_sums[i] += weight
				height_sums[i] += weight * (stamp.y + lateral * bank)
				var edge := sqrt(squared) - half_width
				if edge < edge_distances[i]:
					edge_distances[i] = edge

	lowest_height = INF
	for i in cell_count:
		if weight_sums[i] > 0.000001 and edge_distances[i] < terrain.corridor_blend:
			var road_height := height_sums[i] / weight_sums[i]
			heights[i] = Corridor.carved_height(road_height, heights[i], edge_distances[i],
					terrain.corridor_blend, terrain.under_road_drop)
		lowest_height = minf(lowest_height, heights[i])


## Shapes the ground along the creek. Each nearby sample takes its shape from the
## nearest point on the creek's centre line:
## - across creek_width, a floor creek_depth below the higher of the centre-line
##   ground and its own ground, so the floor is level where the ground falls away
##   and follows the ground up a slope;
## - banks rising over CREEK_BANK to at least the centre-line ground, so a
##   downhill side gets a low raised bank that holds the water;
## - beyond the banks, raised ground falls back to the natural ground over CREEK_LEVEE.
## The ends taper to nothing. The water level is the lowest centre-line ground
## within CREEK_SMOOTHING either side, less CREEK_BELOW_GROUND, so it never steps
## up and never tops a bank.
func _cut_creek(sampler: RoadSampler, trail: TrailDef) -> void:
	if not trail.has_creek():
		return
	var half_width := trail.creek_width * 0.5
	var radius := half_width + CREEK_BANK
	var outer := radius + CREEK_LEVEE
	var start := trail.creek_start
	var end := minf(trail.creek_start + trail.creek_length, sampler.length)
	var steps := int(end - start) + 1
	var centres: Array[Vector2] = []
	var grounds := PackedFloat32Array()
	var tapers := PackedFloat32Array()
	for step in steps:
		var distance := start + step
		var centre := creek_point(sampler, trail, distance)
		centres.append(centre)
		grounds.append(height_at(centre.x, centre.y))
		tapers.append(minf(smoothstep(start, start + CREEK_TAPER, distance), 1.0 - smoothstep(end - CREEK_TAPER, end, distance)))
	creek_start = start
	creek_levels.resize(steps)
	for step in steps:
		var ground := grounds[step]
		for other in range(maxi(0, step - int(CREEK_SMOOTHING)), mini(steps, step + int(CREEK_SMOOTHING) + 1)):
			ground = minf(ground, grounds[other])
		creek_levels[step] = ground - CREEK_BELOW_GROUND

	var nearest := PackedInt32Array()
	nearest.resize(columns * rows)
	nearest.fill(-1)
	var touched := PackedInt32Array()
	var reach := ceili(outer / spacing) + 1
	for step in steps:
		var centre := centres[step]
		var centre_column := roundi((centre.x - origin.x) / spacing)
		var centre_row := roundi((centre.y - origin.y) / spacing)
		for row in range(maxi(0, centre_row - reach), mini(rows, centre_row + reach + 1)):
			for column in range(maxi(0, centre_column - reach), mini(columns, centre_column + reach + 1)):
				var i := row * columns + column
				var from_centre := Vector2(origin.x + column * spacing, origin.y + row * spacing).distance_to(centre)
				if from_centre < creek_distances[i]:
					if nearest[i] < 0:
						touched.append(i)
					creek_distances[i] = from_centre
					nearest[i] = step

	for i in touched:
		var from_centre := creek_distances[i]
		if from_centre >= outer:
			continue
		var step := nearest[i]
		var natural := heights[i]
		var depth := trail.creek_depth * tapers[step]
		var top := lerpf(natural, grounds[step], tapers[step])
		if from_centre < radius:
			var floor := maxf(grounds[step], natural) - depth
			heights[i] = lerpf(floor, maxf(natural, top), smoothstep(half_width, radius, from_centre))
		else:
			heights[i] = maxf(natural, lerpf(top, natural, smoothstep(radius, outer, from_centre)))
		lowest_height = minf(lowest_height, heights[i])


## The creek's water height at `distance` along the road, or -INF where there is no creek.
func creek_water_level(distance: float) -> float:
	var step := roundi(distance - creek_start)
	return creek_levels[step] if step >= 0 and step < creek_levels.size() else -INF
