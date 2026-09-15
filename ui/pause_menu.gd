class_name PauseMenu
extends CanvasLayer
## The pause overlay (spec §3.5, §6.2). Opening it pauses the game and lets go of
## every touch. The menu runs even while the game is paused, and it answers the
## phone's back gesture and Escape: closing itself when open, otherwise asking the
## level (back_pressed). Free Drive turns off show_restart, which hides Restart and
## Level select (there is no run to restart). Change car is offered in both.

signal restart_pressed
signal level_select_pressed
## Change car: the level opens car select for itself.
signal car_select_pressed
signal main_menu_pressed
## Back gesture or Escape while the menu is closed; the level decides what it means.
signal back_pressed

## Draw above the HUD, the results and the touch controls.
const LAYER := 20

## Set before adding the menu to the tree.
var show_restart := true
var rig: DrivingRig

var _steering: Button
var _sound: Button
var _telemetry: Button
var _recording: Button


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		handle_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func setup(driving_rig: DrivingRig) -> void:
	rig = driving_rig


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	if rig != null:
		rig.touch_controls.release_all_touches()
	_refresh_labels()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


## The back gesture or Escape: closes the menu when it is open, otherwise asks the level.
func handle_back() -> void:
	if visible:
		close()
	else:
		back_pressed.emit()


func _on_restart() -> void:
	close()
	restart_pressed.emit()


func _on_steering() -> void:
	var controls := rig.touch_controls
	var next := TouchSteerLogic.Mode.BUTTONS if controls.steer_mode == TouchSteerLogic.Mode.ANALOG \
			else TouchSteerLogic.Mode.ANALOG
	controls.set_steer_mode(next)
	GameState.set_steer_mode(TouchControls.mode_name(next))
	_refresh_labels()


## Steps the Sound setting to the next quieter step, wrapping from Off to 100%.
func _on_sound() -> void:
	var steps := Progress.SOUND_STEPS
	var index := steps.find(GameState.progress.sound_volume)
	GameState.set_sound_volume(steps[(index + 1) % steps.size()])
	_refresh_labels()


func _on_telemetry() -> void:
	rig.telemetry.toggle()
	_refresh_labels()


func _on_recording() -> void:
	rig.recorder.toggle()
	_refresh_labels()


func _refresh_labels() -> void:
	var volume := GameState.progress.sound_volume
	_sound.text = "Sound: %s" % ("Off" if volume <= 0.0 else "%d%%" % roundi(volume * 100.0))
	if rig == null:
		return
	var buttons_mode := rig.touch_controls.steer_mode == TouchSteerLogic.Mode.BUTTONS
	_steering.text = "Steering: %s" % ("Buttons" if buttons_mode else "Analog")
	_telemetry.text = "Telemetry: %s" % ("On" if rig.telemetry.visible else "Off")
	_recording.text = "Rec: %s" % ("On" if rig.recorder.is_recording() else "Off")


func _build_ui() -> void:
	var column := UiKit.centered_column(self, UiKit.dim(0.55))
	column.add_child(UiKit.label("Paused", UiKit.HEADING_FONT))
	column.add_child(UiKit.button("Resume", close))
	var restart := UiKit.button("Restart", _on_restart)
	restart.visible = show_restart
	column.add_child(restart)
	column.add_child(UiKit.button("Change car", car_select_pressed.emit))
	var level_select := UiKit.button("Level select", level_select_pressed.emit)
	level_select.visible = show_restart
	column.add_child(level_select)
	column.add_child(UiKit.button("Main menu", main_menu_pressed.emit))
	_steering = UiKit.button("Steering", _on_steering)
	column.add_child(_steering)
	_sound = UiKit.button("Sound", _on_sound)
	column.add_child(_sound)
	var dev_row := HBoxContainer.new()
	dev_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dev_row.add_theme_constant_override("separation", 20)
	column.add_child(dev_row)
	_telemetry = UiKit.button("Telemetry", _on_telemetry)
	_telemetry.custom_minimum_size.x = 340.0
	dev_row.add_child(_telemetry)
	_recording = UiKit.button("Rec", _on_recording)
	_recording.custom_minimum_size.x = 340.0
	dev_row.add_child(_recording)
