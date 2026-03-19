shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.8, 0.3, 0.6, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.25;
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

	// Anisotropic stretch for tendril effect
	vec2 stretched = vec2(uv.x * 1.0, uv.y * 4.0);
	float wisp1 = fbm(stretched * 3.0 + vec2(t * 0.3, -t * 0.6));
	float wisp2 = fbm(stretched * 2.0 + vec2(-t * 0.2, t * 0.4) + 30.0);

	// Sharpen into filaments
	float filament = pow(wisp1, 1.5) * 0.7 + pow(wisp2, 2.0) * 0.5;
	filament = pow(filament, 2.0 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.15, dist);

	float cloud = filament * falloff;
	vec3 col = nebula_color.rgb * cloud * brightness * 2.5;

	float alpha = cloud * nebula_color.a;
	COLOR = vec4(col, alpha * modulate_alpha);
}
