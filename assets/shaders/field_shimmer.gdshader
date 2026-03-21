shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float wave_frequency : hint_range(2.0, 12.0) = 5.0;
uniform float distortion_strength : hint_range(0.01, 0.15) = 0.05;
uniform float rainbow_intensity : hint_range(0.0, 1.0) = 0.5;

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

vec3 hue_shift(vec3 col, float shift) {
	// Simple hue rotation via YIQ
	float cos_h = cos(shift);
	float sin_h = sin(shift);
	vec3 yiq = vec3(
		dot(col, vec3(0.299, 0.587, 0.114)),
		dot(col, vec3(0.596, -0.274, -0.322)),
		dot(col, vec3(0.211, -0.523, 0.312))
	);
	float i_rot = yiq.y * cos_h - yiq.z * sin_h;
	float q_rot = yiq.y * sin_h + yiq.z * cos_h;
	return vec3(
		yiq.x + 0.956 * i_rot + 0.621 * q_rot,
		yiq.x - 0.272 * i_rot - 0.647 * q_rot,
		yiq.x - 1.106 * i_rot + 1.703 * q_rot
	);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;
	float angle = atan(uv.y, uv.x);

	// Distorted wave pattern
	float distort = noise(uv * 8.0 + t * 0.5) * distortion_strength;
	float wave = sin((dist + distort) * wave_frequency * 3.14159 - t * 2.0);
	float angular_wave = sin(angle * 3.0 + t * 1.5) * 0.3;
	wave = wave * 0.5 + 0.5; // normalize 0-1
	wave += angular_wave * 0.2;
	wave = clamp(wave, 0.0, 1.0);

	// Iridescent color shift
	float hue_phase = (dist * 2.0 + angle * 0.5 + t * 0.8) * rainbow_intensity;
	vec3 shifted_color = hue_shift(field_color.rgb, hue_phase * 3.14159 * 2.0);
	vec3 col = mix(field_color.rgb, shifted_color, rainbow_intensity);

	// Inner/outer edge masking
	float inner_edge = smoothstep(radius_ratio * 0.4, radius_ratio * 0.4 + 0.15, dist);
	float outer_edge = smoothstep(1.0, 0.85, dist);
	float mask = inner_edge * outer_edge;

	// Intensity
	float intensity = wave * mask * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	col *= intensity;
	// Specular highlights on wave peaks
	float spec = pow(wave, 4.0) * mask * 0.3 * brightness;
	col += vec3(1.0) * spec;

	float alpha = clamp(mask * (wave * 0.6 + 0.2) * opacity, 0.0, 1.0);

	// Kill pixels outside circle
	if (dist > 1.0) alpha = 0.0;

	COLOR = vec4(col, alpha * modulate_alpha);
}
