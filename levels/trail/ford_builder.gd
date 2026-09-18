class_name FordBuilder
extends Node3D
## Visual river, scrolling waterfall, mist and positional sound (M5 spec §9).
## The riverbed is the road/terrain collision, never the translucent water.
## A small rock face closes the ledge behind the waterfall into the terrain.

const STEP := 2.0
const LEDGE_RUN := FordDef.LEDGE_RUN
const SCROLL_PER_SECOND := 0.8
const MIST_AMOUNT := 32
const SOUND_DISTANCE := 80.0
const WATER_ALPHA := 0.75
const FOAM_ALPHA := 0.8
const ROCK_INSET := 0.15

## Heights and points in the trail's space (world space on shipped levels).
var water_levels := PackedFloat32Array()
var waterfall_feet := PackedVector3Array()
var waterfall_tops := PackedVector3Array()

var _waterfall_materials: Array[StandardMaterial3D] = []
var _players: Array[AudioStreamPlayer3D] = []


func build(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, trail: TrailDef) -> void:
	_stop_players()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	water_levels.clear()
	waterfall_feet.clear()
	waterfall_tops.clear()
	_waterfall_materials.clear()
	_players.clear()
	set_process(not trail.fords.is_empty())
	for i in trail.fords.size():
		_build_ford(sampler, profile, field, trail.fords[i], i)


func _stop_players() -> void:
	for player in _players:
		player.stop()


func _exit_tree() -> void:
	_stop_players()


func _process(delta: float) -> void:
	for material in _waterfall_materials:
		material.uv1_offset.y = fposmod(material.uv1_offset.y - delta * SCROLL_PER_SECOND, 1.0)


func _build_ford(sampler: RoadSampler, profile: RoadProfile, field: TerrainField, ford: FordDef, index: int) -> void:
	var centre := sampler.position(ford.distance)
	var across := ford.across(sampler)
	var along := Vector3.UP.cross(across)
	var floor := ford.floor_height(sampler, profile)
	var level := floor + ford.water_depth
	water_levels.append(level)
	_add_water(ford, index, centre, across, along, level)
	var foot := centre + across * ford.waterfall_offset
	foot.y = floor
	var top := foot + Vector3.UP * ford.waterfall_height
	waterfall_feet.append(foot)
	waterfall_tops.append(top)
	_add_rock_return(ford, index, foot, top, across, along, field)
	_add_waterfall(ford, index, foot, top, along)
	_add_mist(index, foot, ford.foam_color)
	_add_sound(index, foot)


func _add_water(ford: FordDef, index: int, centre: Vector3, across: Vector3, along: Vector3, level: float) -> void:
	var half_along := ford.water_half_width()
	var near := minf(ford.waterfall_offset, ford.river_reach)
	var far := maxf(ford.waterfall_offset, ford.river_reach)
	var count := maxi(1, ceili((far - near) / STEP))
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for step in count + 1:
		var mid := centre + across * lerpf(near, far, step / float(count))
		var back := mid - along * half_along
		var front := mid + along * half_along
		vertices.append(Vector3(back.x, level, back.z))
		vertices.append(Vector3(front.x, level, front.z))
		if step > 0:
			var i := vertices.size() - 4
			indices.append_array([i, i + 1, i + 2, i + 1, i + 3, i + 2])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(ford.water_color, WATER_ALPHA)
	material.roughness = 0.15
	material.metallic_specular = 0.8
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mesh("Water%d" % index, mesh, material)


