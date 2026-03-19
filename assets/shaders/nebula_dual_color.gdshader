shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform vec4 secondary_color : source_color = vec4(1.0, 0.3, 0.5, 1.0);
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

	float layer1 = fbm(uv * 3.5 + vec2(t * 0.2, -t * 0.15));
	float layer2 = fbm(uv * 3.0 + vec2(-t * 0.15, t * 0.2) + 100.0);

	layer1 = pow(layer1, 2.0 - density * 0.25);
	layer2 = pow(layer2, 2.0 - density * 0.25);

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 1.0 - radial_spread, dist);

	// Additive blend of two colored layers
	vec3 col1 = nebula_color.rgb * layer1 * brightness;
	vec3 col2 = secondary_color.rgb * layer2 * brightness;
	vec3 col = (col1 + col2) * falloff * 2.0;

	float alpha = max(layer1, layer2) * falloff * nebula_color.a;
	COLOR = vec4(col, alpha * modulate_alpha);
}
