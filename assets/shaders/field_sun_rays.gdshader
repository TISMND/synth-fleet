shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.0, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float ray_count : hint_range(0.0, 24.0) = 8.0;
uniform float ray_width : hint_range(0.0, 0.5) = 0.2;
uniform float ray_rotation_speed : hint_range(0.0, 3.0) = 0.5;
uniform float length_variance : hint_range(0.0, 1.0) = 0.4;
uniform float width_variance : hint_range(0.0, 1.0) = 0.3;
uniform float brightness_variance : hint_range(0.0, 1.0) = 0.5;
uniform float chaos_speed : hint_range(0.0, 3.0) = 0.8;
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

	float rotated_angle = angle + t * ray_rotation_speed;
	float rc = max(ray_count, 0.001);
	float ray_index = floor((rotated_angle / TAU + 0.5) * rc);
	float ray_phase = fract((rotated_angle / TAU + 0.5) * rc);

	float chaos_t = t * chaos_speed;
	float ray_seed = ray_index * 1.618;

	float len_noise = noise(vec2(ray_seed, chaos_t * 0.4));
	float ray_length = 1.0 * (1.0 - length_variance * 0.6 * len_noise);

	float width_noise = noise(vec2(ray_seed + 50.0, chaos_t * 0.3));
	float rw = max(ray_width, 0.001);
	float local_width = rw * (1.0 - width_variance * 0.5 + width_variance * width_noise);

	float bright_noise = noise(vec2(ray_seed + 100.0, chaos_t * 0.7));
	float ray_bright = 1.0 - brightness_variance * 0.6 + brightness_variance * 0.6 * bright_noise;

	float ray_center_dist = abs(ray_phase - 0.5) * 2.0;
	float ray = smoothstep(local_width, local_width * 0.3, ray_center_dist);

	float inner_start = radius_ratio * 0.3;
	float radial = smoothstep(ray_length, inner_start, dist);
	float center_fade = smoothstep(0.0, inner_start + 0.1, dist);

	float sway = sin(ray_index * 2.7 + t * 1.5) * 0.02;
	float sway_offset = abs(ray_phase - 0.5 + sway) * 2.0;
	float swayed_ray = smoothstep(local_width * 1.1, local_width * 0.2, sway_offset);
	ray = max(ray, swayed_ray * 0.6);

	float intensity = ray * radial * center_fade * ray_bright * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	float base_glow = pow(max(0.0, 1.0 - dist), 2.0) * 0.2 * brightness;
	base_glow += base_glow * pulse_intensity;

	vec3 col = field_color.rgb * (intensity + base_glow);
	col += vec3(1.0) * ray * radial * ray_bright * 0.15 * brightness;

	float alpha = clamp((ray * radial * center_fade * 0.8 + base_glow * 0.4) * opacity, 0.0, 1.0);

	if (raw_dist > 1.0) alpha = 0.0;

	COLOR = vec4(col, alpha * modulate_alpha);
}
