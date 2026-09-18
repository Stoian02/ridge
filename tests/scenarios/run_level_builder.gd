class_name RunLevelBuilder
extends RefCounted
## Builds a small RunLevel in code for scenario tests: a straight or gently
## curving trail, the driving rig, and the run systems. Touch controls are
## switched off so tests can drive through the car's virtual inputs.

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")


static func straight(test: GutTest, length: float, checkpoints: PackedFloat32Array,
		trail_def: TrailDef = null, car_def: CarDef = null) -> RunLevel:
	var trail := TrailLevel.new()
	trail.name = "Trail"
	# A scenario can reuse one authored trail across cars without its checkpoint
	# override leaking into the next run or into the caller's Resource.
	trail.trail = trail_def.duplicate(true) as TrailDef if trail_def != null else TrailDef.new()
	trail.trail.checkpoint_distances = checkpoints
	trail.terrain = TerrainDef.new()
	trail.terrain.margin = 60.0
	trail.terrain.chunk_size = 64.0
	trail.scatter = ScatterDef.new()
	var road := Path3D.new()
	road.name = "Road"
	road.curve = Curve3D.new()
	road.curve.bake_interval = 1.0
	road.curve.add_point(Vector3.ZERO)
	road.curve.add_point(Vector3(0.0, 0.0, -length))
	trail.add_child(road)

	var level := RunLevel.new()
	level.name = "TestRun"
	level.add_child(trail)
	var rig: DrivingRig = RIG_SCENE.instantiate()
	rig.name = "DrivingRig"
	if car_def != null:
		rig.car_override = car_def
	level.add_child(rig)
	var tracker := CheckpointTracker.new()
	tracker.name = "CheckpointTracker"
	level.add_child(tracker)
	var resets := ResetController.new()
	resets.name = "ResetController"
	level.add_child(resets)
	var run := RunController.new()
	run.name = "RunController"
	level.add_child(run)
	var hud := RunHud.new()
	hud.name = "RunHud"
	level.add_child(hud)
	test.add_child_autofree(level)
	rig.touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	return level
