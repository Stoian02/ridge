class_name DrivingRig
extends Node3D
## The car with everything needed to drive it: chase camera, touch controls,
## telemetry and run recorder. Levels place one, use place_car() to put the car
## somewhere, and listen to pause_requested. The steering style comes from the save.

signal pause_requested

@onready var car: Car = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var touch_controls: TouchControls = $TouchControls
@onready var telemetry: TelemetryOverlay = $TelemetryOverlay
@onready var recorder: RunRecorder = $RunRecorder


func _ready() -> void:
	touch_controls.pause_requested.connect(pause_requested.emit)
	touch_controls.set_steer_mode(TouchControls.mode_from_name(GameState.progress.steer_mode))


## Puts the car upright and still at `target`, with the camera straight behind it.
func place_car(target: Transform3D) -> void:
	car.reset_to(target)
	camera.snap_to_target()
