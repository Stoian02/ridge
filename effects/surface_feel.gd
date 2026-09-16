class_name SurfaceFeel
extends Resource
## How a surface looks and sounds under a wheel (spec §3): which spray it throws,
## in which colour, which rolling sound it makes, and whether sliding tyres squeal
## and smoke on it. Kept apart from SurfaceDef, whose values are physics.

enum SprayKind { NONE, CLODS, DUST, SMOKE }
enum RollingSound { NONE, ROAD, GRAVEL, MUD, SNOW }

@export var spray: SprayKind = SprayKind.NONE
@export var spray_color: Color = Color(0.62, 0.52, 0.38)
@export var rolling: RollingSound = RollingSound.NONE
## Sliding tyres squeal (and, with SMOKE spray, smoke) on this surface.
@export var skids: bool = false
@export_range(0.0, 1.0) var skid_volume: float = 1.0
