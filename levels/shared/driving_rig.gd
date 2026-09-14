class_name DrivingRig
extends Node3D
## The car with everything needed to drive it: chase camera, touch controls,
## telemetry and run recorder. Levels place one, use place_car() to put the car
## somewhere, and listen to pause_requested. The steering style comes from the save.
## The car is the player's selected one (spec §3.4) unless car_override is set.

signal pause_requested

## Drive this car instead of the player's selected one (tests and tools).
@export var car_override: CarDef

## The car this rig drives, chosen as the rig enters the tree.
var car_def: CarDef

@onready var car: Car = $Car
@onready var camera: ChaseCamera = $ChaseCamera
@onready var touch_controls: TouchControls = $TouchControls
@onready var telemetry: TelemetryOverlay = $TelemetryOverlay
@onready var recorder: RunRecorder = $RunRecorder


## Runs before the car's own _ready applies its stats: gives the car the chosen
## car's stats and body, and names recordings after it.
func _enter_tree() -> void:
	car_def = car_override if car_override != null else GameState.selected_car()
	var driven: Car = $Car
	driven.stats = car_def.stats
	driven.body_def = car_def.body
	($RunRecorder as RunRecorder).car_id = String(car_def.id)


func _ready() -> void:
	touch_controls.pause_requested.connect(pause_requested.emit)
	touch_controls.set_steer_mode(TouchControls.mode_from_name(GameState.progress.steer_mode))


## Puts the car upright and still at `target`, with the camera straight behind it.
func place_car(target: Transform3D) -> void:
	car.reset_to(target)
	camera.snap_to_target()
