extends Node
## Measures the cost of the Rock Canyon shelf's loose stones without a driver:
## builds the level, shoves a patch of stones the way a car ploughing through
## would, then prints frame rate, physics time and how many stones are awake.
## It lives in debug/ so it is exported, for measuring on the phone:
##   adb shell run-as com.ridge.game touch files/shelf_stress
##   adb logcat -s godot
## Run it on the desktop with: godot --path . res://debug/shelf_stress.tscn

const LEVEL := "res://levels/rock_canyon/rock_canyon.tscn"
## Road distance the shove starts at (m) and how far along it travels.
const SHOVE_FROM := 1560.0
const SHOVE_LENGTH := 30.0
## Stones within this distance of the moving shove point are kicked (m).
const SHOVE_RADIUS := 3.5
const SHOVE_SPEED := 4.0
## Speed a shoved stone is given, whatever it weighs, so the probe compares
## like with like when stone sizes change (m/s).
const SHOVE_KICK := 2.5
## Seconds measured while shoving.
const SECONDS := 12.0

var _level: Node3D
var _talus: TalusBuilder
var _sampler: RoadSampler
## Stands in for the chase camera, so the activation window sees the shelf.
var _camera: Camera3D


func _ready() -> void:
	await get_tree().process_frame
	var started := Time.get_ticks_usec()
	var scene: PackedScene = load(LEVEL)
	var loaded := Time.get_ticks_usec()
	_level = scene.instantiate()
	add_child(_level)
	var ready_at := Time.get_ticks_usec()
	var trail: TrailLevel = _level.get_node("Trail")
	_talus = trail.talus_builder
	_sampler = trail.sampler
	_camera = Camera3D.new()
	_camera.name = "ProbeCamera"
	add_child(_camera)
	_camera.global_position = _sampler.position(SHOVE_FROM) + Vector3.UP * 3.0
	_camera.make_current()
	print("shelf_stress: load %.2f s, instantiate and ready %.2f s, total %.2f s, %d stones" % [
			(loaded - started) / 1000000.0, (ready_at - loaded) / 1000000.0,
			(ready_at - started) / 1000000.0, _talus.stones.size()])
	await _measure(2.0, false)
	await _measure(SECONDS, true)
	print("shelf_stress done")
	get_tree().quit()


## Measures for `seconds`, printing one line per second. With `shoving`, stones
## around a point walking along the shelf are kicked, like a car passing through.
func _measure(seconds: float, shoving: bool) -> void:
	var elapsed := 0.0
	var window := 0.0
	var frames := 0
	var worst := 0.0
	var physics_total := 0.0
	var awake_peak := 0
	while elapsed < seconds:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		if shoving:
			_shove(elapsed)
		elapsed += delta
		window += delta
		frames += 1
		worst = maxf(worst, delta)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		awake_peak = maxi(awake_peak, _talus.awake_count())
		if window >= 1.0:
			print("shelf_stress %-5s %4.1f s: %5.1f fps, worst frame %6.1f ms, physics %5.1f ms, awake %d" % [
					"shove" if shoving else "idle", elapsed, frames / window, worst * 1000.0,
					physics_total / frames * 1000.0, awake_peak])
			window = 0.0
			frames = 0
			worst = 0.0
			physics_total = 0.0
			awake_peak = 0


func _shove(elapsed: float) -> void:
	var travelled := minf(SHOVE_SPEED * elapsed, SHOVE_LENGTH)
	var centre := _sampler.position(SHOVE_FROM + travelled)
	_camera.global_position = centre + Vector3.UP * 3.0
	if SHOVE_SPEED * elapsed > SHOVE_LENGTH:
		return
	for stone: RigidBody3D in _talus.stones:
		var offset := stone.global_position - centre
		if offset.length() > SHOVE_RADIUS:
			continue
		stone.apply_central_impulse(Vector3(offset.x, 0.4, offset.z).normalized() * SHOVE_KICK * stone.mass)
