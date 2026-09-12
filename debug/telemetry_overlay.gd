class_name TelemetryOverlay
extends CanvasLayer
## Live numbers for tuning: performance, car state, and each wheel.
## Toggle with F1, the gamepad Back button, or the "Telemetry" touch button.

const WHEEL_NAMES := ["FL", "FR", "RL", "RR"]

@export var car: Car
@export var recorder: RunRecorder

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(20.0, 150.0)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.TOGGLE_TELEMETRY):
		toggle()


func _process(_delta: float) -> void:
	if not visible or car == null:
		return
	var text := format(car.get_telemetry(), performance_snapshot())
	if recorder != null and recorder.is_recording():
		text = "[REC]\n" + text
	_label.text = text


func toggle() -> void:
	visible = not visible


static func performance_snapshot() -> Dictionary:
	return {
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	}


static func format(telemetry: Dictionary, perf: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("%d fps   frame %.1f ms   physics %.1f ms" % [perf.fps, perf.process_ms, perf.physics_ms])
	lines.append("%.1f km/h   gear %s   %d rpm   %s" % [telemetry.speed_kmh, _gear_name(telemetry.gear),
			telemetry.rpm, "AIR" if telemetry.airborne else ""])
	lines.append("thr %.2f   brk %.2f   steer %+.2f" % [telemetry.throttle, telemetry.brake, telemetry.steer])
	for i in telemetry.wheels.size():
		var wheel: Dictionary = telemetry.wheels[i]
		lines.append("%s %-7s load %5.0f  comp %.2f  slip %+.2f  angle %+5.1f" % [WHEEL_NAMES[i],
				wheel.surface, wheel.load, wheel.compression, wheel.slip_ratio, wheel.slip_angle_deg])
	return "\n".join(lines)


static func _gear_name(gear: int) -> String:
	return "R" if gear < 0 else str(gear)
