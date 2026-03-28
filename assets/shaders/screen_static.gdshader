shader_type canvas_item;
// Screen static / interference overlay — noise-based TV static.
// Controlled by intensity uniform (0 = invisible, 1 = full static).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float scan_speed : hint_range(0.0, 20.0) = 8.0;
uniform float grain_scale : hint_range(1.0, 200.0) = 80.0;
uniform float bar_count : hint_range(0.0, 20.0) = 6.0;
uniform float bar_opacity : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// High-frequency noise grain
	float grain = hash(uv * grain_scale + vec2(t * 17.3, t * 13.7));

	// Horizontal scan bars that drift
	float scan = sin((uv.y + t * scan_speed * 0.1) * bar_count * 6.2831853) * 0.5 + 0.5;
	scan = smoothstep(0.3, 0.7, scan) * bar_opacity;

	// Combine
	float noise = mix(grain, 1.0, scan * 0.4);
	float alpha = intensity * noise * 0.85;

	COLOR = vec4(vec3(grain * 0.9 + 0.1), alpha * modulate_alpha);
}
