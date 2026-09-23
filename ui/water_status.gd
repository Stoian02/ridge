class_name WaterStatus
extends CanvasLayer
## Non-interactive water warning; numbers and intake marker are debug-only.

var car: Car
var telemetry: TelemetryOverlay
var label: Label
var intake_marker: MeshInstance3D


func setup(driven: Car, debug_overlay: TelemetryOverlay) -> void:
	car = driven
	telemetry = debug_overlay
	label = Label.new()
	label.position = Vector2(660.0, 155.0)
	label.size = Vector2(620.0, 50.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	intake_marker = MeshInstance3D.new()
	intake_marker.name = "DebugIntake"
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	sphere.radial_segments = 8
	sphere.rings = 4
	intake_marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.75, 0.12)
	intake_marker.material_override = material
	intake_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	intake_marker.visible = false
	# Keep the marker in world space, not transformed as a CanvasLayer child.
	car.add_child(intake_marker)
	intake_marker.top_level = true


func _process(_delta: float) -> void:
	if car == null or car.water == null:
		return
	var state := car.water.state
	label.text = WaterFeedback.warning(state.sinking, state.stalled, state.restarting, state.intake_at_risk)
	label.visible = not label.text.is_empty()
	label.modulate = Color(1.0, 0.35, 0.25) if state.sinking or (state.stalled and not state.restarting) \
		else Color(1.0, 0.78, 0.25)
	intake_marker.visible = telemetry != null and telemetry.visible
	label.position.x = 1120.0 if intake_marker.visible else 660.0
	label.size.x = 580.0 if intake_marker.visible else 620.0
	intake_marker.global_position = car.water.intake_world_position


func notify_reset() -> void:
	label.text = ""
	label.visible = false
	intake_marker.visible = false
