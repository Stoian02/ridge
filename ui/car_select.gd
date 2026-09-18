extends Control
## Car select (spec §5.2): one card per catalog car with a turning preview, its
## description and what it is best on, or how many stars unlock it. The last car
## chosen is highlighted. Tapping an unlocked card saves it and starts
## GameState.pending_scene. Back, Escape or the back gesture return to level select,
## or to the main menu when heading for Free Drive. A destination can recommend
## a car without changing which cars are unlocked or selectable.

const CARD_SIZE := Vector2(560.0, 640.0)
const PREVIEW_SIZE := Vector2i(480, 280)
const NAME_FONT := 56
const SELECTED_BORDER := Color(0.95, 0.72, 0.3)


func _ready() -> void:
	var column := UiKit.centered_column(self, UiKit.BACKGROUND)
	column.add_child(UiKit.label("Choose your car", UiKit.HEADING_FONT))
	column.add_child(UiKit.label(destination_text(GameState.pending_scene)))
	var level := GameState.level_for_scene(GameState.pending_scene)
	if level != null:
		var recommended := level.recommended_text(GameState.car_catalog)
		if not recommended.is_empty():
			column.add_child(UiKit.label(recommended))
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 30)
	column.add_child(cards)
	for car in GameState.car_catalog.cars:
		cards.add_child(_card(car))
	column.add_child(UiKit.button("Back", _back))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


## "Muddy Valley · Dirt, mud, creek", "Free Drive", or the level name alone when it
## lists no surfaces.
static func destination_text(scene_path: String) -> String:
	if scene_path == GameState.FREE_DRIVE:
		return "Free Drive"
	var level := GameState.level_for_scene(scene_path)
	if level == null:
		return ""
	if level.surfaces.is_empty():
		return level.display_name
	return "%s · %s" % [level.display_name, level.surfaces]


## "Earn 3 stars to unlock (you have 2)"
static func locked_text(car: CarDef, total_stars: int) -> String:
	return "Earn %d stars to unlock (you have %d)" % [car.unlock_stars, total_stars]


## The card for one car: a button that chooses it, disabled while locked.
func _card(car: CarDef) -> Button:
	var unlocked := GameState.is_car_unlocked(car)
	var card := Button.new()
	card.name = String(car.id)
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.disabled = not unlocked
	card.pressed.connect(_choose.bind(car))
	if unlocked and car == GameState.selected_car():
		for state: String in ["normal", "hover", "pressed"]:
			card.add_theme_stylebox_override(state, _selected_style())
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var preview_holder := CenterContainer.new()
	preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(CarPreview.new(car, PREVIEW_SIZE))
	content.add_child(preview_holder)
	content.add_child(UiKit.label(car.display_name, NAME_FONT))
	if unlocked:
		content.add_child(_wrapped(car.description))
		content.add_child(UiKit.label("Best on: %s" % car.best_on))
	else:
		content.add_child(_wrapped(locked_text(car, GameState.progress.total_stars(GameState.catalog))))
	return card


func _wrapped(text: String) -> Label:
	var result := UiKit.label(text)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = CARD_SIZE.x - 60.0
	return result


func _selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.27, 0.21, 0.17)
	style.border_color = SELECTED_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(10)
	return style


func _choose(car: CarDef) -> void:
	GameState.set_selected_car(car.id)
	if GameState.pending_scene.is_empty():
		GameState.change_scene(GameState.LEVEL_SELECT)
	else:
		GameState.change_scene(GameState.pending_scene)


func _back() -> void:
	if GameState.pending_scene == GameState.FREE_DRIVE:
		GameState.change_scene(GameState.MAIN_MENU)
	else:
		GameState.change_scene(GameState.LEVEL_SELECT)
