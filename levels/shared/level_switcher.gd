class_name LevelSwitcher
extends RefCounted
## Switches between the game's levels with the Track button. Part B's level
## select replaces this.

const RALLY_ROAD := "res://levels/rally_road/rally_road.tscn"
const TEST_GROUND := "res://levels/test_ground/test_ground.tscn"


## The level the Track button leads to from `current_scene_path`.
static func other_level(current_scene_path: String) -> String:
	return TEST_GROUND if current_scene_path == RALLY_ROAD else RALLY_ROAD


static func switch_from(tree: SceneTree, current_scene_path: String) -> void:
	tree.change_scene_to_file(other_level(current_scene_path))
