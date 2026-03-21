shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float scan_frequency : hint_range(0.0, 40.0) = 20.0;
uniform float scan_speed : hint_range(0.0, 10.0) = 4.0;
uniform float jitter_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float jitter_rate : hint_range(0.0, 8.0) = 3.0;
uniform float aberration : hint_range(0.0, 0.1) = 0.03;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;
uniform float blink_interval : hint_range(0.0, 8.0) = 3.0;
uniform float blink_duration : hint_range(0.0, 1.0) = 0.1;
uniform float blink_irregularity : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float blink_value(float t) {
	float bi = max(blink_interval, 0.1);
	float bd = max(blink_duration, 0.01);
	float window_idx = floor(t / bi);
	float window_start = window_idx * bi;

	float offset_rand = hash(vec2(window_idx, 7.31));
	float dur_rand = hash(vec2(window_idx, 13.57));

	float offset = mix(bi * 0.5, bi * 0.1 + offset_rand * bi * 0.8 * blink_irregularity, blink_irregularity);
	float dur = max(mix(bd, bd * (0.5 + dur_rand * blink_irregularity), blink_irregularity), 0.01);

	float blink_start = window_start + offset;
	float blink_end = blink_start + dur;

	if (t >= blink_start && t < blink_end) {
		float into = (t - blink_start) / dur;
		float edge = smoothstep(0.0, 0.15, into) * smoothstep(1.0, 0.85, into);
		return 1.0 - edge * 0.85;
	}

	// Check previous window bleed
	float prev_idx = window_idx - 1.0;
	float prev_start = prev_idx * bi;
	float prev_offset_rand = hash(vec2(prev_idx, 7.31));
	float prev_dur_rand = hash(vec2(prev_idx, 13.57));
	float prev_offset = mix(bi * 0.5, bi * 0.1 + prev_offset_rand * bi * 0.8 * blink_irregularity, blink_irregularity);
	float prev_dur = max(mix(bd, bd * (0.5 + prev_dur_rand * blink_irregularity), blink_irregularity), 0.01);
	float prev_blink_start = prev_start + prev_offset;
	float prev_blink_end = prev_blink_start + prev_dur;
	if (t >= prev_blink_start && t < prev_blink_end) {
		float into = (t - prev_blink_start) / prev_dur;
		float edge = smoothstep(0.0, 0.15, into) * smoothstep(1.0, 0.85, into);
		return 1.0 - edge * 0.85;
	}

	return 1.0;
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float raw_dist = length(uv) * 2.0;
	float dist = raw_dist / max(outer_radius, 0.01);

	// Horizontal scanlines
	float sf = max(scan_frequency, 0.001);
	float scan_y = UV.y * sf + t * scan_speed;
	float scanline = 0.65 + 0.35 * sin(scan_y * TAU);

	// Holographic jitter
	float jitter = 0.0;
	if (jitter_intensity > 0.0 && jitter_rate > 0.0) {
		float jitter_hash = hash(vec2(floor(t * jitter_rate), floor(UV.y * 8.0)));
		float trigger = step(0.85 - jitter_intensity * 0.3, jitter_hash);
		jitter = (jitter_hash - 0.5) * 0.1 * jitter_intensity * trigger;
	}

	float r_offset = aberration + jitter;
	float b_offset = -aberration + jitter;

	// Shape
	float inner_mask = smoothstep(radius_ratio * 0.4, radius_ratio * 0.4 + 0.1, dist);
	float outer_mask = smoothstep(1.0, 0.92, dist);
	float shape = inner_mask * outer_mask;

	vec2 uv_r = uv + vec2(r_offset, 0.0);
	vec2 uv_b = uv + vec2(b_offset, 0.0);
	float dist_r = length(uv_r) * 2.0 / max(outer_radius, 0.01);
	float dist_b = length(uv_b) * 2.0 / max(outer_radius, 0.01);
	float shape_r = smoothstep(radius_ratio * 0.4, radius_ratio * 0.4 + 0.1, dist_r) * smoothstep(1.0, 0.92, dist_r);
	float shape_b = smoothstep(radius_ratio * 0.4, radius_ratio * 0.4 + 0.1, dist_b) * smoothstep(1.0, 0.92, dist_b);

	// Blink
	float blink = blink_interval > 0.0 ? blink_value(t) : 1.0;

	// Color with chromatic split
	vec3 col;
	col.r = field_color.r * shape_r * 1.2;
	col.g = field_color.g * shape;
	col.b = field_color.b * shape_b * 1.2;

	col *= scanline * blink * brightness * 1.5;
	col += col * pulse_intensity * 1.5;

	// Core glow
	float core = smoothstep(0.5, 0.0, dist) * inner_mask;
	col += field_color.rgb * core * 0.2 * brightness * blink;
	col += vec3(1.0) * core * 0.1 * blink;

	float edge_fade = smoothstep(1.0, 0.92, dist);
	float alpha = shape * (scanline * 0.4 + 0.6) * blink * opacity * edge_fade;
	alpha = clamp(alpha, 0.0, 1.0);

	if (raw_dist > 1.0) alpha = 0.0;

	float pt = pulse_tint * smoothstep(0.0, 0.3, pulse_intensity);
	col = mix(col, field_color.rgb * max(max(col.r, col.g), col.b), pt);
	COLOR = vec4(col, alpha * modulate_alpha);
}
