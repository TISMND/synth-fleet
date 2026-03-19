shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 2.0;
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

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV + seed_offset;
	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;

	float cloud = fbm(uv * 3.0 + vec2(t * 0.15, -t * 0.1));
	cloud = pow(cloud, 2.0 - density * 0.3);

	// Strong HDR core glow
	float core_glow = exp(-dist * dist * 8.0);
	float halo = smoothstep(1.0, 0.3, dist) * cloud;

	float total = halo + core_glow * 1.5;
	vec3 col = nebula_color.rgb * total * brightness;
	// White-hot center
	col += vec3(1.0) * core_glow * brightness * 0.8;

	float alpha = smoothstep(0.02, 0.15, total) * nebula_color.a;
	alpha *= smoothstep(1.0, 0.3, dist);
	COLOR = vec4(col, alpha * modulate_alpha);
}
