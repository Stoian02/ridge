extends Node3D
## Explicit standalone preview/parity runner. No Car, DrivingRig or WaterWorld
## binding. Run with --verify to calibrate/read GPU heights and exit automatically.

const PROBE := preload("res://debug/water_wave_probe.gdshader")
var _runtime: WaterWaveRuntime
var _top: WaterWaveMesh
var _view: WaterWaveRuntime.View
var _elapsed := 0.0
var _next_entry := 0.0
var _next_wake := 0.0
var _verify := false


func _ready() -> void:
	_verify = "--verify" in OS.get_cmdline_user_args()
	process_physics_priority = 50
	var course := WaterCourse.new()
	add_child(course)
	course.set_process(false)
	_top = WaterWaveMesh.new()
	if not _top.build(course.pool_water_faces, course.pool_floor_faces, course.pool_water_colors):
		push_error(_top.error)
		get_tree().quit(1)
		return
	_runtime = WaterWaveRuntime.new()
	add_child(_runtime)
	_view = _runtime.add_view(&"calm", _top, true)
	# Keep the actual pool/closed banks, but replace only this unregistered visual.
	course.get_node("CalmWater").hide()
	var instance := MeshInstance3D.new()
	instance.mesh = _top.mesh
	instance.material_override = _view.material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = Vector3(WaterCourse.CALM_X, 0.0, WaterCourse.START_Z)
	add_child(instance)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -35.0, 0.0)
	add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.20, 0.28, 0.36)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.6
	environment.environment = settings
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(115.0, 10.0, 111.0)
	camera.look_at(Vector3(105.0, 2.82, 126.0))
	camera.current = true
	if _verify:
		set_physics_process(false)
		_runtime.set_physics_process(false)
		await _verify_gpu()


func _physics_process(delta: float) -> void:
	if _runtime == null:
		return
	_elapsed += delta
	var at := Vector2(sin(_elapsed * 0.3) * 3.0, 96.0 + sin(_elapsed * 0.6) * 5.0)
	var heading := Vector2(cos(_elapsed * 0.3) * 0.9, cos(_elapsed * 0.6) * 3.0).normalized()
	_runtime.field.set_bow(&"calm", at + heading * 1.5, heading, 1.8, 0.05)
	if _elapsed >= _next_entry:
		_runtime.field.queue_packet(WaterWaveField.Kind.ENTRY, &"calm", at, Vector2.ZERO, 0.08)
		_next_entry = _elapsed + 4.0
	if _elapsed >= _next_wake:
		_runtime.field.queue_packet(WaterWaveField.Kind.WAKE, &"calm", at - heading * 1.5, Vector2.ZERO, 0.03, heading)
		_next_wake = _elapsed + 0.3


