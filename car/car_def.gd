class_name CarDef
extends Resource
## One selectable car (spec §3.1): its save key, name, how car select describes it,
## its physics stats, its low-poly body, and the total stars needed to unlock it.

## Stable key for save data. Never rename it once players have saves.
@export var id: StringName = &""
@export var display_name: String = ""
## One line for car select, e.g. "Heavy and torquey. Loves mud, slow on asphalt."
@export var description: String = ""
## The surfaces it suits, e.g. "Mud, rough ground".
@export var best_on: String = ""
@export var stats: CarStats
@export var body: CarBodyDef
## Total stars across all levels needed to drive it.
@export var unlock_stars: int = 0
