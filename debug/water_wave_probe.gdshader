shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://water/waves/water_wave_math.gdshaderinc"

uniform vec4 probe_points[64];
uniform bool calibrate = false;

void fragment() {
	int index = clamp(int(floor(UV.x * 64.0)), 0, 63);
	vec4 point = probe_points[index];
	float height = calibrate ? point.w : wave_value(point.xy, point.z, vec2(0.0)).x;
	// Reversible 24-bit RGB coding in an LDR unshaded target. The driver is
	// calibrated against known heights before any parity result is accepted.
	uint value = uint(round(clamp((height + 0.125) / 0.25, 0.0, 1.0) * 16777215.0));
	COLOR = vec4(float((value >> 16u) & 255u), float((value >> 8u) & 255u), float(value & 255u), 255.0) / 255.0;
}
