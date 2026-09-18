extends GutTest
## Canyon wall sections (M5 spec §10) on a flat, noise-free straight road:
## deltas ease along the section, walls rise and drops fall beyond the corridor
## blend, the corridor itself is untouched, and generation stays deterministic.

var trail: TrailDef
var terrain: TerrainDef
var sampler: RoadSampler


func before_each() -> void:
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(0.0, 0.0, -400.0))
	trail = TrailDef.new()
	sampler = RoadSampler.new(curve, true, trail)
	terrain = TerrainDef.new()
	terrain.margin = 120.0
	terrain.chunk_size = 32.0
	terrain.noise_amplitude = 0.0
	terrain.corridor_blend = 8.0
	terrain.wall_sections = [Vector4(100.0, 200.0, 20.0, -15.0)]
	terrain.wall_blend = 25.0


func test_wall_delta_eases_in_and_out_of_a_section() -> void:
	assert_almost_eq(terrain.wall_delta(90.0, -1.0), 0.0, 0.0001, "before the section")
	assert_almost_eq(terrain.wall_delta(100.0, -1.0), 0.0, 0.0001, "nothing yet at its start")
	assert_almost_eq(terrain.wall_delta(112.5, -1.0), 10.0, 0.0001, "halfway through the 25 m blend")
	assert_almost_eq(terrain.wall_delta(200.0, -1.0), 20.0, 0.0001, "the left delta in the middle")
	assert_almost_eq(terrain.wall_delta(200.0, 1.0), -15.0, 0.0001, "the right delta")
	assert_almost_eq(terrain.wall_delta(287.5, 1.0), -7.5, 0.0001, "easing out")
	assert_almost_eq(terrain.wall_delta(300.0, 1.0), 0.0, 0.0001, "gone at the end")
	assert_true(terrain.has_walls())
	assert_false(TerrainDef.new().has_walls())


func test_walls_rise_and_drops_fall_beyond_the_corridor_blend() -> void:
	var field := TerrainField.generate(sampler, trail, terrain)
	var full := trail.half_total_width() + terrain.corridor_blend + TerrainField.WALL_RISE + 4.0
	assert_almost_eq(field.height_at(-full, -200.0), 20.0, 0.3, "left wall at full height")
	assert_almost_eq(field.height_at(full, -200.0), -15.0, 0.3, "right side dropped away")
	var half_rise := trail.half_total_width() + terrain.corridor_blend + TerrainField.WALL_RISE * 0.5
	assert_between(field.height_at(-half_rise, -200.0), 5.0, 15.0, "climbing through the rise")
	var far := full + TerrainField.WALL_PLATEAU + TerrainField.WALL_FALLOFF + 6.0
	assert_almost_eq(field.height_at(-far, -200.0), 0.0, 0.05, "back to the natural ground far out")
	assert_almost_eq(field.height_at(-full, -50.0), 0.0, 0.05, "no wall before the section")
	assert_almost_eq(field.height_at(-full, -350.0), 0.0, 0.05, "none after it")
	assert_between(field.height_at(-full, -112.0), 5.0, 15.0, "easing in along the road")


func test_the_corridor_itself_is_untouched() -> void:
	var walled := TerrainField.generate(sampler, trail, terrain)
	terrain.wall_sections = []
	var plain := TerrainField.generate(sampler, trail, terrain)
	var edge := trail.half_total_width()
	for lateral: float in [0.0, -edge, edge, -(edge + terrain.corridor_blend - 0.5), edge + terrain.corridor_blend - 0.5]:
		var spot := sampler.position(200.0) + sampler.right(200.0) * lateral
		assert_almost_eq(walled.height_at(spot.x, spot.z), plain.height_at(spot.x, spot.z), 0.0001,
				"%.1f m from the centre line" % lateral)
	assert_eq(walled.edge_distances, plain.edge_distances, "walls do not change edge distances")


