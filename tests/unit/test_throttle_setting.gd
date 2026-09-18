extends GutTest
## The saved throttle setting (M5 spec §11.1): Progress round trip, the pause
## menu's Throttle row, and the driving rig applying it.

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")


func before_each() -> void:
	SaveSandbox.enter()


func after_each() -> void:
	get_tree().paused = false
	SaveSandbox.leave()


func test_throttle_mode_round_trips_and_rejects_unknown_values() -> void:
	var progress := Progress.new()
	assert_eq(progress.throttle_mode, Progress.THROTTLE_PEDAL, "the pedal is the default")
	progress.throttle_mode = Progress.THROTTLE_LEVER
	assert_eq(Progress.from_dictionary(progress.to_dictionary()).throttle_mode, Progress.THROTTLE_LEVER)
	assert_eq(Progress.from_dictionary({"settings": {"throttle_mode": "joystick"}}).throttle_mode, Progress.THROTTLE_PEDAL, "unknown value")
	assert_eq(Progress.from_dictionary({"settings": {"throttle_mode": 3}}).throttle_mode, Progress.THROTTLE_PEDAL, "wrong type")
	assert_eq(Progress.from_dictionary({"settings": {"steer_mode": "analog"}}).throttle_mode, Progress.THROTTLE_PEDAL, "an older save")
	assert_eq(Progress.from_dictionary({}).throttle_mode, Progress.THROTTLE_PEDAL)


func test_the_pause_menu_switches_the_throttle_and_saves_it() -> void:
	var rig: DrivingRig = RIG_SCENE.instantiate()
	add_child_autofree(rig)
	rig.touch_controls.screen_size_override = Vector2(1920.0, 1080.0)
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	menu.setup(rig)
	menu.open()
	var throttle: Button = menu.find_children("*", "Button", true, false).filter(
			func(b: Button) -> bool: return b.text.begins_with("Throttle"))[0]
	assert_eq(throttle.text, "Throttle: Pedal")
	throttle.pressed.emit()
	assert_eq(rig.touch_controls.throttle_mode, TouchThrottleLogic.Mode.LEVER)
	assert_eq(throttle.text, "Throttle: Lever")
	assert_eq(SaveSystem.read(SaveSandbox.PATH)["settings"]["throttle_mode"], Progress.THROTTLE_LEVER)
	throttle.pressed.emit()
	assert_eq(throttle.text, "Throttle: Pedal")
	var content: VBoxContainer = menu.find_child("PauseContent", true, false)
	assert_lt(content.get_combined_minimum_size().y, 1080.0, "still fits the landscape viewport")


func test_a_rig_applies_the_saved_throttle_mode() -> void:
	var state := SaveSandbox.game_state()
	state.set_throttle_mode(Progress.THROTTLE_LEVER)
	var rig: DrivingRig = RIG_SCENE.instantiate()
	add_child_autofree(rig)
	assert_eq(rig.touch_controls.throttle_mode, TouchThrottleLogic.Mode.LEVER)
