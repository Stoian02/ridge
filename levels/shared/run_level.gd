class_name RunLevel
extends Node3D
## A timed level: a generated trail, the driving rig and the run systems, wired
## together. Expects children named Trail (TrailLevel), DrivingRig,
## CheckpointTracker, ResetController, RunController and RunHud; adds its own
## PauseMenu and ResultsScreen. The Trail builds itself in its own _ready, which
## runs before this one.
## Its LevelDef comes from the catalog by scene path; a level that isn't in the
## catalog (one built by a test) runs without stars or saving.
## At the finish the pedals lock and the results appear straight away.

@onready var trail: TrailLevel = $Trail
@onready var rig: DrivingRig = $DrivingRig
@onready var tracker: CheckpointTracker = $CheckpointTracker
@onready var resets: ResetController = $ResetController
@onready var run: RunController = $RunController
@onready var hud: RunHud = $RunHud

var level: LevelDef
var pause_menu: PauseMenu
var results: ResultsScreen


func _ready() -> void:
	level = GameState.level_for_scene(scene_file_path)
	if level != null and GameState.progress.best_time(level.id) > 0.0:
		run.clock.set_reference_best(GameState.progress.best_time(level.id), GameState.progress.best_splits(level.id))
	tracker.setup(trail.checkpoints.reset_transforms)
	trail.checkpoints.gate_entered.connect(_on_gate_entered)
	resets.setup(rig, tracker, trail.kill_height())
	hud.setup(run)
	_add_overlays()
	run.run_finished.connect(_on_run_finished)
	run.countdown_started.connect(results.hide_results)
	run.setup(rig, tracker, resets, trail.start_transform())
	print("%s built in %.2f s" % [name, trail.build_seconds])


func _add_overlays() -> void:
	results = ResultsScreen.new()
	results.name = "ResultsScreen"
	add_child(results)
	results.retry_pressed.connect(_retry)
	results.next_pressed.connect(_next_level)
	results.level_select_pressed.connect(GameState.change_scene.bind(GameState.LEVEL_SELECT))
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.setup(rig)
	pause_menu.restart_pressed.connect(run.restart)
	pause_menu.level_select_pressed.connect(GameState.change_scene.bind(GameState.LEVEL_SELECT))
	pause_menu.main_menu_pressed.connect(GameState.change_scene.bind(GameState.MAIN_MENU))
	pause_menu.back_pressed.connect(_on_back)
	rig.pause_requested.connect(_on_pause_requested)


func _on_gate_entered(index: int, body: Node3D) -> void:
	if body == rig.car:
		tracker.enter_gate(index)


func _on_pause_requested() -> void:
	if not results.is_showing():
		pause_menu.toggle()


## The back gesture or Escape with the pause menu closed.
func _on_back() -> void:
	if results.is_showing():
		GameState.change_scene(GameState.LEVEL_SELECT)
	else:
		pause_menu.open()


func _on_run_finished(time: float, splits: Dictionary) -> void:
	var earned := 0
	var best := time
	var new_best := true
	var has_next := false
	if level != null:
		var result := GameState.record_finish(level, time, splits)
		earned = result["stars"]
		best = result["best_time"]
		new_best = result["new_best"]
		var next := GameState.catalog.next_after(level)
		has_next = next != null and GameState.progress.is_unlocked(GameState.catalog, next)
	results.show_results(time, earned, level, best, new_best, has_next)


func _retry() -> void:
	if scene_file_path.is_empty():
		run.restart()
	else:
		GameState.change_scene(scene_file_path)


func _next_level() -> void:
	var next := GameState.catalog.next_after(level) if level != null else null
	if next != null:
		GameState.change_scene(next.scene_path)
