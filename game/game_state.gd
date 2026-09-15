extends Node
## The one always-loaded game object (autoload "GameState", spec §5.6): the level
## catalog, the player's progress and its save file, and moving between scenes.

const CATALOG := preload("res://levels/catalog.tres")
const DEFAULT_SAVE_PATH := "user://save.json"
const MAIN_MENU := "res://ui/main_menu.tscn"
const LEVEL_SELECT := "res://ui/level_select.tscn"
const FREE_DRIVE := "res://levels/test_ground/test_ground.tscn"
const CAR_SELECT := "res://ui/car_select.tscn"
const CAR_CATALOG := preload("res://car/car_catalog.tres")

var catalog: LevelCatalog = CATALOG
## Where progress is saved. Tests point this at a throwaway file (see SaveSandbox).
var save_path := DEFAULT_SAVE_PATH
var progress := Progress.new()
## Loads a scene by path. Tests replace it so a menu test records the request
## instead of swapping out the test runner.
var scene_changer: Callable
var car_catalog: CarCatalog = CAR_CATALOG
## The scene car select starts once a car is chosen: a level, or Free Drive.
var pending_scene := ""


func _ready() -> void:
	scene_changer = Callable(get_tree(), "change_scene_to_file")
	reload()


## Reads progress from save_path, replacing what is in memory, and applies its Sound setting.
func reload() -> void:
	progress = Progress.from_dictionary(SaveSystem.read(save_path))
	apply_sound_volume()


func save() -> Error:
	return SaveSystem.write(save_path, progress.to_dictionary())


## The catalog level whose scene is `scene_path`, or null (e.g. Free Drive).
func level_for_scene(scene_path: String) -> LevelDef:
	return catalog.find_by_scene(scene_path)


## Records a finished run and saves. Returns what Progress.record_finish returns,
## plus "new_cars": the cars (Array[CarDef]) this finish unlocked.
func record_finish(level: LevelDef, time: float, splits: Dictionary) -> Dictionary:
	var stars_before := progress.total_stars(catalog)
	var result := progress.record_finish(level, time, splits)
	save()
	result["new_cars"] = car_catalog.newly_unlocked(stars_before, progress.total_stars(catalog))
	return result


func set_steer_mode(mode: String) -> void:
	progress.steer_mode = mode
	save()


## The Sound setting (M3B spec §7): stores, applies and saves it.
func set_sound_volume(value: float) -> void:
	progress.sound_volume = clampf(value, 0.0, 1.0)
	apply_sound_volume()
	save()


## Sets the Master bus from the Sound setting; 0 mutes it.
func apply_sound_volume() -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, progress.sound_volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(progress.sound_volume, 0.0001)))


## The car to drive: the player's last choice while it exists and is unlocked,
## otherwise the starter car.
func selected_car() -> CarDef:
	var car := car_catalog.find_by_id(StringName(progress.selected_car))
	if car == null or not is_car_unlocked(car):
		return car_catalog.cars[0]
	return car


func is_car_unlocked(car: CarDef) -> bool:
	return progress.total_stars(catalog) >= car.unlock_stars


func set_selected_car(id: StringName) -> void:
	progress.selected_car = String(id)
	save()


## Opens car select, which then starts `scene_path` with the chosen car.
func choose_car_for(scene_path: String) -> void:
	pending_scene = scene_path
	change_scene(CAR_SELECT)


## Leaves the current scene for `path`, unpausing first so the next scene runs.
func change_scene(path: String) -> void:
	get_tree().paused = false
	scene_changer.call(path)
