class_name RunLevel
extends Node3D
## A timed level: a generated trail, the driving rig and the run systems, wired
## together. Expects children named Trail (TrailLevel), DrivingRig,
## CheckpointTracker, ResetController, RunController and RunHud. The Trail
## builds itself in its own _ready, which runs before this one.

@onready var trail: TrailLevel = $Trail
@onready var rig: DrivingRig = $DrivingRig
@onready var tracker: CheckpointTracker = $CheckpointTracker
@onready var resets: ResetController = $ResetController
@onready var run: RunController = $RunController
@onready var hud: RunHud = $RunHud


func _ready() -> void:
	tracker.setup(trail.checkpoints.reset_transforms)
	trail.checkpoints.gate_entered.connect(_on_gate_entered)
	resets.setup(rig, tracker, trail.kill_height())
	hud.setup(run)
	run.setup(rig, tracker, resets, trail.start_transform())
	hud.restart_pressed.connect(run.restart)
	rig.track_switch_requested.connect(_on_track_switch_requested)
	print("%s built in %.2f s" % [name, trail.build_seconds])


func _on_gate_entered(index: int, body: Node3D) -> void:
	if body == rig.car:
		tracker.enter_gate(index)


func _on_track_switch_requested() -> void:
	LevelSwitcher.switch_from(get_tree(), scene_file_path)
