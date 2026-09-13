extends Node
## The one always-loaded game object (autoload "GameState", spec §5.6): the level
## catalog, the player's progress and its save file, and moving between scenes.

const CATALOG := preload("res://levels/catalog.tres")
const DEFAULT_SAVE_PATH := "user://save.json"
const MAIN_MENU := "res://ui/main_menu.tscn"
const LEVEL_SELECT := "res://ui/level_select.tscn"
const FREE_DRIVE := "res://levels/test_ground/test_ground.tscn"

var catalog: LevelCatalog = CATALOG
## Where progress is saved. Tests point this at a throwaway file (see SaveSandbox).
var save_path := DEFAULT_SAVE_PATH
var progress := Progress.new()
## Loads a scene by path. Tests replace it so a menu test records the request
## instead of swapping out the test runner.
var scene_changer: Callable


func _ready() -> void:
	scene_changer = Callable(get_tree(), "change_scene_to_file")
	reload()


## Reads progress from save_path, replacing what is in memory.
func reload() -> void:
	progress = Progress.from_dictionary(SaveSystem.read(save_path))


func save() -> Error:
	return SaveSystem.write(save_path, progress.to_dictionary())


## The catalog level whose scene is `scene_path`, or null (e.g. Free Drive).
func level_for_scene(scene_path: String) -> LevelDef:
	return catalog.find_by_scene(scene_path)


## Records a finished run and saves. Returns what Progress.record_finish returns.
func record_finish(level: LevelDef, time: float, splits: Dictionary) -> Dictionary:
	var result := progress.record_finish(level, time, splits)
	save()
	return result


func set_steer_mode(mode: String) -> void:
	progress.steer_mode = mode
	save()


## Leaves the current scene for `path`, unpausing first so the next scene runs.
func change_scene(path: String) -> void:
	get_tree().paused = false
	scene_changer.call(path)
