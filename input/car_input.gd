class_name CarInput
extends Node
## The single source of driver intent. Combines keyboard/gamepad with "virtual"
## inputs (the on-screen touch controls, or scripted drivers in tests). The car
## reads steer/throttle/brake and never knows which device produced them.

signal reset_requested

## Final values the car reads. steer: -1 (left) .. 1 (right).
var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0

## While locked (the countdown), every driver input reads as zero. The
## drivetrain's auto-hold keeps a stopped car still; holding the brake instead
## would select reverse.
var locked: bool = false

## Written by touch controls or test scripts.
var virtual_steer: float = 0.0
var virtual_throttle: float = 0.0
var virtual_brake: float = 0.0


func _ready() -> void:
	InputActions.register()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.RESET_CAR):
		request_reset()


## Called by the car at the start of every physics tick.
func refresh() -> void:
	if locked:
		steer = 0.0
		throttle = 0.0
		brake = 0.0
		return
	var device_steer := Input.get_axis(InputActions.STEER_LEFT, InputActions.STEER_RIGHT)
	steer = clampf(device_steer + virtual_steer, -1.0, 1.0)
	throttle = maxf(Input.get_action_strength(InputActions.THROTTLE), virtual_throttle)
	brake = maxf(Input.get_action_strength(InputActions.BRAKE), virtual_brake)


func request_reset() -> void:
	reset_requested.emit()
