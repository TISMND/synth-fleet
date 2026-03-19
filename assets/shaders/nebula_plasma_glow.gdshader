shader_type canvas_item;

uniform vec4 nebula_color : source_color = vec4(0.9, 0.2, 0.4, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.5;
uniform float animation_speed : hint_range(0.0, 3.0) = 0.4;
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

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV + seed_offset;

	// Smooth low-frequency noise
	float plasma1 = noise(uv * 2.0 + vec2(t * 0.3, t * 0.2));
	float plasma2 = noise(uv * 1.5 + vec2(-t * 0.25, t * 0.35) + 20.0);
	float plasma3 = noise(uv * 2.5 + vec2(t * 0.15, -t * 0.2) + 40.0);

	float combined = (plasma1 + plasma2 + plasma3) / 3.0;
	combined = pow(combined, 1.5 - density * 0.2);

	// Color cycling
	float hue_shift = sin(t * 0.5 + combined * 3.0) * 0.15;
	vec3 base = nebula_color.rgb;
	base.r += hue_shift;
	base.b -= hue_shift * 0.5;

	vec2 center = UV - 0.5;
	float dist = length(center) * 2.0;
	float falloff = smoothstep(1.0, 0.2, dist);

	float cloud = combined * falloff;
	vec3 col = base * cloud * brightness * 2.5;

	float alpha = cloud * nebula_color.a;
	COLOR = vec4(col, alpha * modulate_alpha);
}
