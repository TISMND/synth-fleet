shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.4, 0.9, 0.5, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.3;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float radial_spread : hint_range(0.05, 1.0) = 0.2;

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
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float ang_a = hash(i) * 6.2832;
	float ang_b = hash(i + vec2(1.0, 0.0)) * 6.2832;
	float ang_c = hash(i + vec2(0.0, 1.0)) * 6.2832;
	float ang_d = hash(i + vec2(1.0, 1.0)) * 6.2832;
	float a = dot(vec2(cos(ang_a), sin(ang_a)), f);
	float b = dot(vec2(cos(ang_b), sin(ang_b)), f - vec2(1.0, 0.0));
	float c = dot(vec2(cos(ang_c), sin(ang_c)), f - vec2(0.0, 1.0));
	float d = dot(vec2(cos(ang_d), sin(ang_d)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV + seed_offset;

	float cells = voronoi(uv * 4.0, t);
	float cloud = fbm(uv * 3.0 + t * 0.1);

	// Combine cellular and cloud patterns
	float combined = (1.0 - cells) * 0.7 + cloud * 0.5;
	combined = pow(combined, 2.0 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 1.0 - radial_spread, dist);

	float result = combined * falloff;
	vec3 col = nebula_color.rgb * result * brightness * 2.0;
	// Edge glow on cells
	col += nebula_color.rgb * smoothstep(0.3, 0.0, cells) * 0.3 * falloff;

	float alpha = result * nebula_color.a;
	COLOR = vec4(col, alpha * modulate_alpha);
}
