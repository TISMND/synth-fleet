shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.2, 0.3, 0.7, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.2;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

float stars(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float star = 0.0;
	// Sparse bright points
	float h = hash(cell);
	if (h > 0.92) {
		vec2 center = vec2(hash(cell + 0.1), hash(cell + 0.2));
		float d = length(f - center);
		float twinkle = sin(TIME * (2.0 + h * 4.0)) * 0.3 + 0.7;
		star = smoothstep(0.15, 0.0, d) * twinkle * (h - 0.92) * 12.5;
	}
	return star;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV + seed_offset;

	// Diffuse cloud background
	float cloud = fbm(uv * 3.0 + vec2(t * 0.1, -t * 0.08));
	cloud = pow(cloud, 2.5 - density * 0.4);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.2, dist);

	// Embedded stars
	float star_field = stars(uv * 20.0);

	float nebula = cloud * falloff;
	vec3 col = nebula_color.rgb * nebula * brightness * 1.5;
	col += vec3(1.0, 0.95, 0.8) * star_field * falloff * brightness;

	float alpha = max(nebula, star_field * 0.8) * nebula_color.a;
	alpha *= smoothstep(1.0, 0.5, dist);
	COLOR = vec4(col, alpha * modulate_alpha);
}
