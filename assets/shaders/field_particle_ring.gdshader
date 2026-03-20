shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float particle_count : hint_range(4.0, 32.0) = 12.0;
uniform float orbit_speed : hint_range(0.1, 4.0) = 1.0;
uniform float particle_size : hint_range(0.01, 0.1) = 0.04;

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

	float ring_radius = (1.0 + radius_ratio) * 0.5;
	float total = 0.0;

	// Orbit particles
	for (float i = 0.0; i < 32.0; i++) {
		if (i >= particle_count) break;
		float base_angle = i / particle_count * 6.28318;
		float speed_var = 1.0 + hash(vec2(i, 0.0)) * 0.3;
		float angle = base_angle + t * orbit_speed * speed_var;
		float r_var = ring_radius + (hash(vec2(i, 1.0)) - 0.5) * 0.1;
		vec2 particle_pos = vec2(cos(angle), sin(angle)) * r_var * 0.5;
		float d = length(uv - particle_pos);
		float glow = smoothstep(particle_size, 0.0, d);
		glow = pow(glow, 1.5);
		total += glow;
	}

	// Subtle ring outline
	float ring_dist = abs(dist - ring_radius);
	float ring_line = smoothstep(0.03, 0.0, ring_dist) * 0.15;

	float intensity = (total + ring_line) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * total * 0.1;

	float alpha = clamp(intensity * 0.9, 0.0, 1.0) * opacity;

	if (dist > 1.05) alpha = 0.0;

	COLOR = vec4(col, alpha * modulate_alpha);
}
