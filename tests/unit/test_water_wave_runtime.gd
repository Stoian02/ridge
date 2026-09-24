extends GutTest


func _top() -> WaterWaveMesh:
	var data := WaterWaveMesh.new()
	var top := PackedVector3Array([Vector3(-3.0, 1.0, -3.0), Vector3(3.0, 1.0, -3.0),
		Vector3(-3.0, 1.0, 3.0), Vector3(3.0, 1.0, -3.0), Vector3(3.0, 1.0, 3.0), Vector3(-3.0, 1.0, 3.0)])
	var bed := top.duplicate()
	for index in bed.size():
		bed[index].y = 0.0
	assert_true(data.build(top, bed), data.error)
	return data


func test_views_share_topology_but_never_material_or_packet_history() -> void:
	var runtime := WaterWaveRuntime.new()
	add_child_autofree(runtime)
	var top := _top()
	var calm := runtime.add_view(&"calm", top, false)
	var current := runtime.add_view(&"current", top, false)
	assert_eq(runtime.process_physics_priority, -50)
	assert_same(calm.sampler.topology, current.sampler.topology)
	assert_ne(calm.material, current.material)
	runtime.field.queue_packet(WaterWaveField.Kind.ENTRY, &"calm", Vector2.ZERO, Vector2.ZERO, 0.08)
	runtime._physics_process(0.0)
	runtime._physics_process(0.5)
	assert_ne(calm.sampler.height_at(Vector2(0.5, 0.0)), 1.0)
	assert_eq(current.sampler.height_at(Vector2(0.5, 0.0)), 1.0)
	assert_eq(calm.snapshot.serial, current.snapshot.serial)
	assert_eq(calm.material.get_shader_parameter("wave_packets"), calm.snapshot.packets)


func test_reset_clears_sources_and_refreshes_cached_answers() -> void:
	var runtime := WaterWaveRuntime.new()
	add_child_autofree(runtime)
	var view := runtime.add_view(&"a", _top(), false)
	runtime.field.queue_packet(WaterWaveField.Kind.ENTRY, &"a", Vector2.ZERO, Vector2.ZERO, 0.08)
	runtime._physics_process(0.0)
	runtime._physics_process(0.5)
	assert_ne(view.sampler.height_at(Vector2(0.5, 0.0)), 1.0)
	runtime.reset()
	assert_eq(view.sampler.height_at(Vector2(0.5, 0.0)), 1.0)
	assert_eq(runtime.field.active_count(), 0)


func test_scene_pause_freezes_snapshot_clock_and_render_uniforms() -> void:
	var runtime := WaterWaveRuntime.new()
	add_child_autofree(runtime)
	var view := runtime.add_view(&"a", _top(), true)
	await wait_physics_frames(2)
	var before := runtime.field.clock_seconds
	var phases := view.snapshot.ambient.duplicate()
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(runtime.field.clock_seconds, before)
	assert_eq(view.material.get_shader_parameter("wave_ambient"), phases)
	get_tree().paused = false
	await wait_physics_frames(2)
	assert_gt(runtime.field.clock_seconds, before)
