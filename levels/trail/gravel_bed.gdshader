shader_type spatial;
render_mode cull_disabled;

// Fine compacted chips, not additional rigid bodies. The larger loose fragments
// above this bed have matching visible meshes and real convex collision.
varying vec3 world_position;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz * 12.0;
	vec2 cell = floor(p);
	float nearest = 10.0;
	float next_nearest = 10.0;
	float shade = 0.0;
	vec2 facet_direction = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cell + vec2(float(x), float(y));
			vec2 point = id + 0.1 + 0.8 * vec2(hash(id), hash(id + 43.7));
			vec2 offset = p - point;
			float d = dot(offset, offset);
			if (d < nearest) {
				next_nearest = nearest;
				nearest = d;
				shade = hash(id + 7.1);
				facet_direction = offset;
			} else {
				next_nearest = min(next_nearest, d);
			}
		}
	}
	float edge = next_nearest - nearest;
	float aa = max(fwidth(edge), 0.01);
	float chip = smoothstep(0.01, 0.035 + aa, edge);
	float facet = facet_direction.x + facet_direction.y > 0.0 ? 1.04 : 0.86;
	// Vertex palette is authored in sRGB, like StructureMesh's standard material.
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 stone = base * (0.85 + shade * 0.65) * facet;
	vec3 detailed = mix(base * 0.65, stone, chip);
	float detail = 1.0 - smoothstep(0.5, 1.5, max(length(dFdx(p)), length(dFdy(p))));
	ALBEDO = mix(base, detailed, detail);
	ROUGHNESS = 0.95;
}
