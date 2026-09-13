class_name DrivingRig
extends Node3D
## The car with everything needed to drive it: chase camera, touch controls,
## telemetry and run recorder, wired together. Levels place one and use
## place_car() to put the car somewhere.

signal track_switch_requested

@onready var car: Car = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var touch_controls: TouchControls = $TouchControls
@onready var telemetry: TelemetryOverlay = $TelemetryOverlay
@onready var recorder: RunRecorder = $RunRecorder


func _ready() -> void:
	touch_controls.telemetry_toggled.connect(telemetry.toggle)
	touch_controls.recording_toggled.connect(recorder.toggle)
	touch_controls.track_switch_requested.connect(track_switch_requested.emit)


## Puts the car upright and still at `target`, with the camera straight behind it.
func place_car(target: Transform3D) -> void:
	car.reset_to(target)
	camera.snap_to_target()
