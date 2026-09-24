shader_type spatial;
render_mode cull_disabled;

#include "res://water/waves/water_wave_math.gdshaderinc"

void vertex() {
	// UV.x is the conservative per-vertex cap; UV2 contains its baked gradient.
	vec3 wave = wave_value(VERTEX.xz, UV.x, UV2);
	VERTEX.y += wave.x;
	NORMAL = normalize(vec3(-wave.y, 1.0, -wave.z));
}

void fragment() {
	// Same sRGB-authored vertex palette as the existing standard water material.
	vec3 low = COLOR.rgb / 12.92;
	vec3 high = pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4));
	ALBEDO = mix(high, low, lessThanEqual(COLOR.rgb, vec3(0.04045)));
	ALPHA = COLOR.a;
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
