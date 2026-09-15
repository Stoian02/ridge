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


func _ready() -> void:
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
