extends Control
## The first screen (spec §3.2): the title, the player's total stars, Play (level
## select) and Free Drive (the Test Ground). The back gesture closes the app, as it
## does on any Android app's first screen.


func _ready() -> void:
	var column := UiKit.centered_column(self, UiKit.BACKGROUND)
	column.add_child(UiKit.label("RIDGE", UiKit.TITLE_FONT))
	column.add_child(UiKit.label(stars_text()))
	column.add_child(UiKit.button("Play", GameState.change_scene.bind(GameState.LEVEL_SELECT)))
	column.add_child(UiKit.button("Free Drive", GameState.change_scene.bind(GameState.FREE_DRIVE)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


## "4 / 6 stars" across the catalog.
static func stars_text() -> String:
	return "%d / %d stars" % [GameState.progress.total_stars(GameState.catalog),
			GameState.catalog.levels.size() * Stars.MAX]
