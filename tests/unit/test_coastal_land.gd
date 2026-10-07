extends GutTest
## Opt-in coastal land/barriers; old fixtures are checked independently, unchanged.

const TERRAIN := preload("res://levels/coastal_highway/coastal_highway_terrain.tres")
const TRAIL := preload("res://levels/coastal_highway/coastal_highway_trail.tres")
const CURVE := preload("res://levels/coastal_highway/coastal_highway_curve.tres")


func test_natural_shore_is_world_authored_and_serial_worker_results_are_exact() -> void:
	assert_null(TerrainDef.new().coast)
	assert_true(TrailDef.new().barriers.is_empty())
	assert_eq(TERRAIN.coast.validation_error(), "")
	var coast := CoastalTerrainDef.new()
	coast.shore = [Vector4(-100, 0, 24, 20), Vector4(100, 0, 24, 20)]
	coast.relief = 0
	var input := coast.snapshot()
	input.merge({"first": 0, "count": 1, "columns": 5, "origin": Vector2(-30, 0), "spacing": 10.0})
	var result := {}
	CoastalEarthworks.compute(input, result)
	assert_eq(result.heights, PackedFloat32Array([24, 24, 9, -6, -6]))
	# A frozen snapshot does not change when an author edits the resource.
	coast.shore[0] = Vector4(-100, 100, 60, 20)
	var repeated := {}
	CoastalEarthworks.compute(input, repeated)
	assert_eq(result.heights, repeated.heights)
	var serial := TerrainField.new()
	serial.origin = Vector2(-300, -800)
	serial.columns = 65
	serial.rows = 97
	serial.spacing = 3.0
	CoastalEarthworks.fill(serial, TERRAIN.coast, false)
	var parallel := TerrainField.new()
	parallel.origin = serial.origin
	parallel.columns = serial.columns
	parallel.rows = serial.rows
	parallel.spacing = serial.spacing
	CoastalEarthworks.fill(parallel, TERRAIN.coast, true)
	assert_eq(serial.heights, parallel.heights, "all rows, including worker boundaries")
	coast.shore = [Vector4(100, 0, 24, 20), Vector4(-100, 0, 24, 20)]
	assert_ne(coast.validation_error(), "")


func test_barriers_are_selective_seaward_and_flare_outside_the_road() -> void:
	assert_eq(TRAIL.barriers.size(), 3)
	var sampler := RoadSampler.new(CURVE, false, TRAIL)
	var coverage := 0.0
	for span: RoadBarrierDef in TRAIL.barriers:
		assert_eq(span.validation_error(TRAIL, sampler.length), "")
		coverage += span.length
		assert_eq(span.side, 1)
		assert_gt(sampler.right(span.start).x, 0.0, "east/seaward half-plane")
		assert_eq(span.end_weight(span.start), 0.0)
		assert_eq(span.end_weight(span.end()), 0.0)
		assert_eq(span.end_weight(span.start + span.length * 0.5), 1.0)
		for at: float in [span.start, span.start + span.length * 0.5, span.end()]:
			assert_gt(span.lateral(TRAIL, at) - span.width * 0.5, TRAIL.road_width_at(at) * 0.5 + 0.5)
	assert_eq(coverage, 460.0, "not a continuous fence")
	var invalid: RoadBarrierDef = TRAIL.barriers[0].duplicate()
	invalid.inset = 2.0
	assert_ne(invalid.validation_error(TRAIL, sampler.length), "")
	invalid.inset = 0.1
	invalid.start = 800
	assert_ne(invalid.validation_error(TRAIL, sampler.length), "", "jump remains clear")


func test_coastal_complete_fields_match_and_hairpin_support_stays_below_road() -> void:
	var sampler := RoadSampler.new(CURVE, false, TRAIL)
	var profile := RoadProfile.new(TRAIL, sampler.length)
	var serial := TerrainField.generate(sampler, TRAIL, TERRAIN, false, profile)
	var parallel := TerrainField.generate(sampler, TRAIL, TERRAIN, true, profile)
	assert_eq(serial.heights, parallel.heights)
	assert_eq(serial.portal_holes, parallel.portal_holes)
	for at: float in [1020, 1050, 1100, 1130, 1170, 1220, 1270, 1330]:
		for lateral: float in [-2, 0, 2]:
			var p := sampler.surface_point(at, lateral, profile)
			assert_lt(parallel.height_at(p.x, p.z), p.y, "neighbouring hairpin stamps cannot prop up tyres")


func test_coastal_earth_joins_match_terrain_color_and_worker_arrays() -> void:
	var terrain := TerrainDef.new()
	terrain.margin = 16
	terrain.chunk_size = 32
	terrain.coast = CoastalTerrainDef.new()
	terrain.coast.shore = [Vector4(-200, 20, 2, 15), Vector4(100, 25, 12, 15)]
	terrain.coast.relief = 0
	var def := TrailDef.new()
	def.terrain_blend_width = 3
	var curve := Curve3D.new()
	curve.add_point(Vector3(0, 3, 0))
	curve.add_point(Vector3(0, 3, -80))
	var sampler := RoadSampler.new(curve, false, def)
	var profile := RoadProfile.new(def, sampler.length)
	var field := TerrainField.generate(sampler, def, terrain, true, profile)
	var ground := TerrainBuilder.new()
	add_child_autofree(ground)
	ground._grid_indices(field.cells_per_chunk + 1)
	var arrays := ground._mesh_arrays(field, 0, 0, field.cells_per_chunk + 1, 1)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var join := RoadBlendBuilder.new()
	add_child_autofree(join)
	for row in field.cells_per_chunk + 1:
		for column in field.cells_per_chunk + 1:
			var color: Color = join._ground_vertex(field, Vector2i(column, row)).color
			assert_eq(color, colors[row * (field.cells_per_chunk + 1) + column], "same drawn ground colour")
	var recorder := preload("res://tools/record_build_details.gd")
	join.threaded = false
	join.build(sampler, profile, field, def)
	var expected: Array = recorder.tree_data(join)
	join.threaded = true
	join.build(sampler, profile, field, def)
	assert_eq(recorder.tree_data(join), expected, "complete colors, normals, geometry and collision")
