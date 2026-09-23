class_name WaterTelemetry
extends RefCounted
## Append-only recording fields. Missing water data in older callers means dry.

const FIELDS: Array[String] = ["immersion", "intake_clearance", "flooding", "stalled", "restarting",
	"torque_scale", "intake_seconds", "restart_seconds", "deep_seconds", "dry_seconds",
	"current_x", "current_y", "current_z", "relative_speed", "buoyancy_ratio",
	"drag_x", "drag_y", "drag_z", "physics_usec", "fl_wetness", "fr_wetness", "rl_wetness", "rr_wetness"]


static func snapshot(water: VehicleWaterController, weight: float) -> Dictionary:
	var state := water.state
	return {
		"immersion": state.body_immersion, "intake_clearance": state.intake_clearance,
		"flooding": state.flooding, "stalled": 1.0 if state.stalled else 0.0,
		"restarting": 1.0 if state.restarting else 0.0, "torque_scale": state.torque_scale,
		"intake_seconds": state.intake_seconds, "restart_seconds": state.restart_seconds,
		"deep_seconds": state.deep_seconds, "dry_seconds": state.dry_seconds,
		"current_x": water.current_velocity.x, "current_y": water.current_velocity.y,
		"current_z": water.current_velocity.z, "relative_speed": water.relative_speed,
		"buoyancy_ratio": water.buoyancy_force.y / maxf(weight, 0.001),
		"drag_x": water.drag_force.x, "drag_y": water.drag_force.y, "drag_z": water.drag_force.z,
		"physics_usec": water.water_time_usec,
		"fl_wetness": water.wheel_wetness[0], "fr_wetness": water.wheel_wetness[1],
		"rl_wetness": water.wheel_wetness[2], "rr_wetness": water.wheel_wetness[3],
	}


static func default_value(field: String) -> float:
	if field == "intake_clearance":
		return INF
	return 1.0 if field == "torque_scale" else 0.0