func _verify_gpu() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU parity requires a real renderer, not the headless dummy backend")
		get_tree().quit(2)
		return
	var target := SubViewport.new()
	target.size = Vector2i(64, 1)
	target.disable_3d = true
	target.use_hdr_2d = false
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(target)
	var rectangle := ColorRect.new()
	rectangle.size = Vector2(64.0, 1.0)
	var material := ShaderMaterial.new()
	material.shader = PROBE
	rectangle.material = material
	target.add_child(rectangle)
	var points := PackedVector4Array()
	points.resize(64)
	for index in 64:
		points[index] = Vector4(0.0, 0.0, 0.12, lerpf(-0.12, 0.12, index / 63.0))
	material.set_shader_parameter("calibrate", true)
	material.set_shader_parameter("probe_points", points)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := target.get_texture().get_image()
	var calibration_error := 0.0
	for index in 64:
		calibration_error = maxf(calibration_error, absf(_decode(image.get_pixel(index, 0)) - points[index].w))
	print("wave GPU calibration maximum error_m=", calibration_error)
	if calibration_error > 0.00001:
		push_error("Readback encoding/colour pipeline calibration failed")
		get_tree().quit(1)
		return
	material.set_shader_parameter("calibrate", false)
	var maximum := 0.0
	var checked := 0
	for age: float in [0.0, 0.01, 0.12, 0.5, 1.0, 2.99, 3.99, 4.0, 600.0]:
		_runtime.field.reset()
		for index in 16:
			_runtime.field.queue_packet(WaterWaveField.Kind.ENTRY if index < 4 else WaterWaveField.Kind.WAKE,
				&"calm", Vector2((index % 4) * 0.3, 95.0 + (index / 4) * 0.3),
				Vector2(0.75, 0.0), 0.08, Vector2(1.0, 0.3).normalized())
		_runtime.field.set_bow(&"calm", Vector2(0.5, 96.0), Vector2(1.0, 0.3), 1.8, 0.05)
		_runtime.field.step(0.0)
		_runtime.field.step(age)
		_runtime.refresh()
		_view.snapshot.upload(material)
		for index in 64:
			points[index] = Vector4((index % 8 - 4) * 0.35, 96.0 + (index / 8 - 4) * 0.35,
				0.0 if index == 0 else (0.006 if index % 3 == 0 else 0.12), 0.0)
		material.set_shader_parameter("probe_points", points)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		image = target.get_texture().get_image()
		for index in 64:
			var point := points[index]
			var expected := WaterWaveMath.bounded(WaterWaveMath.raw(Vector2(point.x, point.y), _view.snapshot), point.z).x
			maximum = maxf(maximum, absf(_decode(image.get_pixel(index, 0)) - expected))
			checked += 1
	print("wave GPU parity checked=%d maximum_error_m=%.9f; desktop only, not a phone/performance pass" % [checked, maximum])
	if maximum > 0.001:
		push_error("CPU and GPU wave surface differ by more than 1 mm")
		get_tree().quit(1)
		return
	# Read actual mesh attributes, not an independently reconstructed grid. For
	# each rendered triangle, interpolate three GPU heights and compare the exact
	# standalone sampler at its centroid. This also catches UV/vertex quantization.
	_runtime.field.reset()
	_runtime.field.queue_packet(WaterWaveField.Kind.ENTRY, &"calm", Vector2(0.0, 96.0), Vector2.ZERO, 0.08)
	_runtime.field.step(0.0)
	_runtime.field.step(0.5)
	_runtime.refresh()
	_view.snapshot.upload(material)
	var arrays := _top.mesh.surface_get_arrays(0)
	var drawn_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var drawn_limits: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var centroids := PackedVector2Array()
	for index in 21:
		var triangle := mini(_top.indices.size() / 3 - 1, index * (_top.indices.size() / 3 - 1) / 20)
		var centroid := Vector2.ZERO
		for corner in 3:
			var id := _top.indices[triangle * 3 + corner]
			var point := drawn_vertices[id]
			points[index * 3 + corner] = Vector4(point.x, point.z, drawn_limits[id].x, 0.0)
			centroid += Vector2(point.x, point.z) / 3.0
		centroids.append(centroid)
	material.set_shader_parameter("probe_points", points)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	image = target.get_texture().get_image()
	var triangle_error := 0.0
	for index in centroids.size():
		var gpu_height := _top.level
		for corner in 3:
			gpu_height += _decode(image.get_pixel(index * 3 + corner, 0)) / 3.0
		var sampled := _view.sampler.height_at(centroids[index])
		triangle_error = maxf(triangle_error, absf(sampled - gpu_height))
	print("wave GPU drawn-triangle parity triangles=%d maximum_error_m=%.9f" % [centroids.size(), triangle_error])
	if triangle_error > 0.001 or not is_finite(triangle_error):
		push_error("Drawn triangle and physical sampler differ by more than 1 mm")
		get_tree().quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("capture="):
			_runtime.field.reset()
			_runtime.field.queue_packet(WaterWaveField.Kind.ENTRY, &"calm", Vector2(0.0, 96.0), Vector2.ZERO, 0.08)
			_runtime.field.step(0.0)
			_runtime.field.step(0.5)
			_runtime.refresh()
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("capture="))
	target.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _decode(color: Color) -> float:
	var value := (roundi(color.r * 255.0) << 16) | (roundi(color.g * 255.0) << 8) | roundi(color.b * 255.0)
	return value / 16777215.0 * 0.25 - 0.125
