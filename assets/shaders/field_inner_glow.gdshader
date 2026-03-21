shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float glow_falloff : hint_range(0.0, 6.0) = 2.5;
uniform float core_size : hint_range(0.0, 0.5) = 0.15;
uniform float flicker_speed : hint_range(0.0, 4.0) = 1.0;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;

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
	vec2 uv = UV - 0.5;
	float raw_dist = length(uv) * 2.0;
	float dist = raw_dist / max(outer_radius, 0.01);

	// Flicker: subtle temporal noise
	float flicker = 1.0;
	if (flicker_speed > 0.0) {
		float n = noise(vec2(t * flicker_speed, t * flicker_speed * 0.7));
		flicker = 0.85 + 0.15 * n;
	}

	// Core: bright center region
	float cs = max(core_size, 0.001);
	float core = smoothstep(cs, cs * 0.3, dist * 0.5);

	// Outer glow: soft radial falloff from center
	float glow_range = 1.0 - radius_ratio * 0.5;
	float glow_dist = clamp(dist / max(glow_range, 0.001), 0.0, 1.0);
	float gf = max(glow_falloff, 0.001);
	float glow = pow(max(0.0, 1.0 - glow_dist), gf);

	// Combine
	float intensity = (core * 2.0 + glow) * brightness * flicker;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * core * 0.4 * brightness;

	float alpha = clamp((core * 0.9 + glow * 0.7) * opacity, 0.0, 1.0);

	if (raw_dist > 1.0) alpha = 0.0;

	col = mix(col, field_color.rgb * length(col), pulse_tint * clamp(pulse_intensity, 0.0, 1.0));
	COLOR = vec4(col, alpha * modulate_alpha);
}