## A vertical rock face and closed side/top returns, with the back edge on the
## raised terrain ledge. This makes the water come off solid rock rather than
## hanging in front of the heightfield's necessarily sloping cut.
func _add_rock_return(ford: FordDef, index: int, foot: Vector3, top: Vector3,
		across: Vector3, along: Vector3, field: TerrainField) -> void:
	var outward := across * signf(ford.river_reach - ford.waterfall_offset)
	var half := along * (ford.waterfall_width * 0.5 + FordDef.ROCK_MARGIN)
	var bottom_left := foot - half - outward * ROCK_INSET
	var bottom_right := foot + half - outward * ROCK_INSET
	var top_left := top - half - outward * ROCK_INSET
	var top_right := top + half - outward * ROCK_INSET
	var back_left := foot - half - outward * LEDGE_RUN
	var back_right := foot + half - outward * LEDGE_RUN
	back_left.y = maxf(top.y, field.height_at(back_left.x, back_left.z))
	back_right.y = maxf(top.y, field.height_at(back_right.x, back_right.z))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(tool, bottom_left, bottom_right, top_right, top_left, outward)
	_quad(tool, top_left, top_right, back_right, back_left, Vector3.UP)
	_triangle(tool, bottom_left, top_left, back_left, -along)
	_triangle(tool, bottom_right, back_right, top_right, along)
	# The underside meets the sloping heightfield; closing it also prevents
	# seeing a hollow rock wedge when looking up from the riverbank.
	_quad(tool, bottom_left, back_left, back_right, bottom_right, -Vector3.UP)
	var material := StandardMaterial3D.new()
	material.albedo_color = field.def.rock_color
	material.roughness = 0.95
	_add_mesh("Waterfall%dRock" % index, tool.commit(), material)


static func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	# Godot renders clockwise faces; enforce the requested outward normal.
	var facing := (c - a).cross(b - a)
	var corners: Array[Vector3] = [a, b, c]
	if facing.dot(normal) < 0.0:
		corners = [a, c, b]
	tool.set_normal(normal)
	for corner in corners:
		tool.add_vertex(corner)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_triangle(tool, a, b, c, normal)
	_triangle(tool, a, c, d, normal)


func _add_waterfall(ford: FordDef, index: int, foot: Vector3, top: Vector3, along: Vector3) -> void:
	var half := along * ford.waterfall_width * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners: Array[Vector3] = [foot - half, foot + half, top + half, top - half]
	var uvs: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)]
	var normal := along.cross(Vector3.UP)
	for i: int in [0, 1, 2, 0, 2, 3]:
		tool.set_uv(uvs[i])
		tool.set_normal(normal)
		tool.add_vertex(corners[i])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(ford.foam_color, FOAM_ALPHA)
	material.albedo_texture = _streaks(ford.seed)
	material.uv1_scale = Vector3(1.0, 3.0, 1.0)
	_waterfall_materials.append(material)
	_add_mesh("Waterfall%d" % index, tool.commit(), material)


## Seeded streak texture, generated synchronously and looped vertically. No
## background texture job remains alive when short unit-test levels close.
static func _streaks(seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.09
	noise.fractal_octaves = 2
	var image := Image.create(32, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var angle := TAU * y / 128.0
		for x in 32:
			var shade := 0.7 + 0.3 * noise.get_noise_3d(x * 3.0, cos(angle) * 5.0, sin(angle) * 5.0)
			image.set_pixel(x, y, Color(shade, shade, shade, 0.5 + shade * 0.5))
	return ImageTexture.create_from_image(image)


func _add_mist(index: int, foot: Vector3, color: Color) -> void:
	var mist := CPUParticles3D.new()
	mist.name = "Mist%d" % index
	mist.position = foot + Vector3.UP * 0.5
	mist.amount = MIST_AMOUNT
	mist.lifetime = 1.8
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = 1.5
	mist.direction = Vector3.UP
	mist.spread = 70.0
	mist.initial_velocity_min = 1.0
	mist.initial_velocity_max = 2.5
	mist.gravity = Vector3(0.0, 0.4, 0.0)
	mist.scale_amount_min = 1.0
	mist.scale_amount_max = 2.0
	mist.color = Color(color, 0.3)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = material
	mist.mesh = quad
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mist.visibility_range_end = 120.0
	mist.emitting = true
	add_child(mist)


func _add_sound(index: int, foot: Vector3) -> void:
	var player := AudioStreamPlayer3D.new()
	player.name = "Waterfall%dSound" % index
	player.stream = SoundSynth.sound(&"waterfall")
	player.max_distance = SOUND_DISTANCE
	player.position = foot + Vector3.UP * 2.0
	add_child(player)
	if not Engine.is_editor_hint():
		player.play()
	_players.append(player)


func _add_mesh(node_name: String, mesh: ArrayMesh, material: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 350.0
	add_child(instance)
