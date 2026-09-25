extends Control
## The first screen (spec §3.2): the title, the player's total stars, Play (level
## select) and Free Drive (car select, then the Test Ground). The back gesture closes the app, as it
## does on any Android app's first screen.
## Launched with the argument --benchmark, or (in a debug build) with a "benchmark"
## file in user://, it goes straight to the load benchmark instead
## (debug/load_benchmark.tscn), so load times can be measured from a computer. On the
## phone, Android doesn't pass launch arguments on to the game, so use the file:
##   adb shell run-as com.ridge.game touch files/benchmark
## The file is deleted as the benchmark starts, so the next launch is normal.

const BENCHMARK_ARG := "--benchmark"
const BENCHMARK_FILE := "user://benchmark"
const BENCHMARK_SCENE := "res://debug/load_benchmark.tscn"
## The same trick for the loose-stone cost probe: touch "shelf_stress" instead.
const STRESS_FILE := "user://shelf_stress"
const STRESS_SCENE := "res://debug/shelf_stress.tscn"
## Android drops scene arguments; use this one-shot flag for water profiling.
const WATER_FILE := "user://water_benchmark"
const WATER_SCENE := "res://debug/water_benchmark.tscn"
const WATER_ACCEPTANCE_FILE := "user://water_acceptance"
const WATER_ACCEPTANCE_SCENE := "res://debug/water_acceptance.tscn"
## The wave playcheck needs a real renderer, so on Android it runs from a flag
## file like the others: adb shell run-as com.ridge.game touch files/wave_playcheck
const WAVE_CHECK_FILE := "user://wave_playcheck"
const WAVE_CHECK_SCENE := "res://debug/water_wave_pc_playcheck.tscn"
const WAVE_ACCEPTANCE_FILE := "user://wave_acceptance"
const WAVE_ACCEPTANCE_SCENE := "res://debug/water_wave_acceptance.tscn"


func _ready() -> void:
	if OS.is_debug_build() and FileAccess.file_exists(WAVE_ACCEPTANCE_FILE):
		get_tree().change_scene_to_file.call_deferred(WAVE_ACCEPTANCE_SCENE)
		return
	if OS.is_debug_build() and FileAccess.file_exists(WAVE_CHECK_FILE):
		DirAccess.remove_absolute(WAVE_CHECK_FILE)
		get_tree().change_scene_to_file.call_deferred(WAVE_CHECK_SCENE)
		return
	if OS.is_debug_build() and FileAccess.file_exists(WATER_ACCEPTANCE_FILE):
		# The acceptance scene reads and consumes the optional JSON configuration.
		get_tree().change_scene_to_file.call_deferred(WATER_ACCEPTANCE_SCENE)
		return
	if OS.is_debug_build() and FileAccess.file_exists(WATER_FILE):
		DirAccess.remove_absolute(WATER_FILE)
		get_tree().change_scene_to_file.call_deferred(WATER_SCENE)
		return
	var stressed := OS.is_debug_build() and FileAccess.file_exists(STRESS_FILE)
	if stressed:
		DirAccess.remove_absolute(STRESS_FILE)
		get_tree().change_scene_to_file.call_deferred(STRESS_SCENE)
		return
	var flagged := OS.is_debug_build() and FileAccess.file_exists(BENCHMARK_FILE)
	if flagged:
		DirAccess.remove_absolute(BENCHMARK_FILE)
	if flagged or wants_benchmark(OS.get_cmdline_args() + OS.get_cmdline_user_args()):
		get_tree().change_scene_to_file.call_deferred(BENCHMARK_SCENE)
		return
	var column := UiKit.centered_column(self, UiKit.BACKGROUND)
	column.add_child(UiKit.label("RIDGE", UiKit.TITLE_FONT))
	column.add_child(UiKit.label(stars_text()))
	column.add_child(UiKit.button("Play", GameState.change_scene.bind(GameState.LEVEL_SELECT)))
	column.add_child(UiKit.button("Free Drive", GameState.choose_car_for.bind(GameState.FREE_DRIVE)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


## True when the app was launched to run the load benchmark.
static func wants_benchmark(args: PackedStringArray) -> bool:
	return args.has(BENCHMARK_ARG)


## "4 / 6 stars" across the catalog.
static func stars_text() -> String:
	return "%d / %d stars" % [GameState.progress.total_stars(GameState.catalog),
			GameState.catalog.levels.size() * Stars.MAX]
