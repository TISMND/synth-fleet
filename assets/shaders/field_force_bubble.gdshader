shader_type canvas_item;

uniform vec4 field_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 4.0) = 1.0;
uniform float animation_speed : hint_range(0.1, 3.0) = 1.0;
uniform float radius_ratio : hint_range(0.0, 1.0) = 0.8;
uniform float pulse_intensity : hint_range(0.0, 4.0) = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

// Per-shader params
uniform float refraction_strength : hint_range(0.0, 0.3) = 0.05;
uniform float edge_width : hint_range(0.02, 0.3) = 0.1;
uniform float wobble_speed : hint_range(0.1, 4.0) = 1.0;

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
	float dist = length(uv) * 2.0;

	// Wobble distortion
	float angle = atan(uv.y, uv.x);
	float wobble = noise(vec2(angle * 3.0, t * wobble_speed)) * refraction_strength;
	float distorted_dist = dist + wobble;

	// Outer edge of bubble
	float outer = smoothstep(1.0, 1.0 - edge_width, distorted_dist);
	// Inner edge (hollow center)
	float inner = smoothstep(radius_ratio, radius_ratio + edge_width, distorted_dist);
	float shell = outer * inner;

	// Edge brightening (fresnel-like)
	float edge_glow = smoothstep(radius_ratio + edge_width * 0.5, 1.0 - edge_width * 0.3, distorted_dist);
	edge_glow = pow(edge_glow, 2.0) * 0.5;

	// Translucent interior fill
	float interior = outer * (1.0 - inner) * 0.15;

	// Combine
	float intensity = (shell + edge_glow + interior) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = field_color.rgb * intensity;
	col += vec3(1.0) * shell * 0.2; // white highlight on shell

	float alpha = (shell * 0.8 + edge_glow * 0.4 + interior) * opacity;
	alpha = clamp(alpha, 0.0, 1.0);

	// Kill pixels outside circle
	if (dist > 1.0) alpha = 0.0;

	COLOR = vec4(col, alpha * modulate_alpha);
}
