class_name WaterWaveRuntime
extends Node
## Pause-aware immutable snapshot clock, shared by the lab and opt-in Test Ground.

const SURFACE := preload("res://water/waves/water_surface.gdshader")

class View:
	var body_id: StringName
	var origin := Vector3.ZERO
	var ambient := false
	var snapshot := WaterWaveSnapshot.new()
	var uploaded := WaterWaveSnapshot.new()
	var sampler := WaterWaveSampler.new()
	var material: ShaderMaterial

var field := WaterWaveField.new()
var views: Array[View] = []
var step_usec := 0


func _ready() -> void:
	process_physics_priority = -50


func add_view(body_id: StringName, topology: WaterWaveMesh, ambient: bool) -> View:
	var view := View.new()
	view.body_id = body_id
	view.ambient = ambient
	view.material = ShaderMaterial.new()
	view.material.shader = SURFACE
	field.write_snapshot(body_id, ambient, view.snapshot)
	view.sampler.configure(topology, view.snapshot)
	view.snapshot.upload(view.material)
	view.snapshot.upload_changed(view.material, view.uploaded)
	views.append(view)
	return view


func _physics_process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	field.step(delta)
	refresh()
	step_usec = Time.get_ticks_usec() - started


func refresh() -> void:
	for view: View in views:
		field.write_snapshot(view.body_id, view.ambient, view.snapshot)
		view.snapshot.upload_changed(view.material, view.uploaded)


func reset() -> void:
	field.reset()
	refresh()


func _exit_tree() -> void:
	field.reset()
	views.clear()
