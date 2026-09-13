class_name UiKit
extends RefCounted
## The shared look of menus and overlays (spec §6.4): thumb-sized buttons, outlined
## labels in the HUD's text style, and dimmed full-screen backdrops. Functional
## first; the art pass comes later.

const BUTTON_SIZE := Vector2(460.0, 110.0)
const BUTTON_FONT := 44
const TITLE_FONT := 110
const HEADING_FONT := 72
const TEXT_FONT := 40
## Menu screens' background: a dark warm brown in the golden-hour palette.
const BACKGROUND := Color(0.16, 0.12, 0.1)


static func button(text: String, on_pressed: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = BUTTON_SIZE
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", BUTTON_FONT)
	result.pressed.connect(on_pressed)
	return result


static func label(text: String, font_size: int = TEXT_FONT) -> Label:
	var result := Label.new()
	result.text = text
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_outline_color", Color.BLACK)
	result.add_theme_constant_override("outline_size", 8)
	return result


## A full-screen backdrop of `color` that stops touches reaching what is behind it,
## with a centred column to add content to. Returns the column.
static func centered_column(parent: Node, color: Color) -> VBoxContainer:
	var backdrop := ColorRect.new()
	backdrop.color = color
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)
	return column


## A see-through dark tint for overlays drawn over a running level.
static func dim(alpha: float) -> Color:
	return Color(0.0, 0.0, 0.0, alpha)


## A StarRow wrapped so it sits centred in a column.
static func centered_stars(row: StarRow) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	return holder
