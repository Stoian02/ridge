class_name CarBodyDef
extends Resource
## The look of a car's low-poly body (spec §6.1). Lengths are shares of the body's
## length unless named in metres. It never changes the car's collision box.

@export_group("Colours")
@export var body_color: Color = Color(0.86, 0.32, 0.16)
@export var window_color: Color = Color(0.2, 0.24, 0.3)
@export var trim_color: Color = Color(0.12, 0.12, 0.13)
@export var rim_color: Color = Color(0.75, 0.75, 0.78)

@export_group("Shape")
## Hood in front of the windscreen.
@export_range(0.0, 1.0) var hood_length: float = 0.3
## Cabin roof.
@export_range(0.0, 1.0) var cabin_length: float = 0.35
## Height of the cabin above the body (m).
@export var cabin_height: float = 0.45
## How far the windscreen and rear window lean (0 = upright).
@export_range(0.0, 0.5) var windscreen_slope: float = 0.12
@export_range(0.0, 0.5) var rear_window_slope: float = 0.1
## How much the nose and tail narrow and drop at their ends.
@export_range(0.0, 0.5) var nose_taper: float = 0.2
@export_range(0.0, 0.5) var tail_taper: float = 0.1
## The body's top edges are bevelled by this much (m).
@export var bevel: float = 0.06

@export_group("Extras")
@export var rear_spoiler: bool = false
@export var big_wing: bool = false
@export var hood_scoop: bool = false
@export var roof_rack: bool = false
@export var bull_bar: bool = false
@export var spare_wheel: bool = false
@export var fender_flares: bool = false
