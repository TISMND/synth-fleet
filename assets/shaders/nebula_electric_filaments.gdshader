shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.8;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.4;
uniform float density : hint_range(0.5, 4.0) = 2.0;
uniform float seed_offset : hint_range(0.0, 1000.0) = 0.0;
uniform float radial_spread : hint_range(0.05, 1.0) = 0.2;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

float ridged_noise(vec2 p) {
	return 1.0 - abs(noise(p) * 2.0 - 1.0);
}

float ridged_fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * ridged_noise(p);
		p = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV + seed_offset;

	float ridge1 = ridged_fbm(uv * 4.0 + vec2(t * 0.2, -t * 0.3));
	float ridge2 = ridged_fbm(uv * 3.0 + vec2(-t * 0.15, t * 0.25) + 50.0);

	float combined = ridge1 * 0.6 + ridge2 * 0.5;
	combined = pow(combined, 2.0 - density * 0.3);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 1.0 - radial_spread, dist);

	float cloud = combined * falloff;
	vec3 col = nebula_color.rgb * cloud * brightness * 2.0;
	// Bright filament highlights
	col += vec3(1.0) * pow(ridge1, 3.0) * 0.4 * falloff * brightness;

	float alpha = cloud * nebula_color.a;
	COLOR = vec4(col, alpha * modulate_alpha);
}
