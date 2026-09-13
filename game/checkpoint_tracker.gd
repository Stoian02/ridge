class_name CheckpointTracker
extends Node
## Progress through a trail's checkpoint gates, in order. Gate 0 is the start
## line and the last gate is the finish. A gate only counts when it is the next
## one, so skipping ahead does nothing.

signal checkpoint_passed(index: int)
signal finished

## Where the car is put back after a reset, one per gate, in order.
var gate_transforms: Array[Transform3D] = []
## The gate that must be passed next.
var next_index: int = 1
## The last gate passed (0 = only the start line).
var last_passed: int = 0


func setup(transforms: Array[Transform3D]) -> void:
	gate_transforms = transforms
	restart()


func restart() -> void:
	next_index = 1
	last_passed = 0


func gate_count() -> int:
	return gate_transforms.size()


func is_finished() -> bool:
	return gate_transforms.size() > 1 and last_passed == gate_transforms.size() - 1


## Called when the car enters gate `index`.
func enter_gate(index: int) -> void:
	if index != next_index:
		return
	last_passed = index
	next_index += 1
	if index == gate_transforms.size() - 1:
		finished.emit()
	else:
		checkpoint_passed.emit(index)


## Where to put the car on a reset: the last gate it passed.
func reset_transform() -> Transform3D:
	return gate_transforms[last_passed]
