shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.4, 0.9, 0.5, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.9, 0.4, 0.2, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.3;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(127.1, 311.7)));
}

float voronoi(vec2 p, float t) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash2(i + neighbor);
			point = 0.5 + 0.5 * sin(t + 6.2831 * point);
			float d = length(neighbor + point - f);
			min_dist = min(min_dist, d);
		}
	}
	return min_dist;
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV + seed_offset;

	// Primary voronoi layer
	float cells1 = voronoi(uv * 4.0, t);
	float cloud1 = fbm(uv * 3.0 + t * 0.1);
	float layer1 = (1.0 - cells1) * 0.7 + cloud1 * 0.4;
	layer1 = pow(layer1, 2.0 - density * 0.3);

	// Secondary voronoi layer — offset scale and time for contrast
	float cells2 = voronoi(uv * 3.2 + 30.0, t * 0.8 + 20.0);
	float cloud2 = fbm(uv * 2.5 - t * 0.08 + 60.0);
	float layer2 = (1.0 - cells2) * 0.7 + cloud2 * 0.4;
	layer2 = pow(layer2, 2.0 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.2, dist);

	// Dual color additive blend
	vec3 col1 = nebula_color.rgb * layer1 * brightness;
	vec3 col2 = secondary_color.rgb * layer2 * brightness;
	vec3 col = (col1 + col2) * falloff * 2.0;
	// Cell edge highlights
	col += nebula_color.rgb * smoothstep(0.3, 0.0, cells1) * 0.2 * falloff;
	col += secondary_color.rgb * smoothstep(0.3, 0.0, cells2) * 0.2 * falloff;

	float alpha = max(layer1, layer2) * falloff * nebula_color.a;
	COLOR = vec4(col, alpha * modulate_alpha);
}
