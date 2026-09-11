class_name SurfaceDef
extends Resource
## Physical properties of a ground surface (asphalt, mud, ...).
## Ground collision bodies point at one of these through their "surface" meta entry.

## Short identifier, also used as the GripTable key ("asphalt", "mud", ...).
@export var id: StringName = &""
@export var display_name: String = ""
## Base tire friction. 1.0 = dry asphalt.
@export_range(0.0, 2.0) var grip: float = 1.0
## Rolling resistance: resisting force = rolling_resistance x wheel load.
@export_range(0.0, 0.5) var rolling_resistance: float = 0.015
## How far wheels sink into the surface, in metres.
@export_range(0.0, 0.2) var sink_depth: float = 0.0
## Extra drag per wheel in contact: force = drag x speed (N per m/s).
@export var drag: float = 0.0
## Colour used for gray-box geometry.
@export var debug_color: Color = Color.GRAY
