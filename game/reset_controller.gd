class_name ResetController
extends Node
## Puts the car back at the last passed checkpoint when the player taps Reset,
## when it stays flipped for 2 s, or when it falls off the map. The run clock
## is not touched: lost time is the only penalty.

signal car_reset(reason: StringName)

var rig: DrivingRig
var tracker: CheckpointTracker
## Falling below this height counts as falling off the map.
var kill_height := -INF
var flip_detector := FlipDetector.new()


func setup(driving_rig: DrivingRig, checkpoint_tracker: CheckpointTracker, fall_height: float) -> void:
	rig = driving_rig
	tracker = checkpoint_tracker
	kill_height = fall_height
	rig.car.input.reset_requested.connect(reset_car.bind(&"button"))


func _physics_process(delta: float) -> void:
	if rig == null:
		return
	var car := rig.car
	if car.global_position.y < kill_height:
		reset_car(&"fell")
	elif flip_detector.update(delta, car.global_basis.y, car.linear_velocity.length()):
		reset_car(&"flipped")


func reset_car(reason: StringName) -> void:
	rig.place_car(tracker.reset_transform())
	flip_detector.reset()
	car_reset.emit(reason)
