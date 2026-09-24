// Shared by the actual spatial water shader and the GPU readback diagnostic.
// Contract: all positions local XZ; parameters packed once per physics snapshot.
uniform vec4 wave_ambient[2];
uniform vec4 wave_packets[16];
uniform vec4 wave_directions[16];
uniform vec4 wave_shape = vec4(1.5, 2.0, 0.5, 0.15);
uniform vec2 wave_envelope = vec2(0.12, 0.75);
uniform vec4 wave_bow = vec4(0.0, 0.0, 0.0, 1.5);
uniform vec4 wave_bow_direction = vec4(0.0, -1.0, 1.0, 0.0);

vec2 wave_pulse(float q) {
	if (abs(q) >= 1.0) { return vec2(0.0); }
	float t = 1.0 - q * q;
	return vec2(t * t * cos(PI * q),
		-4.0 * q * t * cos(PI * q) - PI * t * t * sin(PI * q));
}

vec3 wave_packet(vec2 point, vec4 data, vec4 direction) {
	float age = data.z;
	if (data.w == 0.0 || age < 0.0 || age >= direction.z) { return vec3(0.0); }
	vec2 d = point - data.xy;
	float core = sqrt(dot(d, d) + wave_shape.z * wave_shape.z);
	float radius = core - wave_shape.z;
	float q = (radius - wave_shape.y * age) / wave_shape.x;
	if (abs(q) >= 1.0) { return vec3(0.0); }
	vec2 profile = wave_pulse(q);
	float attenuation = 1.0 / (1.0 + wave_shape.w * radius);
	float value = profile.x * attenuation;
	vec2 gradient = d / core * (profile.y / wave_shape.x * attenuation
		- profile.x * wave_shape.w * attenuation * attenuation);
	if (direction.w > 0.5) {
		float forward = dot(d, direction.xy);
		float t = clamp((-forward / core + 0.2) / 0.6, 0.0, 1.0);
		float mask = t * t * (3.0 - 2.0 * t);
		vec2 mask_gradient = (-direction.xy / core + d * (forward / (core * core * core)))
			* (6.0 * t * (1.0 - t) / 0.6);
		gradient = gradient * mask + value * mask_gradient;
		value *= mask;
	}
	float strength = data.w * smoothstep(0.0, wave_envelope.x, age)
		* (1.0 - smoothstep(direction.z - wave_envelope.y, direction.z, age));
	return vec3(value * strength, gradient * strength);
}

vec3 wave_bow_value(vec2 point) {
	if (wave_bow.z == 0.0) { return vec3(0.0); }
	vec2 forward = wave_bow_direction.xy;
	vec2 right = vec2(-forward.y, forward.x);
	vec2 d = point - wave_bow.xy;
	float u = dot(d, forward) / wave_bow.w;
	float v = dot(d, right) / wave_bow_direction.z;
	if (abs(u) >= 1.0 || abs(v) >= 1.0) { return vec3(0.0); }
	vec2 longitudinal = wave_pulse(u);
	float side = 1.0 - v * v;
	vec2 gradient = forward * (longitudinal.y * side * side / wave_bow.w)
		+ right * (longitudinal.x * -4.0 * v * side / wave_bow_direction.z);
	return vec3(longitudinal.x * side * side, gradient) * wave_bow.z;
}

vec3 wave_raw(vec2 point) {
	vec3 result = vec3(0.0);
	for (int i = 0; i < 2; i++) {
		vec4 wave = wave_ambient[i];
		float angle = dot(point, wave.xy) + wave.w;
		result += vec3(wave.z * sin(angle), wave.z * cos(angle) * wave.xy);
	}
	for (int i = 0; i < 16; i++) {
		result += wave_packet(point, wave_packets[i], wave_directions[i]);
	}
	return result + wave_bow_value(point);
}

vec3 wave_value(vec2 point, float limit, vec2 limit_gradient) {
	if (limit <= 0.0) { return vec3(0.0); }
	vec3 raw = wave_raw(point);
	float denominator = sqrt(limit * limit + raw.x * raw.x);
	float r = raw.x / denominator;
	float l = limit / denominator;
	return vec3(limit * r, raw.yz * (l * l * l) + limit_gradient * (r * r * r));
}
