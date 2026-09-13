class_name RunClock
extends RefCounted
## The timing of one run, as pure logic: countdown, running time, checkpoint
## splits and the session best. The run controller calls tick() every frame.

enum Stage { READY, COUNTDOWN, RUNNING, FINISHED }

## The countdown before GO (spec §3.1).
const COUNTDOWN_SECONDS := 3.0

var stage: Stage = Stage.READY
var countdown_remaining: float = 0.0
var elapsed: float = 0.0
## This run's split times, keyed by checkpoint index.
var splits: Dictionary = {}
## Best finished time this session, or -1.0 before the first finish.
var session_best_time: float = -1.0
## The splits of the session-best run, keyed by checkpoint index.
var session_best_splits: Dictionary = {}


func start_countdown() -> void:
	stage = Stage.COUNTDOWN
	countdown_remaining = COUNTDOWN_SECONDS
	elapsed = 0.0
	splits.clear()


## Advances the clock. Returns true on the tick the countdown reaches GO.
func tick(delta: float) -> bool:
	match stage:
		Stage.COUNTDOWN:
			countdown_remaining -= delta
			if countdown_remaining <= 0.0:
				countdown_remaining = 0.0
				stage = Stage.RUNNING
				return true
		Stage.RUNNING:
			elapsed += delta
	return false


func pass_checkpoint(index: int) -> void:
	if stage == Stage.RUNNING:
		splits[index] = elapsed


## This run's split at a checkpoint minus the session-best split there, or NAN
## when there is nothing to compare (no split yet, or no finished run yet).
func split_delta(index: int) -> float:
	if not splits.has(index) or not session_best_splits.has(index):
		return NAN
	return splits[index] - session_best_splits[index]


func finish() -> void:
	if stage != Stage.RUNNING:
		return
	stage = Stage.FINISHED
	if session_best_time < 0.0 or elapsed < session_best_time:
		session_best_time = elapsed
		session_best_splits = splits.duplicate()


## Back to READY for a new run; the session best is kept.
func restart() -> void:
	stage = Stage.READY
	countdown_remaining = 0.0
	elapsed = 0.0
	splits.clear()
