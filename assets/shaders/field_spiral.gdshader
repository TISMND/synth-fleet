shader_type canvas_item;
// Rotating spiral arms — like a galaxy or whirlpool.
// Arms wind outward from center, rotating continuously.

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float arm_count : hint_range(1.0, 8.0) = 3.0;
uniform float arm_width : hint_range(0.05, 0.5) = 0.25;
uniform float wind_tightness : hint_range(0.5, 6.0) = 2.5;
uniform float rotation_speed : hint_range(0.0, 4.0) = 1.0;
uniform float trail_decay : hint_range(0.5, 4.0) = 1.5;
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
	float angle = atan(uv.y, uv.x);

	// Spiral: angle offset increases with distance (logarithmic spiral)
	float spiral_angle = angle - dist * wind_tightness - t * rotation_speed;

	float ac = max(arm_count, 1.0);
	// Map to arm period
	float arm_phase = mod(spiral_angle * ac / TAU, 1.0);
	// Distance from arm center (0.5 = center of arm)
	float arm_dist = abs(arm_phase - 0.5) * 2.0;

	float aw = max(arm_width, 0.001);
	float arm = smoothstep(aw, aw * 0.15, arm_dist);

	// Trailing edge decay — arm fades more on one side for motion feel
	float trail_phase = mod(spiral_angle * ac / TAU + 0.25, 1.0);
	float trail = exp(-trail_phase * trail_decay) * 0.5;
	arm = max(arm, trail * smoothstep(aw * 2.0, 0.0, arm_dist));

	// Noise texture on arms for detail
	float n = noise(vec2(angle * 3.0 + t * 0.5, dist * 8.0));
	arm *= 0.7 + 0.3 * n;

	// Radial fade — center and edge
	float inner_fade = smoothstep(0.0, 0.2, dist);
	float outer_fade = smoothstep(1.05, 0.8, dist);
	arm *= inner_fade * outer_fade;

	// Core glow
	float core = pow(max(0.0, 1.0 - dist * 1.5), 2.5) * 0.25;

	float intensity = (arm + core) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * arm * 0.12;

	float alpha = clamp(intensity * 0.85, 0.0, 1.0) * opacity;
	if (raw_dist > 1.0) alpha = 0.0;

	float pt = pulse_tint * smoothstep(0.0, 0.3, pulse_intensity);
	col = mix(col, field_color.rgb * max(max(col.r, col.g), col.b), pt);
	COLOR = vec4(col, alpha * modulate_alpha);
}
