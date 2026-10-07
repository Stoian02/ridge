class_name StoneBridgeDef
extends Resource
## Independent asphalt-deck masonry bridge. Never inherits log-bridge physics.

@export var start: float = 2055.0
@export var length: float = 18.0
@export var clear_width: float = 7.0
@export var parapet_height: float = 0.7
@export var parapet_width: float = 0.5
@export var crest: float = 0.15
## Solid abutments flank the clear arch; its crown remains below the deck.
@export var abutment_length: float = 3.0
@export var arch_rise: float = 3.5
@export var crown_thickness: float = 0.9
@export var channel_depth: float = 5.5
## Dry channel reach across the road, before a smooth return to natural ground.
@export var channel_half_width: float = 24.0
@export var channel_blend: float = 8.0
@export var stone_color: Color = Color(0.49, 0.46, 0.40)


func end() -> float:
	return start + length


func contains(distance: float) -> bool:
	return distance >= start and distance < end()


func height_offset(distance: float) -> float:
	if distance <= start or distance >= end():
		return 0.0
	var wave := sin(PI * (distance - start) / length)
	return crest * wave * wave


func arch_start() -> float:
	return start + abutment_length


func arch_end() -> float:
	return end() - abutment_length


## The visible intrados, relative to the uncrested curve's elevation.
func soffit_offset(distance: float) -> float:
	var x := (distance - (start + length * 0.5)) / (length * 0.5 - abutment_length)
	return -crown_thickness - arch_rise + arch_rise * sqrt(maxf(0.0, 1.0 - x * x))


func validation_error(road_length: float) -> String:
	for value: float in [start, length, clear_width, parapet_height, parapet_width,
			crest, abutment_length, arch_rise, crown_thickness, channel_depth,
			channel_half_width, channel_blend]:
		if not is_finite(value):
			return "stone bridge values must be finite"
	if start < 0.0 or length < 8.0 or length > 60.0 or end() > road_length:
		return "stone bridge span must fit the route and be 8–60 m long"
	if clear_width < 4.0 or clear_width > 12.0 or parapet_height < 0.3 or parapet_height > 1.2 \
			or parapet_width < 0.25 or parapet_width > 1.0 or crest < 0.0 or crest > 0.3:
		return "stone bridge deck/parapets exceed supported bounds"
	if abutment_length < 2.0 or abutment_length * 2.0 >= length - 4.0 \
			or arch_rise < 1.0 or crown_thickness < 0.4 \
			or channel_depth < arch_rise + crown_thickness + 0.5 or channel_depth > 15.0:
		return "stone bridge must have solid abutments and an open arch above its floor"
	if channel_half_width < clear_width * 0.5 + parapet_width + 4.0 \
			or channel_half_width > 100.0 or channel_blend < 2.0 or channel_blend > 30.0:
		return "stone bridge channel must extend beyond the structure and blend into land"
	return ""


## A straight, unbanked reservation keeps the arch and channel unambiguous.
## Other structures retain their existing alignment support.
func alignment_error(sampler: RoadSampler) -> String:
	var forward := sampler.forward(start)
	var point := sampler.position(start)
	for i in ceili(length) + 1:
		var at := minf(start + i, end())
		if sampler.forward(at).dot(forward) < 0.999 or (sampler.position(at) - point).cross(forward).length() > 0.05 \
				or absf(sampler.right(at).y) > 0.001:
			return "stone bridge requires a straight unbanked reservation"
	return ""
