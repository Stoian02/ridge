extends GutTest
## The driving rig drives the selected car, or an override (spec §3.4).

const RIG_SCENE := preload("res://levels/shared/driving_rig.tscn")
const RALLY := preload("res://car/cars/rally.tres")
const OFFROAD := preload("res://car/cars/offroad_4x4.tres")

var state: Node


func before_each() -> void:
	SaveSandbox.enter()
	state = SaveSandbox.game_state()


func after_each() -> void:
	SaveSandbox.leave()


func _rig(override: CarDef = null) -> DrivingRig:
	var rig: DrivingRig = RIG_SCENE.instantiate()
	rig.car_override = override
	add_child_autofree(rig)
	return rig


func test_the_rig_drives_the_selected_car() -> void:
	var first := _rig()
	assert_eq(first.car_def, RALLY, "the starter car by default")
	assert_eq(first.car.stats, RALLY.stats)
	assert_eq(first.car.body_def, RALLY.body)
	state.record_finish(state.catalog.levels[0], 60.0, {})
	state.set_selected_car(&"offroad_4x4")
	var second := _rig()
	assert_eq(second.car_def, OFFROAD)
	assert_eq(second.car.stats, OFFROAD.stats)
	assert_almost_eq(second.car.mass, OFFROAD.stats.mass, 0.001, "the car took the 4x4's stats")


func test_an_override_beats_the_selection() -> void:
	var rig := _rig(OFFROAD)
	assert_eq(rig.car_def, OFFROAD, "even while the 4x4 is locked")
	assert_eq(rig.car.body_def, OFFROAD.body)


func test_recordings_are_named_after_the_car() -> void:
	var rig := _rig(OFFROAD)
	var path := rig.recorder.start()
	rig.recorder.stop()
	assert_true(path.ends_with("_offroad_4x4.csv"), path)
	DirAccess.remove_absolute(path)
