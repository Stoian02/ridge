class_name SaveSandbox
extends RefCounted
## Points GameState at a throwaway save file and records scene changes instead of
## performing them, so tests never touch the player's real save and never swap out
## the test runner. Tests may also swap GameState's catalog; leave() restores it.
## Call enter() before a test uses GameState and leave() after.

const PATH := "user://test_sandbox/save.json"

## Scene paths requested through GameState.change_scene since enter().
static var requested_scenes: Array[String] = []
static var _real_changer: Callable
static var _real_catalog: LevelCatalog


static func enter() -> void:
	clear_files()
	requested_scenes.clear()
	var state := game_state()
	_real_changer = state.scene_changer
	_real_catalog = state.catalog
	state.save_path = PATH
	state.scene_changer = func(path: String) -> void: requested_scenes.append(path)
	state.reload()


static func leave() -> void:
	var state := game_state()
	state.get_tree().paused = false
	state.scene_changer = _real_changer
	state.catalog = _real_catalog
	state.save_path = state.DEFAULT_SAVE_PATH
	state.reload()
	clear_files()


static func clear_files() -> void:
	for suffix in ["", ".tmp", ".bad"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


## The GameState autoload (it has no class_name, so it is reached through the tree).
static func game_state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")
