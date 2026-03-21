shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float turbulence_speed : hint_range(0.0, 4.0) = 1.5;
uniform float plasma_density : hint_range(0.0, 8.0) = 4.0;
uniform float edge_glow : hint_range(0.0, 3.0) = 1.5;
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
	vec2 uv = UV - 0.5;
	float raw_dist = length(uv) * 2.0;
	float dist = raw_dist / max(outer_radius, 0.01);
	float angle = atan(uv.y, uv.x);

	// Ring mask
	float outer = smoothstep(1.0, 0.95, dist);
	float inner = smoothstep(radius_ratio - 0.02, radius_ratio, dist);
	float ring = outer * inner;

	// Turbulent plasma noise
	float pd = max(plasma_density, 0.001);
	vec2 plasma_uv = vec2(angle * pd / 3.14159, dist * 3.0);
	plasma_uv += vec2(t * turbulence_speed * 0.3, t * turbulence_speed * 0.5);
	float plasma = fbm(plasma_uv * 2.0);
	float plasma2 = fbm(plasma_uv * 3.0 + vec2(5.0, 3.0));
	float combined = mix(plasma, plasma2, 0.5);

	// Edge glow effect
	float rim = smoothstep(0.85, 0.98, dist) * smoothstep(1.02, 0.98, dist) * edge_glow;

	float intensity = (combined * ring + rim) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * combined * ring * 0.15;

	float alpha = clamp((ring * 0.7 + rim * 0.5) * opacity, 0.0, 1.0);

	if (raw_dist > 1.0) alpha = 0.0;

	float pt = pulse_tint * smoothstep(0.0, 0.3, pulse_intensity);
	col = mix(col, field_color.rgb * max(max(col.r, col.g), col.b), pt);
	COLOR = vec4(col, alpha * modulate_alpha);
}
