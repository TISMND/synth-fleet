shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float pulse_tint : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float ring_count : hint_range(0.0, 12.0) = 5.0;
uniform float ring_width : hint_range(0.0, 0.1) = 0.03;
uniform float expansion_speed : hint_range(0.0, 3.0) = 1.0;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float raw_dist = length(uv) * 2.0;
	float dist = raw_dist / max(outer_radius, 0.01);

	// Ring mask
	float outer = smoothstep(1.0, 0.98, dist);
	float inner = smoothstep(radius_ratio - 0.02, radius_ratio, dist);
	float ring_mask = outer * inner;

	// Concentric expanding rings
	float rc = max(ring_count, 0.001);
	float ring_phase = dist * rc - t * expansion_speed;
	float rings = abs(sin(ring_phase * 3.14159));
	float rw = max(ring_width, 0.001);
	rings = smoothstep(1.0 - rw * 10.0, 1.0, rings);

	// Fade rings at edges
	float edge_fade = smoothstep(1.0, 0.85, dist) * smoothstep(radius_ratio, radius_ratio + 0.1, dist);

	float intensity = rings * ring_mask * edge_fade * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	// Soft outer glow
	float glow = smoothstep(1.05, 0.95, dist) * smoothstep(0.9, 1.0, dist) * 0.3;
	intensity += glow * brightness;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * rings * ring_mask * edge_fade * 0.15;

	float alpha = clamp(intensity * 0.8, 0.0, 1.0) * opacity;

	if (raw_dist > 1.0) alpha = 0.0;

	float pt = pulse_tint * smoothstep(0.0, 0.3, pulse_intensity);
	col = mix(col, field_color.rgb * max(max(col.r, col.g), col.b), pt);
	COLOR = vec4(col, alpha * modulate_alpha);
}
