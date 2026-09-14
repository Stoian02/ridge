extends Control
## Level select (spec §3.3): one card per catalog level with its best time and stars,
## or a lock saying which level to finish first. Back, Escape or the back gesture
## return to the main menu.

const CARD_SIZE := Vector2(560.0, 340.0)
const CARD_STAR_SIZE := 64.0


func _ready() -> void:
	var column := UiKit.centered_column(self, UiKit.BACKGROUND)
	column.add_child(UiKit.label("Select level", UiKit.HEADING_FONT))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 30)
	column.add_child(cards)
	for level in GameState.catalog.levels:
		cards.add_child(_card(level))
	column.add_child(UiKit.button("Back", _back))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


## The card for one level: a button that opens it, disabled while locked.
func _card(level: LevelDef) -> Button:
	var progress := GameState.progress
	var unlocked := progress.is_unlocked(GameState.catalog, level)
	var card := Button.new()
	card.name = String(level.id)
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not unlocked
	card.pressed.connect(GameState.change_scene.bind(level.scene_path))
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(UiKit.label(level.display_name, UiKit.HEADING_FONT))
	if unlocked:
		var stars := StarRow.new()
		stars.star_size = CARD_STAR_SIZE
		stars.earned = progress.stars(level.id)
		content.add_child(UiKit.centered_stars(stars))
		content.add_child(UiKit.label(best_text(progress.best_time(level.id))))
	else:
		var previous := GameState.catalog.previous_of(level)
		content.add_child(UiKit.label("Finish %s to unlock" % previous.display_name))
	return card


## "Best  1:11.6", or "No time yet" for a level never finished.
static func best_text(best_time: float) -> String:
	return "Best  %s" % RunHud.format_time(best_time) if best_time > 0.0 else "No time yet"


func _back() -> void:
	GameState.change_scene(GameState.MAIN_MENU)
