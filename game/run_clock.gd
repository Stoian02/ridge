class_name RunClock
extends RefCounted
## The timing of one run, as pure logic: countdown, running time, checkpoint
## splits and the best run to compare against. The run controller calls tick()
## every frame.

enum Stage { READY, COUNTDOWN, RUNNING, FINISHED }

## The countdown before GO (spec §3.1).
const COUNTDOWN_SECONDS := 3.0

var stage: Stage = Stage.READY
var countdown_remaining: float = 0.0
var elapsed: float = 0.0
## This run's split times, keyed by checkpoint index.
var splits: Dictionary = {}
## The best finished time to compare against: the saved all-time best, replaced by
## any faster run this session. -1.0 when there is none (spec §5.4).
var best_time: float = -1.0
## The splits of that best run, keyed by checkpoint index.
var best_splits: Dictionary = {}


## Starts comparing against a saved best run (time and its checkpoint splits).
func set_reference_best(time: float, reference_splits: Dictionary) -> void:
	best_time = time
	best_splits = reference_splits.duplicate()


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


## This run's split at a checkpoint minus the best run's split there, or NAN when
## there is nothing to compare (no split yet, or no best run).
func split_delta(index: int) -> float:
	if not splits.has(index) or not best_splits.has(index):
		return NAN
	return splits[index] - best_splits[index]


## Ends the run; a run faster than the best (or the first finish) becomes the best.
func finish() -> void:
	if stage != Stage.RUNNING:
		return
	stage = Stage.FINISHED
	if best_time < 0.0 or elapsed < best_time:
		best_time = elapsed
		best_splits = splits.duplicate()


## Back to READY for a new run; the best run is kept.
func restart() -> void:
	stage = Stage.READY
	countdown_remaining = 0.0
	elapsed = 0.0
	splits.clear()
