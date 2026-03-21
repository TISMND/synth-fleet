shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float scan_frequency : hint_range(4.0, 40.0) = 20.0;
uniform float scan_speed : hint_range(1.0, 10.0) = 4.0;
uniform float jitter_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float jitter_rate : hint_range(0.0, 8.0) = 3.0;
uniform float aberration : hint_range(0.0, 0.1) = 0.03;
uniform float outer_radius : hint_range(0.5, 1.0) = 0.95;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	if (dist > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}

	// Horizontal scanlines
	float scan_y = UV.y * scan_frequency + t * scan_speed;
	float scanline = 0.65 + 0.35 * sin(scan_y * TAU);

	// Holographic jitter: periodic horizontal displacement
	float jitter = 0.0;
	if (jitter_intensity > 0.0 && jitter_rate > 0.0) {
		float jitter_hash = hash(vec2(floor(t * jitter_rate), floor(UV.y * 8.0)));
		// Sporadic jitter — only triggers sometimes
		float trigger = step(0.85 - jitter_intensity * 0.3, jitter_hash);
		jitter = (jitter_hash - 0.5) * 0.1 * jitter_intensity * trigger;
	}

	// Chromatic aberration with jitter offset
	float r_offset = aberration + jitter;
	float b_offset = -aberration + jitter;

	// Shape: ring or full based on radius_ratio
	float inner_mask = smoothstep(radius_ratio * 0.4, radius_ratio * 0.4 + 0.1, dist);
	float outer_mask = smoothstep(outer_radius, outer_radius - 0.08, dist);
	float shape = inner_mask * outer_mask;

	// Chromatic split shapes
	vec2 uv_r = uv + vec2(r_offset, 0.0);
	vec2 uv_b = uv + vec2(b_offset, 0.0);
	float dist_r = length(uv_r) * 2.0;
	float dist_b = length(uv_b) * 2.0;
	float shape_r = smoothstep(radius_ratio * 0.4, radius_ratio * 0.4 + 0.1, dist_r) * smoothstep(outer_radius, outer_radius - 0.08, dist_r);
	float shape_b = smoothstep(radius_ratio * 0.4, radius_ratio * 0.4 + 0.1, dist_b) * smoothstep(outer_radius, outer_radius - 0.08, dist_b);

	// Flicker: occasional full-frame dropout
	float flicker = 1.0;
	if (jitter_rate > 0.0) {
		float flicker_hash = hash(vec2(floor(t * jitter_rate * 0.5), 0.0));
		flicker = flicker_hash > 0.08 ? 1.0 : 0.2;
	}

	// Color build with chromatic split
	vec3 col;
	col.r = field_color.r * shape_r * 1.2;
	col.g = field_color.g * shape;
	col.b = field_color.b * shape_b * 1.2;

	col *= scanline * flicker * brightness * 1.5;
	col += col * pulse_intensity * 1.5;

	// Core glow
	float core = smoothstep(0.5, 0.0, dist) * inner_mask;
	col += field_color.rgb * core * 0.2 * brightness;
	col += vec3(1.0) * core * 0.1;

	// Soft circular edge
	float edge_fade = smoothstep(1.0, 0.92, dist);
	float alpha = shape * (scanline * 0.4 + 0.6) * flicker * opacity * edge_fade;
	alpha = clamp(alpha, 0.0, 1.0);

	COLOR = vec4(col, alpha * modulate_alpha);
}
