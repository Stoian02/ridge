shader_type spatial;
render_mode cull_disabled;

#include "res://water/waves/water_wave_math.gdshaderinc"

varying float interaction_height;

void vertex() {
	// UV.x is the conservative per-vertex cap; UV2 contains its baked gradient.
	vec3 wave = wave_value(VERTEX.xz, UV.x, UV2);
	VERTEX.y += wave.x;
	NORMAL = normalize(vec3(-wave.y, 1.0, -wave.z));
	// Compare actual bounded height with ambient-only height. This follows the
	// drawn triangles; no second packet loop, extra layer or cosmetic wave clock.
	// Ambient colour/strength is exactly unchanged when no car wave is present.
	float ambient = 0.0;
	for (int i = 0; i < 2; i++) {
		vec4 component = wave_ambient[i];
		ambient += component.z * sin(dot(VERTEX.xz, component.xy) + component.w);
	}
	float quiet = UV.x > 0.0 ? UV.x * ambient / sqrt(UV.x * UV.x + ambient * ambient) : 0.0;
	interaction_height = wave.x - quiet;
}

void fragment() {
	// Same sRGB-authored vertex palette as the existing standard water material.
	vec3 low = COLOR.rgb / 12.92;
	vec3 high = pow((COLOR.rgb + vec3(0.055)) / 1.055, vec3(2.4));
	ALBEDO = mix(high, low, lessThanEqual(COLOR.rgb, vec3(0.04045)));
	// A restrained aerated crest, only where vehicle waves really raise water.
	// Keep alpha/depth readability unchanged, including the dry shoreline fade.
	float crest = smoothstep(0.004, 0.045, interaction_height);
	ALBEDO = mix(ALBEDO, vec3(0.72, 0.84, 0.80), crest * 0.85);
	ALPHA = COLOR.a;
	ROUGHNESS = mix(0.18, 0.45, crest);
	METALLIC = 0.0;
	SPECULAR = 0.65;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
