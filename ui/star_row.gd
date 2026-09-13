class_name StarRow
extends Control
## A row of Stars.MAX stars drawn as shapes, `earned` of them filled. Drawn rather
## than typed because the default font has no star character.

const FILLED := Color(1.0, 0.8, 0.25)
const EMPTY := Color(1.0, 1.0, 1.0, 0.25)
## Inner corner radius as a share of the outer radius.
const INNER_RATIO := 0.45

var earned := 0:
	set(value):
		earned = clampi(value, 0, Stars.MAX)
		queue_redraw()
## Width and height of one star (px).
var star_size := 90.0:
	set(value):
		star_size = value
		_update_size()
var gap := 16.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_size()


func _draw() -> void:
	for i in Stars.MAX:
		var center := Vector2(star_size * 0.5 + i * (star_size + gap), star_size * 0.5)
		draw_colored_polygon(star_points(center, star_size * 0.5), FILLED if i < earned else EMPTY)


## The ten corners of a five-pointed star with its top point straight up.
static func star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var corner_radius := radius if i % 2 == 0 else radius * INNER_RATIO
		var angle := -PI * 0.5 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)
	return points


func _update_size() -> void:
	custom_minimum_size = Vector2(star_size * Stars.MAX + gap * (Stars.MAX - 1), star_size)
	queue_redraw()
