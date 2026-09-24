extends Node
## Real-car bow diagnostic, not a performance benchmark. Same poses before/after.
## Cars are unfrozen, given initial motion, then use normal water/contact forces.

const OUTPUT := "user://wave_bow_check"
var _level: Node3D
var _rig: DrivingRig
var _waves: WaterWaveTestGround
var _rendered := false


func _ready() -> void:
	_rendered = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_level = load("res://levels/test_ground/test_ground.tscn").instantiate()
	(_level.get_node("DrivingRig") as DrivingRig).car_override = load("res://car/cars/offroad_4x4.tres")
	add_child(_level)
	_rig = _level.rig
	_waves = _level.water_waves
	_rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	if not _waves.set_mode(WaterWaveTestGround.Mode.CAR_WAVES):
		push_error(_waves.error)
		get_tree().quit(1)
		return
	for kind: String in ["forward", "reverse", "oblique", "slow"]:
		await _drive(kind)
	_level.queue_free()
	await get_tree().process_frame
	print("Bow diagnostic complete: ", ProjectSettings.globalize_path(OUTPUT))
	get_tree().quit()


func _drive(kind: String) -> void:
	# Half-metre depth on the original gentle ramp: no buoyancy/bed changes.
	var z := 68.5
	var start := Vector3(105.0, WaterCourse.pool_floor_height(0.0, z - WaterCourse.START_Z) + 1.0, z)
	var yaw := 0.0 if kind == "reverse" else PI
	var direction := Vector3(0.0, 0.0, 1.0)
	if kind == "oblique":
		direction = Vector3(0.6, 0.0, 0.8)
	var speed := 3.0 if kind == "slow" else 8.0
	_rig.place_car(Transform3D(Basis(Vector3.UP, yaw), start))
	await _ticks(Engine.physics_ticks_per_second)
	_rig.car.linear_velocity = direction * speed
	for wheel in _rig.car.wheels:
		wheel.spin_speed = speed / _rig.car.stats.wheel_radius * (-1.0 if kind == "reverse" else 1.0)
	_rig.car.input.virtual_throttle = 0.0
	await _ticks(Engine.physics_ticks_per_second / 3)
	var view := _waves.runtime.views[0]
	var snapshot := WaterWaveSnapshot.new()
	_waves.runtime.field.write_snapshot(view.body_id, false, snapshot)
	# Numeric isolation only; rendered capture retains entry/wake/spray normally.
	for index in WaterWaveProfile.PACKET_SLOTS:
		snapshot.packets[index] = Vector4.ZERO
	var sampler := WaterWaveSampler.new()
	sampler.configure(view.sampler.topology, snapshot)
	var exposed := 0
	var peak := 0.0
	var side_peak := 0.0
	var forward := Vector2(snapshot.bow_direction.x, snapshot.bow_direction.y)
	var side := Vector2(-forward.y, forward.x)
	var middle := Vector2(_rig.car.global_position.x - view.origin.x, _rig.car.global_position.z - view.origin.z)
	for index in sampler.topology.vertices.size():
		var height := sampler.vertex_offset(index)
		var local := _rig.car.to_local(sampler.topology.vertices[index] + view.origin)
		var at := Vector2(sampler.topology.vertices[index].x, sampler.topology.vertices[index].z)
		var outside := absf(local.x) > _rig.car.stats.body_size.x * 0.5 + 0.2 \
			or absf(local.z) > _rig.car.stats.body_size.z * 0.5 + 0.2
		if outside:
			peak = maxf(peak, height)
			if absf((at - middle).dot(side)) > _rig.car.stats.body_size.x * 0.5 + 0.2:
				side_peak = maxf(side_peak, height)
			if height >= 0.004:
				exposed += 1
	print("Bow case ", JSON.stringify({"case": kind, "velocity": str(_rig.car.linear_velocity),
		"bow": str(snapshot.bow), "direction": str(snapshot.bow_direction),
		"exposed_vertices_over_4mm": exposed, "exposed_peak_m": peak, "side_peak_m": side_peak}))
	if _rendered:
		get_tree().paused = true
		await _capture(kind + "_chase")
		var camera := Camera3D.new()
		_level.add_child(camera)
		camera.position = _rig.car.global_position + Vector3(-6.0, 5.0, 6.0)
		camera.look_at(_rig.car.global_position)
		camera.make_current()
		await _capture(kind + "_front_side")
		_rig.camera.make_current()
		camera.queue_free()
		get_tree().paused = false


func _ticks(count: int) -> void:
	for tick in count:
		await get_tree().physics_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUTPUT + "/" + label + ".png")
