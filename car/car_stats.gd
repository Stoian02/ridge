class_name CarStats
extends Resource
## Every tunable number for one car. Tune in the Inspector - no code changes.
## Units: metres, kilograms, seconds, newtons, newton-metres; degrees where named.
## Axes: forward is -Z, right is +X, up is +Y.

enum DriveType { FWD, RWD, AWD }

@export_group("Identity")
@export var display_name: String = "Rally Car"
## Key into the GripTable ("rally", "truck", ...).
@export var archetype: StringName = &"rally"

@export_group("Body")
@export var mass: float = 1300.0
## Centre of mass relative to the body origin. Lower = harder to roll over.
@export var center_of_mass: Vector3 = Vector3(0.0, -0.15, 0.0)
## Resistance to rotating, kg*m^2, around x (pitch), y (yaw) and z (roll).
## Zero means Godot derives it from the gray-box body, which is far too easy to roll.
@export var inertia: Vector3 = Vector3.ZERO
## Size of the gray-box body (collision box and mesh).
@export var body_size: Vector3 = Vector3(1.6, 0.5, 4.2)
## Aerodynamic drag: force = aero_drag x speed^2.
@export var aero_drag: float = 0.42

@export_group("Wheels")
@export var wheel_radius: float = 0.33
@export var wheel_width: float = 0.24
## Distance between left and right wheel centres.
@export var track_width: float = 1.52
## Distance between front and rear axles.
@export var wheelbase: float = 2.52
## Height of the suspension top mounts relative to the body origin.
@export var wheel_mount_height: float = 0.1
## Rotational inertia of one wheel (tire, rim, brake, axle), kg*m^2.
@export var wheel_inertia: float = 1.2

@export_group("Suspension")
## Wheel travel from fully extended to fully compressed.
@export var suspension_length: float = 0.35
@export var spring_stiffness: float = 26500.0
@export var compress_damping: float = 2000.0
@export var rebound_damping: float = 3000.0
@export var bump_stop_stiffness: float = 200000.0
@export var anti_roll_front: float = 5000.0
@export var anti_roll_rear: float = 8000.0

@export_group("Tires")
## The car's own tire friction, multiplied with the surface grip.
@export var tire_grip: float = 1.1
## Rear tire grip as a share of the front's. Below 1.0 the car rotates more.
@export var rear_grip_bias: float = 0.96
## Slip ratio where forward/backward grip peaks.
@export var peak_slip_ratio: float = 0.12
## Slip angle (degrees) where sideways grip peaks.
@export var peak_slip_angle_deg: float = 8.0
## Grip left when fully sliding, as a fraction of peak grip.
@export_range(0.0, 1.0) var slide_grip: float = 0.75
## Slip maths treats speeds below this as this (m/s), for low-speed stability.
@export var low_speed_reference: float = 3.0

@export_group("Engine")
## Torque curve: rpm points and the torque (Nm) at each. Same length, ascending rpm.
@export var torque_curve_rpm: PackedFloat32Array = PackedFloat32Array([1000, 2500, 4000, 5500, 6500, 7200])
@export var torque_curve_nm: PackedFloat32Array = PackedFloat32Array([220, 320, 390, 380, 340, 280])
@export var idle_rpm: float = 1000.0
@export var redline_rpm: float = 7200.0
## Simulated clutch slip: pulling away, the engine may rev up to this rpm.
@export var launch_rpm: float = 3500.0
## Engine braking torque (Nm at the engine) when off the throttle.
@export var engine_braking_nm: float = 50.0

@export_group("Gearbox")
@export var gear_ratios: PackedFloat32Array = PackedFloat32Array([3.3, 2.1, 1.5, 1.15, 0.92, 0.76])
@export var reverse_ratio: float = 3.3
@export var final_drive: float = 4.4
@export var upshift_rpm: float = 6800.0
@export var downshift_rpm: float = 3000.0
## Seconds with no drive torque during a gear change.
@export var shift_time: float = 0.18
@export_range(0.0, 1.0) var drivetrain_efficiency: float = 0.85

@export_group("Drivetrain")
@export var drive_type: DriveType = DriveType.AWD
## AWD only: share of drive torque sent to the front axle.
@export_range(0.0, 1.0) var front_torque_split: float = 0.35

@export_group("Brakes")
## Total brake torque for the whole car at full pedal (Nm).
@export var brake_torque: float = 10000.0
## Share of brake torque on the front axle.
@export_range(0.0, 1.0) var brake_front_bias: float = 0.6
## ABS: holds the brake back once a wheel slips this much, so it keeps turning
## near peak grip instead of locking (a locked wheel cannot steer the car).
@export var abs_enabled: bool = true
@export var abs_target_slip: float = 0.15
## Below this speed (m/s) with no pedal pressed, the brakes hold the car.
@export var auto_hold_speed: float = 0.5
## Below this speed (m/s) the brake pedal selects reverse and gas selects drive.
@export var direction_change_speed: float = 1.0

@export_group("Assists")
## Traction control: trims engine torque while the driven wheels spin. Touch
## pedals are on/off, so without it full throttle usually means wheelspin.
@export var traction_control: bool = true
## Slip ratio the traction control allows before it starts trimming torque.
@export var traction_slip_target: float = 0.3

@export_group("Steering")
@export var max_steer_deg: float = 32.0
## How fast the front wheels turn, degrees per second.
@export var steer_rate_deg: float = 180.0
## Share of the tire's best slip angle the steering assist adds on top of the
## geometric angle. Below 1.0 the front tires stay short of ploughing.
@export var steer_assist_slip: float = 0.75

@export_group("Air control")
## Seconds all four wheels must be off the ground before air control activates.
@export var airborne_grace: float = 0.1
@export var air_pitch_torque: float = 3000.0
## Set to 0 to turn off steer-to-roll in the air.
@export var air_roll_torque: float = 1500.0


## Suspension top-mount position of a wheel, relative to the body origin.
func wheel_mount_position(is_front: bool, is_left: bool) -> Vector3:
	var x := -track_width * 0.5 if is_left else track_width * 0.5
	var z := -wheelbase * 0.5 if is_front else wheelbase * 0.5
	return Vector3(x, wheel_mount_height, z)
