class_name VehicleWaterProfile
extends Resource
## Approved, water-only starting tuning. Runtime flooding/timers never live here.

@export var intake_local_position: Vector3 = Vector3(0.45, 0.15, -1.50)
@export var body_linear_drag: Vector3 = Vector3(50.0, 80.0, 40.0)
@export var body_quadratic_drag: Vector3 = Vector3(350.0, 500.0, 220.0)
@export var wheel_quadratic_drag: float = 8.0
@export var fresh_buoyancy_ratio: float = 1.15
@export var flooded_buoyancy_ratio: float = 0.35
@export var stall_submerged_seconds: float = 0.60
@export var restart_clearance: float = 0.05
@export var restart_clear_seconds: float = 1.00
@export var restart_torque_ramp_seconds: float = 0.50
@export var intake_warning_clearance: float = 0.12
@export var deep_immersion_threshold: float = 0.65
@export var flood_grace_seconds: float = 3.00
@export var flood_fill_seconds: float = 8.00
@export var body_dry_threshold: float = 0.02
@export var drain_clear_seconds: float = 1.00
@export var flood_drain_seconds: float = 12.00
