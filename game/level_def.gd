class_name LevelDef
extends Resource
## One timed level: its save key, name, scene and star targets (spec §5.1).

## Stable key for save data. Never rename it once players have saves.
@export var id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
## The level's surfaces in a few words for car select, e.g. "Dirt, mud, creek".
@export var surfaces: String = ""
## Finish under this time for two stars (s).
@export var two_star_time: float = 0.0
## Finish under this time for three stars (s).
@export var three_star_time: float = 0.0
