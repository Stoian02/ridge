class_name RunHud
extends CanvasLayer
## The run's on-screen information: the countdown, the running time, checkpoint
## split flashes, and the finish panel with Restart.
## Coordinates are in the 1920x1080 canvas; the time sits top-right, clear of the
## top-strip buttons and the pedals.

signal restart_pressed

## How long a checkpoint split stays on screen (s).
const SPLIT_SECONDS := 2.0
## "GO" stays up this long after the countdown ends (s).
const GO_SECONDS := 0.6
const FASTER := Color(0.45, 0.9, 0.45)
const SLOWER := Color(0.95, 0.45, 0.35)

var controller: RunController

var _countdown: Label
var _time: Label
var _split: Label
var _finish_panel: PanelContainer
var _finish_time: Label
var _finish_best: Label
var _split_timer := 0.0


func _ready() -> void:
	_build_ui()


func setup(run_controller: RunController) -> void:
	controller = run_controller
	controller.checkpoint_reached.connect(show_split)
	controller.run_finished.connect(show_finish)
	controller.countdown_started.connect(hide_finish)


func _process(delta: float) -> void:
	if controller == null:
		return
	var clock := controller.clock
	var counting := clock.stage == RunClock.Stage.COUNTDOWN
	_countdown.visible = counting or (clock.stage == RunClock.Stage.RUNNING and clock.elapsed < GO_SECONDS)
	_countdown.text = countdown_text(clock)
	_time.text = format_time(clock.elapsed)
	if _split_timer > 0.0:
		_split_timer -= delta
		_split.visible = _split_timer > 0.0


## Time as m:ss.t
static func format_time(seconds: float) -> String:
	var tenths := int(floor(maxf(seconds, 0.0) * 10.0))
	return "%d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]


static func countdown_text(clock: RunClock) -> String:
	if clock.stage == RunClock.Stage.COUNTDOWN:
		return str(ceili(clock.countdown_remaining))
	return "GO"


static func split_text(index: int, split: float, delta: float) -> String:
	var text := "CP %d   %s" % [index, format_time(split)]
	if not is_nan(delta):
		text += "   %s%.1f" % ["+" if delta >= 0.0 else "-", absf(delta)]
	return text


func show_split(index: int, split: float, delta: float) -> void:
	_split.text = split_text(index, split, delta)
	if is_nan(delta):
		_split.modulate = Color.WHITE
	else:
		_split.modulate = FASTER if delta < 0.0 else SLOWER
	_split.visible = true
	_split_timer = SPLIT_SECONDS


func show_finish(time: float, session_best: float) -> void:
	_finish_time.text = "Finish  %s" % format_time(time)
	_finish_best.text = "Session best  %s" % format_time(session_best)
	_finish_panel.visible = true


func hide_finish() -> void:
	_finish_panel.visible = false
	_split.visible = false
	_split_timer = 0.0


func is_finish_visible() -> bool:
	return _finish_panel.visible


func _build_ui() -> void:
	_countdown = _label(160, Vector2(860.0, 380.0))
	_countdown.custom_minimum_size = Vector2(200.0, 200.0)
	_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown.visible = false
	_time = _label(60, Vector2(0.0, 24.0))
	_time.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_time.offset_left = -360.0
	_time.offset_right = -40.0
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_split = _label(40, Vector2(0.0, 110.0))
	_split.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_split.offset_left = -640.0
	_split.offset_right = -40.0
	_split.offset_top = 110.0
	_split.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_split.visible = false

	_finish_panel = PanelContainer.new()
	_finish_panel.set_anchors_preset(Control.PRESET_CENTER)
	_finish_panel.position = Vector2(-300.0, -170.0)
	_finish_panel.custom_minimum_size = Vector2(600.0, 340.0)
	_finish_panel.visible = false
	add_child(_finish_panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 24)
	_finish_panel.add_child(column)
	_finish_time = Label.new()
	_finish_time.add_theme_font_size_override("font_size", 64)
	_finish_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_finish_time)
	_finish_best = Label.new()
	_finish_best.add_theme_font_size_override("font_size", 40)
	_finish_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_finish_best)
	var restart := Button.new()
	restart.text = "Restart"
	restart.custom_minimum_size = Vector2(320.0, 110.0)
	restart.focus_mode = Control.FOCUS_NONE
	restart.add_theme_font_size_override("font_size", 44)
	restart.pressed.connect(restart_pressed.emit)
	column.add_child(restart)


func _label(font_size: int, at: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label
