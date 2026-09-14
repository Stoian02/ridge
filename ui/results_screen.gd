class_name ResultsScreen
extends CanvasLayer
## The results overlay after a finish (spec §3.6): the run time, stars earned with the
## targets for each star, the all-time best, and Retry / Next level / Level select.
## A level without star times (one built by a test) shows only the time and best.

signal retry_pressed
signal next_pressed
signal level_select_pressed

## Draw above the HUD and the touch controls, below the pause menu.
const LAYER := 15

var stars: StarRow

var _time: Label
var _targets: Label
var _best: Label
var _unlocks: Label
var _next: Button


func _init() -> void:
	layer = LAYER


func _ready() -> void:
	_build_ui()
	visible = false


## Shows the overlay for a finish in `time` that earned `earned` stars on `level`
## (null for a level without star times).
## `new_cars` are the cars this finish unlocked (spec §5.3).
func show_results(time: float, earned: int, level: LevelDef, best_time: float, new_best: bool,
		has_next: bool, new_cars: Array[CarDef] = []) -> void:
	_time.text = RunHud.format_time(time)
	stars.earned = earned
	stars.visible = level != null
	_targets.text = targets_text(level) if level != null else ""
	_best.text = "New best!" if new_best else "Best  %s" % RunHud.format_time(best_time)
	_next.visible = has_next
	_unlocks.text = unlocks_text(new_cars)
	_unlocks.visible = not new_cars.is_empty()
	visible = true


func hide_results() -> void:
	visible = false


func is_showing() -> bool:
	return visible


## "New car unlocked: Off-road 4x4", one line per car; empty when there are none.
static func unlocks_text(new_cars: Array[CarDef]) -> String:
	var lines := PackedStringArray()
	for car in new_cars:
		lines.append("New car unlocked: %s" % car.display_name)
	return "\n".join(lines)


## "1 star: finish · 2 stars: under 1:25.0 · 3 stars: under 1:14.0"
static func targets_text(level: LevelDef) -> String:
	return "1 star: finish · 2 stars: under %s · 3 stars: under %s" % [
		RunHud.format_time(level.two_star_time), RunHud.format_time(level.three_star_time)]


func _build_ui() -> void:
	var column := UiKit.centered_column(self, UiKit.dim(0.45))
	column.add_child(UiKit.label("Finish", UiKit.HEADING_FONT))
	_time = UiKit.label("", UiKit.TITLE_FONT)
	column.add_child(_time)
	stars = StarRow.new()
	column.add_child(UiKit.centered_stars(stars))
	_targets = UiKit.label("")
	column.add_child(_targets)
	_best = UiKit.label("")
	column.add_child(_best)
	_unlocks = UiKit.label("")
	_unlocks.add_theme_color_override("font_color", Color(0.98, 0.8, 0.35))
	_unlocks.visible = false
	column.add_child(_unlocks)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	row.add_child(UiKit.button("Retry", retry_pressed.emit))
	_next = UiKit.button("Next level", next_pressed.emit)
	row.add_child(_next)
	row.add_child(UiKit.button("Level select", level_select_pressed.emit))
