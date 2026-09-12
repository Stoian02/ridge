class_name RunRecorder
extends Node
## Records the car's telemetry every physics tick into a CSV file under
## user://runs/, so a run on the phone can be analysed afterwards.
## Toggle with F2 or the "Rec" touch button. Copy files off the phone with
## tools/pull_runs.sh.

signal recording_changed(is_recording: bool, path: String)

const RUNS_DIR := "user://runs"
const WHEEL_NAMES := ["fl", "fr", "rl", "rr"]
const WHEEL_FIELDS := ["contact", "surface", "load", "compression", "slip_ratio", "slip_angle_deg", "spin"]

@export var car: Car

var _file: FileAccess
var _path := ""
var _time := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.TOGGLE_RECORDING):
		toggle()


func _physics_process(delta: float) -> void:
	if is_recording() and car != null:
		_time += delta
		record(car.get_telemetry(), _time)


func is_recording() -> bool:
	return _file != null


func toggle() -> void:
	if is_recording():
		stop()
	else:
		start()


## Starts a new file. With no path, a timestamped file in RUNS_DIR is used.
## Returns the path, or "" if the file could not be opened.
func start(path: String = "") -> String:
	if is_recording():
		stop()
	if path.is_empty():
		DirAccess.make_dir_recursive_absolute(RUNS_DIR)
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		path = "%s/run_%s.csv" % [RUNS_DIR, stamp]
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("RunRecorder: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return ""
	_path = path
	_time = 0.0
	_file.store_line(csv_header())
	recording_changed.emit(true, _path)
	return _path


## Closes the file. Returns its path.
func stop() -> String:
	if not is_recording():
		return ""
	_file.close()
	_file = null
	print("RunRecorder: saved ", ProjectSettings.globalize_path(_path))
	recording_changed.emit(false, _path)
	return _path


func record(telemetry: Dictionary, time: float) -> void:
	if is_recording():
		_file.store_line(csv_row(telemetry, time))


static func csv_header() -> String:
	var columns := PackedStringArray(["time", "speed_kmh", "rpm", "gear", "throttle", "brake", "steer",
			"airborne", "pos_x", "pos_y", "pos_z", "pitch_deg", "yaw_deg", "roll_deg"])
	for wheel_name in WHEEL_NAMES:
		for field in WHEEL_FIELDS:
			columns.append("%s_%s" % [wheel_name, field])
	return ",".join(columns)


static func csv_row(telemetry: Dictionary, time: float) -> String:
	var pos: Vector3 = telemetry.position
	var rot: Vector3 = telemetry.rotation_deg
	var values := PackedStringArray([
		"%.4f" % time, "%.2f" % telemetry.speed_kmh, "%.0f" % telemetry.rpm, str(telemetry.gear),
		"%.3f" % telemetry.throttle, "%.3f" % telemetry.brake, "%.3f" % telemetry.steer,
		"1" if telemetry.airborne else "0",
		"%.3f" % pos.x, "%.3f" % pos.y, "%.3f" % pos.z,
		"%.2f" % rot.x, "%.2f" % rot.y, "%.2f" % rot.z,
	])
	for wheel: Dictionary in telemetry.wheels:
		values.append("1" if wheel.contact else "0")
		values.append(str(wheel.surface))
		values.append("%.1f" % wheel.load)
		values.append("%.4f" % wheel.compression)
		values.append("%.4f" % wheel.slip_ratio)
		values.append("%.3f" % wheel.slip_angle_deg)
		values.append("%.3f" % wheel.spin)
	return ",".join(values)
