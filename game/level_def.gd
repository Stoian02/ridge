class_name LevelDef
extends Resource
## One timed level: its save key, name, scene and star targets (spec §5.1).

## Stable key for save data. Never rename it once players have saves.
@export var id: StringName = &""
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String = ""
## The level's surfaces in a few words for car select, e.g. "Dirt, mud, creek".
@export var surfaces: String = ""
## Advice only: every unlocked car can enter, regardless of the recommendation.
@export var recommended_car: StringName = &""
## Finish under this time for two stars (s).
@export var two_star_time: float = 0.0
## Finish under this time for three stars (s).
@export var three_star_time: float = 0.0


## A display-name recommendation, or no line for levels without one.
func recommended_text(cars: CarCatalog) -> String:
	if recommended_car == &"":
		return ""
	var car := cars.find_by_id(recommended_car)
	return "Recommended: %s" % (car.display_name if car != null else String(recommended_car))
