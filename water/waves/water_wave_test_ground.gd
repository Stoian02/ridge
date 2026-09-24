class_name WaterWaveTestGround
extends Node3D
## Scene-local prototype coordinator. No timed-level hookup or persistent setting.

signal mode_changed(mode: int)

enum Mode { OFF, CAR_WAVES, FULL }
const MODE_NAMES := ["Off", "Car waves", "Full"]

var mode: Mode = Mode.OFF
var course: WaterCourse
var rig: DrivingRig
var reset_car: Callable
var runtime: WaterWaveRuntime
var emitter: WaterWaveEmitter
var busy := false
var error := ""
var preparation_usec := 0
var _tops: Array[MeshInstance3D] = []
var _generation := -1
var _reset_serial := -1


func _ready() -> void:
	# Reset/rebuild detection must precede the runtime and ALL car probes.
	process_physics_priority = -60
	set_physics_process(false)


func setup(water_course: WaterCourse, driving_rig: DrivingRig, reset: Callable) -> void:
	course = water_course
	rig = driving_rig
	reset_car = reset


## UI entry: pause and draw an opaque cover before doing any optional preparation.
func request_mode(next: int) -> void:
	if busy or next == mode:
		return
	busy = true
	var was_paused := get_tree().paused
	get_tree().paused = true
	rig.touch_controls.release_all_touches()
	var cover := LoadingScreen.new()
	add_child(cover)
	cover.show_for("water waves")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	set_mode(next)
	if DisplayServer.get_name() != "headless":
		# Spawn faces away from water: use a covered all-top view, not an unseen
		# shader warm-up that merely waits for frames without submitting a top.
		var previous_camera := get_viewport().get_camera_3d()
		var warm_camera := Camera3D.new()
		add_child(warm_camera)
		warm_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		warm_camera.size = 240.0
		warm_camera.global_position = course.to_global(Vector3(110.0, 145.0, 240.0))
		warm_camera.look_at(course.to_global(Vector3(110.0, 0.0, 126.0)))
		warm_camera.make_current()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		if is_instance_valid(previous_camera):
			previous_camera.make_current()
		warm_camera.queue_free()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
	cover.queue_free()
	get_tree().paused = was_paused
	busy = false
	mode_changed.emit(mode)


## Synchronous core also used by headless lifecycle tests, never a timing pass.
func set_mode(next: int) -> bool:
	if next < Mode.OFF or next > Mode.FULL:
		return false
	if next == mode:
		return true
	if next != Mode.OFF and not _prepare():
		mode = Mode.OFF
		_set_active(false)
		mode_changed.emit(mode)
		return false
	mode = next as Mode
	course.water_world.clear_waves()
	if runtime != null:
		for index in runtime.views.size():
			var view := runtime.views[index]
			view.ambient = mode == Mode.FULL and index < 2
			if mode != Mode.OFF:
				var body: WaterBody = course.water_world.bodies[index]
				if not course.water_world.bind_wave(body, view.sampler, view.origin):
					error = "Water geometry changed; waves disabled"
					mode = Mode.OFF
					course.water_world.clear_waves()
					break
		_set_active(mode != Mode.OFF)
		reset_history()
	# Same Reset path as R, not a new spawn or modified flotation state.
	reset_car.call()
	mode_changed.emit(mode)
	return mode == next


func reset_history() -> void:
	if runtime != null:
		runtime.reset()
		emitter.source.reset()
	_reset_serial = rig.car.water.reset_serial


func _prepare() -> bool:
	if runtime != null and _generation == course.water_world.generation:
		return true
	_discard()
	error = ""
	if not course.global_basis.is_equal_approx(Basis.IDENTITY):
		error = "Wave prototype supports translated, horizontal Test Ground water only"
		return false
	var started := Time.get_ticks_usec()
	var cache := WaterWaveCourseCache.new()
	if not cache.prepare(course):
		error = cache.error
		return false
	if course.water_world.bodies.size() != 6:
		error = "Unexpected Test Ground water registry"
		return false
	runtime = WaterWaveRuntime.new()
	add_child(runtime)
	runtime.set_physics_process(false)
	for index in 6:
		var deep := index < 2
		var top := cache.tops[0 if deep else index - 1]
		var body := course.water_world.bodies[index]
		var x := WaterCourse.SHALLOW_X
		if deep:
			x = WaterCourse.CALM_X if index == 0 else WaterCourse.CURRENT_X
		var origin := course.global_position + Vector3(x, 0.0, WaterCourse.START_Z)
		var view := runtime.add_view(body.id, top, false)
		view.origin = origin
		var instance := MeshInstance3D.new()
		instance.mesh = top.mesh
		instance.material_override = view.material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
		instance.global_position = origin
		instance.hide()
		_tops.append(instance)
	emitter = WaterWaveEmitter.new()
	add_child(emitter)
	emitter.setup(rig.car, runtime)
	emitter.set_physics_process(false)
	_generation = course.water_world.generation
	preparation_usec = Time.get_ticks_usec() - started
	return true


func _set_active(active: bool) -> void:
	for top in _tops:
		top.visible = active
	for name: String in ["CalmWater", "CurrentWater", "ShallowWater"]:
		var flat := course.get_node_or_null(name) as MeshInstance3D
		if flat != null:
			flat.visible = not active
	course.set_process(not active)
	if runtime != null:
		runtime.set_physics_process(active)
	if emitter != null:
		emitter.set_physics_process(active)
	set_physics_process(active)


func _physics_process(_delta: float) -> void:
	if course.water_world.generation != _generation or rig.car.water.world != course.water_world:
		error = "Water world rebuilt; select a wave mode again"
		course.water_world.clear_waves()
		mode = Mode.OFF
		_set_active(false)
		reset_history()
		mode_changed.emit(mode)
		return
	if rig.car.water.reset_serial != _reset_serial:
		reset_history()


func _discard() -> void:
	if is_instance_valid(course):
		course.water_world.clear_waves()
	if runtime != null:
		runtime.free()
		runtime = null
	if emitter != null:
		emitter.free()
		emitter = null
	for top in _tops:
		top.free()
	_tops.clear()


func _exit_tree() -> void:
	if is_instance_valid(course):
		course.water_world.clear_waves()
