shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float barrier_width : hint_range(0.02, 0.2) = 0.08;
uniform float pulse_decay : hint_range(0.1, 2.0) = 0.5;
uniform float flash_intensity : hint_range(0.5, 4.0) = 2.0;

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Ring center position (average of inner and outer)
	float ring_center = (1.0 + radius_ratio) * 0.5;

	// Pulse contracts the ring slightly
	float pulse_contract = pulse_intensity * 0.05;
	float current_center = ring_center - pulse_contract;

	// Solid ring band
	float ring_dist = abs(dist - current_center);
	float half_width = barrier_width * 0.5;
	float ring = smoothstep(half_width, half_width - 0.02, ring_dist);

	// Inner soft glow
	float inner_glow = smoothstep(half_width + 0.1, half_width, ring_dist) * 0.3;

	// Flash on pulse
	float flash = pulse_intensity * flash_intensity;

	float intensity = (ring + inner_glow) * brightness;
	intensity += flash * ring;

	// Subtle rotation animation
	float angle = atan(uv.y, uv.x);
	float scan = sin(angle * 3.0 + t * 2.0) * 0.1 + 0.9;
	intensity *= scan;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * flash * ring * 0.3;

	float alpha = clamp((ring * 0.9 + inner_glow) * opacity, 0.0, 1.0);

	if (dist > 1.05) alpha = 0.0;

	COLOR = vec4(col, alpha * modulate_alpha);
}
