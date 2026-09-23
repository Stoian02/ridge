class_name WaterBodyDef
extends Resource
## Authoring values only. A registered body snapshots these values, never car state.

@export var id: StringName = &"water"
@export var current_velocity: Vector3 = Vector3.ZERO
@export var shore_probe_blend: float = 0.10
@export var depth_epsilon: float = 0.002
@export var color: Color = Color(0.28, 0.55, 0.58, 0.30)
