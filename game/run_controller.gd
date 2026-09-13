class_name RunController
extends Node
## Runs a timed run: a countdown with the pedals locked, the clock, checkpoint
## splits, the finish (pedals locked again so the car coasts over the line), and
## restarts. Owns the RunClock that the HUD reads.

signal countdown_started
## delta is the difference from the best run at this checkpoint, or NAN.
signal checkpoint_reached(index: int, split: float, delta: float)
## splits: this run's checkpoint index -> split time.
signal run_finished(time: float, splits: Dictionary)

var clock := RunClock.new()
var rig: DrivingRig
var tracker: CheckpointTracker
var start_transform: Transform3D


func setup(driving_rig: DrivingRig, checkpoint_tracker: CheckpointTracker, resets: ResetController,
		start: Transform3D) -> void:
	rig = driving_rig
	tracker = checkpoint_tracker
	start_transform = start
	tracker.checkpoint_passed.connect(_on_checkpoint_passed)
	tracker.finished.connect(_on_finished)
	resets.car_reset.connect(_on_car_reset)
	restart()


## Back to the start line and a fresh countdown.
func restart() -> void:
	tracker.restart()
	clock.restart()
	rig.place_car(start_transform)
	rig.car.input.locked = true
	clock.start_countdown()
	countdown_started.emit()


func _physics_process(delta: float) -> void:
	if rig != null and clock.tick(delta):
		rig.car.input.locked = false


func _on_checkpoint_passed(index: int) -> void:
	if clock.stage != RunClock.Stage.RUNNING:
		return
	clock.pass_checkpoint(index)
	checkpoint_reached.emit(index, clock.splits[index], clock.split_delta(index))


func _on_finished() -> void:
	if clock.stage != RunClock.Stage.RUNNING:
		return
	var splits := clock.splits.duplicate()
	clock.finish()
	rig.car.input.locked = true
	run_finished.emit(clock.elapsed, splits)


func _on_car_reset(_reason: StringName) -> void:
	if clock.stage == RunClock.Stage.COUNTDOWN:
		restart()
