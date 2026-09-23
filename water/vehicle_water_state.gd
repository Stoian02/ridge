class_name VehicleWaterState
extends RefCounted
## Independent per-car engine and flooding state; no frame/scene processing.

var body_immersion: float = 0.0
var intake_clearance: float = INF
var intake_submerged: bool = false
var intake_at_risk: bool = false
var flooding: float = 0.0
var stalled: bool = false
var restarting: bool = false
var sinking: bool = false
var torque_scale: float = 1.0
var intake_seconds: float = 0.0
var restart_seconds: float = 0.0
var deep_seconds: float = 0.0
var dry_seconds: float = 0.0


func reset() -> void:
	body_immersion = 0.0
	intake_clearance = INF
	intake_submerged = false
	intake_at_risk = false
	flooding = 0.0
	stalled = false
	restarting = false
	sinking = false
	torque_scale = 1.0
	intake_seconds = 0.0
	restart_seconds = 0.0
	deep_seconds = 0.0
	dry_seconds = 0.0


func step(delta: float, profile: VehicleWaterProfile, immersion: float,
		intake_in_column: bool, clearance: float) -> void:
	if delta <= 0.0:
		return
	body_immersion = clampf(immersion, 0.0, 1.0)
	intake_clearance = clearance if intake_in_column else INF
	intake_submerged = intake_in_column and clearance < 0.0
	intake_at_risk = intake_in_column and clearance <= profile.intake_warning_clearance
	_step_engine(delta, profile, intake_in_column)
	_step_flooding(delta, profile)
	var critical := (profile.fresh_buoyancy_ratio - 1.0) \
			/ maxf(profile.fresh_buoyancy_ratio - profile.flooded_buoyancy_ratio, 0.0001)
	if body_immersion < profile.deep_immersion_threshold:
		sinking = false
	elif sinking:
		sinking = flooding > critical - 0.05
	else:
		sinking = flooding > critical


func buoyancy_ratio(profile: VehicleWaterProfile) -> float:
	return lerpf(profile.fresh_buoyancy_ratio, profile.flooded_buoyancy_ratio, flooding)


func _step_engine(delta: float, profile: VehicleWaterProfile, intake_in_column: bool) -> void:
	if not stalled:
		intake_seconds = intake_seconds + delta if intake_submerged else 0.0
		if intake_seconds + 0.0000001 >= profile.stall_submerged_seconds:
			stalled = true
			restarting = false
			restart_seconds = 0.0
			torque_scale = 0.0
		else:
			torque_scale = minf(1.0, torque_scale + delta / maxf(profile.restart_torque_ramp_seconds, 0.0001))
		return
	var clear := not intake_in_column or intake_clearance >= profile.restart_clearance
	restart_seconds = restart_seconds + delta if clear else 0.0
	restarting = clear
	if restart_seconds + 0.0000001 >= profile.restart_clear_seconds:
		stalled = false
		restarting = false
		intake_seconds = 0.0
		torque_scale = clampf((restart_seconds - profile.restart_clear_seconds) \
				/ maxf(profile.restart_torque_ramp_seconds, 0.0001), 0.0, 1.0)
		restart_seconds = 0.0


func _step_flooding(delta: float, profile: VehicleWaterProfile) -> void:
	if body_immersion >= profile.deep_immersion_threshold:
		var before := maxf(0.0, deep_seconds - profile.flood_grace_seconds)
		deep_seconds += delta
		var after := maxf(0.0, deep_seconds - profile.flood_grace_seconds)
		flooding = minf(1.0, flooding + (after - before) / maxf(profile.flood_fill_seconds, 0.0001))
	if body_immersion <= profile.body_dry_threshold:
		var before := maxf(0.0, dry_seconds - profile.drain_clear_seconds)
		dry_seconds += delta
		var after := maxf(0.0, dry_seconds - profile.drain_clear_seconds)
		if dry_seconds + 0.0000001 >= profile.drain_clear_seconds:
			deep_seconds = 0.0
			flooding = maxf(0.0, flooding - (after - before) / maxf(profile.flood_drain_seconds, 0.0001))
	else:
		dry_seconds = 0.0
