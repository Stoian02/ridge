class_name LevelCatalog
extends Resource
## The timed levels in unlock order (spec §5.1). Free Drive is not a catalog level.

@export var levels: Array[LevelDef] = []


func find_by_id(id: StringName) -> LevelDef:
	for level in levels:
		if level.id == id:
			return level
	return null


## The level whose scene is `scene_path`, so a level launched straight from the
## editor still finds its data. Null when the scene is not a catalog level.
func find_by_scene(scene_path: String) -> LevelDef:
	for level in levels:
		if level.scene_path == scene_path:
			return level
	return null


## The level after `level` in unlock order, or null for the last or an unknown level.
func next_after(level: LevelDef) -> LevelDef:
	var index := levels.find(level)
	if index < 0 or index + 1 >= levels.size():
		return null
	return levels[index + 1]


## The level before `level` in unlock order, or null for the first or an unknown level.
func previous_of(level: LevelDef) -> LevelDef:
	var index := levels.find(level)
	if index <= 0:
		return null
	return levels[index - 1]
