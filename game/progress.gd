class_name Progress
extends RefCounted
## The player's progress in memory (spec §5.3): per level, the best time with that
## run's checkpoint splits and the most stars earned; plus steering/throttle controls and
## the last car chosen.
## Converts to and from the save file's Dictionary (spec §5.5).

const VERSION := 1
const STEER_ANALOG := "analog"
const STEER_BUTTONS := "buttons"
const THROTTLE_PEDAL := "pedal"
const THROTTLE_LEVER := "lever"
## The starter car's id (see CarCatalog).
const DEFAULT_CAR := "rally"

var steer_mode: String = STEER_ANALOG
## Touch throttle: the original on/off pedal, or the absolute lever slider.
var throttle_mode: String = THROTTLE_PEDAL
## Id of the car the player last chose in car select.
var selected_car: String = DEFAULT_CAR
## The Sound setting (M3B spec §7): one of SOUND_STEPS, 0 = off.
var sound_volume: float = 1.0
## Player-selected TC intervention: 0 = off, 1 = the car's original full assist.
var traction_control_strength: float = 1.0

## The values the Sound setting steps through, loudest first.
const SOUND_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.25, 0.0]

## Level id (String) -> {"best_time": float, "best_splits": {int: float}, "stars": int}.
var _levels := {}


## Best finish time on a level, or -1.0 when it has never been finished.
func best_time(id: StringName) -> float:
	return _record(id)["best_time"]


## Checkpoint index -> split time of the best run; empty when never finished.
func best_splits(id: StringName) -> Dictionary:
	return _record(id)["best_splits"].duplicate()


## Most stars ever earned on a level (0-3).
func stars(id: StringName) -> int:
	return _record(id)["stars"]


func total_stars(catalog: LevelCatalog) -> int:
	var total := 0
	for level in catalog.levels:
		total += stars(level.id)
	return total


## The first catalog level is always open; any other opens once the level before
## it has been finished. Levels outside the catalog are never unlocked.
func is_unlocked(catalog: LevelCatalog, level: LevelDef) -> bool:
	var index := catalog.levels.find(level)
	if index < 0:
		return false
	if index == 0:
		return true
	return stars(catalog.levels[index - 1].id) >= 1


## Records a finished run. Stars keep the most ever earned; the best time and its
## splits are replaced together, and only by a faster run.
## Returns {"stars": stars earned this run, "best_time": float, "new_best": bool}.
func record_finish(level: LevelDef, time: float, splits: Dictionary) -> Dictionary:
	var record := _record(level.id)
	var earned := Stars.for_time(time, level)
	var new_best: bool = record["best_time"] < 0.0 or time < record["best_time"]
	if new_best:
		record["best_time"] = time
		record["best_splits"] = splits.duplicate()
	record["stars"] = maxi(record["stars"], earned)
	_levels[String(level.id)] = record
	return {"stars": earned, "best_time": record["best_time"], "new_best": new_best}


func to_dictionary() -> Dictionary:
	var levels := {}
	for id in _levels:
		var record: Dictionary = _levels[id]
		var splits := {}
		for index in record["best_splits"]:
			splits[str(index)] = record["best_splits"][index]
		levels[id] = {"best_time": record["best_time"], "best_splits": splits, "stars": record["stars"]}
	return {"version": VERSION, "settings": {"steer_mode": steer_mode, "selected_car": selected_car,
			"sound_volume": sound_volume, "traction_control_strength": traction_control_strength,
			"throttle_mode": throttle_mode}, "levels": levels}


## Reads save data. Unknown keys are ignored; missing or wrongly typed values take
## their defaults, so a hand-edited or older file never breaks loading.
static func from_dictionary(data: Dictionary) -> Progress:
	var progress := Progress.new()
	var settings = data.get("settings")
	if settings is Dictionary and settings.get("steer_mode") in [STEER_ANALOG, STEER_BUTTONS]:
		progress.steer_mode = settings["steer_mode"]
	if settings is Dictionary and settings.get("throttle_mode") in [THROTTLE_PEDAL, THROTTLE_LEVER]:
		progress.throttle_mode = settings["throttle_mode"]
	var car_id = settings.get("selected_car") if settings is Dictionary else null
	if car_id is String and car_id != "":
		progress.selected_car = car_id
	var volume = settings.get("sound_volume") if settings is Dictionary else null
	if _is_number(volume) and SOUND_STEPS.has(float(volume)):
		progress.sound_volume = float(volume)
	var traction: Variant = settings.get("traction_control_strength") if settings is Dictionary else null
	if _is_number(traction) and is_finite(float(traction)):
		progress.traction_control_strength = clampf(float(traction), 0.0, 1.0)
	var levels = data.get("levels")
	if not levels is Dictionary:
		return progress
	for id in levels:
		var entry = levels[id]
		if not (id is String and entry is Dictionary):
			continue
		var record := _default_record()
		var best = entry.get("best_time")
		if _is_number(best) and best > 0.0:
			record["best_time"] = float(best)
			var splits = entry.get("best_splits")
			if splits is Dictionary:
				for key in splits:
					if str(key).is_valid_int() and _is_number(splits[key]):
						record["best_splits"][int(str(key))] = float(splits[key])
		var earned = entry.get("stars")
		if _is_number(earned):
			record["stars"] = clampi(int(earned), 0, Stars.MAX)
		progress._levels[id] = record
	return progress


func _record(id: StringName) -> Dictionary:
	var record: Dictionary = _levels.get(String(id), _default_record())
	return record.duplicate(true)


static func _default_record() -> Dictionary:
	return {"best_time": -1.0, "best_splits": {}, "stars": 0}


static func _is_number(value: Variant) -> bool:
	return value is float or value is int
