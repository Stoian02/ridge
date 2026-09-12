extends GutTest

const PERF := {"fps": 60.0, "process_ms": 4.2, "physics_ms": 1.1}


func test_format_shows_performance() -> void:
	var text := TelemetryOverlay.format(TelemetrySample.make(), PERF)
	assert_string_contains(text, "60 fps")
	assert_string_contains(text, "physics 1.1 ms")


func test_format_shows_speed_and_reverse_gear() -> void:
	var text := TelemetryOverlay.format(TelemetrySample.make(), PERF)
	assert_string_contains(text, "42.5 km/h")
	assert_string_contains(text, "gear R")


func test_format_has_a_line_per_wheel() -> void:
	var text := TelemetryOverlay.format(TelemetrySample.make(), PERF)
	for wheel_name in ["FL", "FR", "RL", "RR"]:
		assert_string_contains(text, wheel_name + " mud")
