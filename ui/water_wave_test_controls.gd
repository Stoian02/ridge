class_name WaterWaveTestControls
extends VBoxContainer
## Plain, level-supplied prototype controls. No save setting or timed-level UI.

var prototype: WaterWaveTestGround
var menu: PauseMenu
var _buttons: Array[Button] = []
var _status: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiKit.label("Water waves — Test Ground", 28))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for mode in 3:
		var button := UiKit.button(WaterWaveTestGround.MODE_NAMES[mode], _choose.bind(mode))
		button.name = "WaveMode%d" % mode
		button.custom_minimum_size = Vector2(146.0, 76.0)
		button.add_theme_font_size_override("font_size", 28)
		button.toggle_mode = true
		row.add_child(button)
		_buttons.append(button)
	add_child(UiKit.label("Changing mode resets the car", 23))
	_status = UiKit.label("", 22)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(460.0, 54.0)
	add_child(_status)
	prototype.mode_changed.connect(_refresh)
	_refresh(prototype.mode)


func _choose(mode: int) -> void:
	menu.interaction_locked = true
	for button in _buttons:
		button.disabled = true
	await prototype.request_mode(mode)
	menu.interaction_locked = false
	_refresh(prototype.mode)


func _refresh(mode: int) -> void:
	for index in _buttons.size():
		_buttons[index].disabled = prototype.busy
		_buttons[index].set_pressed_no_signal(index == mode)
	_status.text = "Selected: %s\nWater areas are behind the start" % WaterWaveTestGround.MODE_NAMES[mode] \
		if prototype.error.is_empty() else prototype.error
