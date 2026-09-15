class_name LoadingScreen
extends CanvasLayer
## A full-screen "Loading ..." cover shown while a level builds (GameState shows and
## hides it). It lives under the GameState autoload, so it survives the scene change.

## Above every level overlay (the pause menu is 20).
const LAYER := 100

var _label: Label


func _init() -> void:
	layer = LAYER
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var column := UiKit.centered_column(self, UiKit.BACKGROUND)
	_label = UiKit.label("Loading...", UiKit.HEADING_FONT)
	column.add_child(_label)


## Shows the cover for the place being loaded, e.g. "Loading Muddy Valley...".
func show_for(title: String) -> void:
	_label.text = "Loading %s..." % title
	visible = true


func text() -> String:
	return _label.text