func test_kill_height_follows_the_drop() -> void:
	var field := TerrainField.generate(sampler, trail, terrain)
	assert_lt(field.lowest_height, -14.0)
	assert_almost_eq(field.kill_height(), field.lowest_height - terrain.kill_depth, 0.0001)


func test_generation_is_deterministic_with_walls_noise_and_a_bend() -> void:
	terrain.noise_amplitude = 15.0
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for point: Vector3 in [Vector3.ZERO, Vector3(0, 12, -130), Vector3(45, 21, -250), Vector3(80, 30, -400)]:
		curve.add_point(point)
	var bent := RoadSampler.new(curve, true, trail)
	var serial := TerrainField.generate(bent, trail, terrain, false)
	var parallel := TerrainField.generate(bent, trail, terrain, true)
	assert_eq(parallel.heights, serial.heights)
	assert_eq(parallel.edge_distances, serial.edge_distances)
	assert_eq(parallel.lowest_height, serial.lowest_height)


func test_hairpin_walls_preserve_both_road_corridors_and_their_sample_footprints() -> void:
	# The two legs are 60 m apart, within the canyon wall's 80 m reach. The
	# return road is higher and faces the other way, just like Rock Canyon.
	var curve := CurveGenerator.build_curve([
		["straight", 200.0, 0.0], ["arc", 30.0, 180.0, 0.1], ["straight", 200.0, 0.0],
	])
	var hairpin := RoadSampler.new(curve, false, trail)
	terrain.wall_sections = []
	var plain := TerrainField.generate(hairpin, trail, terrain)
	for delta: float in [22.0, -22.0]:
		terrain.wall_sections = [Vector4(40.0, 120.0, delta, 0.0)]
		var walled := TerrainField.generate(hairpin, trail, terrain)
		var corridor := trail.half_total_width() + terrain.corridor_blend
		for distance: float in [80.3, 100.7, hairpin.length - 119.7, hairpin.length - 99.3]:
			for lateral: float in [-corridor, -trail.half_total_width(), 0.0, trail.half_total_width(), corridor]:
				var spot := hairpin.position(distance) + hairpin.right(distance) * lateral
				var message := "wall %+.0f, road %.1f m, lateral %.1f m" % [delta, distance, lateral]
				assert_almost_eq(walled.height_at(spot.x, spot.z), plain.height_at(spot.x, spot.z),
						0.0001, message)
				# Comparing all four grid corners catches a wall bleeding through a
				# bilinear height query or a terrain triangle beside the road edge.
				var column := int(floor((spot.x - plain.origin.x) / plain.spacing))
				var row := int(floor((spot.z - plain.origin.y) / plain.spacing))
				for dx in 2:
					for dz in 2:
						var index := plain.index(column + dx, row + dz)
						assert_almost_eq(walled.heights[index], plain.heights[index], 0.0001, message + " footprint")
		assert_eq(walled.edge_distances, plain.edge_distances, "walls leave corridor metadata unchanged")
		var middle := hairpin.position(100.0) + hairpin.right(100.0) * -30.0
		assert_almost_eq(walled.height_at(middle.x, middle.z), delta, 0.3,
				"the intended wall/drop remains between the two protected roads")
		# Move from the return road toward the wall. The influence must fade in,
		# rather than jumping from the preserved corridor to the full wall.
		var return_distance := hairpin.length - 100.0
		var fractions: Array[float] = []
		for lateral: float in [-18.0, -21.0, -24.0, -30.0]:
			var spot := hairpin.position(return_distance) + hairpin.right(return_distance) * lateral
			var natural := plain.height_at(spot.x, spot.z)
			fractions.append((walled.height_at(spot.x, spot.z) - natural) / (delta - natural))
		assert_between(fractions[0], 0.0, 0.3, "small influence just beyond the protected footprint")
		assert_between(fractions[1], fractions[0], 0.8, "smoothly grows outside the other road")
		assert_between(fractions[2], fractions[1], 1.0, "keeps growing toward the plateau")
		assert_almost_eq(fractions[3], 1.0, 0.02, "full intended wall away from both roads")
