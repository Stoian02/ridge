class_name TelemetrySample
extends RefCounted
## A realistic telemetry dictionary for tests: same shape as Car.get_telemetry().


static func make() -> Dictionary:
	var wheel := {
		"contact": true,
		"surface": &"mud",
		"load": 3200.0,
		"compression": 0.12,
		"slip_ratio": 0.05,
		"slip_angle_deg": -2.5,
		"spin": 30.0,
	}
	return {
		"speed_kmh": 42.5,
		"rpm": 4100.0,
		"gear": -1,
		"throttle": 0.0,
		"brake": 1.0,
		"steer": -0.25,
		"airborne": false,
		"position": Vector3(1.0, 2.0, 3.0),
		"rotation_deg": Vector3(0.0, 90.0, 0.0),
		"wheels": [wheel, wheel.duplicate(), wheel.duplicate(), wheel.duplicate()],
	}
