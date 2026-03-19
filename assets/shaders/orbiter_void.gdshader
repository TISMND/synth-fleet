shader_type canvas_item;

uniform vec4 orb_color : source_color = vec4(0.5, 0.0, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 6.0) = 2.5;
uniform float animation_speed : hint_range(0.0, 5.0) = 0.8;
uniform int shape_type : hint_range(0, 5) = 0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

// Void-specific
uniform float void_size : hint_range(0.05, 0.5) = 0.2;
uniform float rim_width : hint_range(0.05, 0.4) = 0.15;
uniform float distortion : hint_range(0.1, 2.0) = 0.8;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y
	);
}

float sdf_circle(vec2 p) { return length(p); }
float sdf_diamond(vec2 p) { p = abs(p); return (p.x + p.y) * 0.7071; }
float sdf_triangle(vec2 p) {
	p.y += 0.15;
	float k = sqrt(3.0);
	p.x = abs(p.x) - 0.5;
	p.y = p.y + 0.5 / k;
	if (p.x + k * p.y > 0.0) p = vec2(p.x - k * p.y, -k * p.x - p.y) * 0.5;
	p.x -= clamp(p.x, -1.0, 0.0);
	return -length(p) * sign(p.y);
}
float sdf_star(vec2 p) {
	float a = atan(p.y, p.x) + 0.7854;
	float r = length(p);
	float k = abs(fract(a * 0.6366 + 0.25) - 0.5) * 2.0;
	return r * (0.6 + 0.4 * k);
}
float sdf_crescent(vec2 p) {
	float d1 = length(p);
	float d2 = length(p - vec2(0.2, 0.0));
	return max(d1, -(d2 - 0.35));
}
float sdf_hexagon(vec2 p) {
	p = abs(p);
	return max(dot(p, normalize(vec2(1.0, 1.732))), p.x);
}

float get_sdf(vec2 p, int shape) {
	if (shape == 1) return sdf_diamond(p);
	if (shape == 2) return sdf_triangle(p);
	if (shape == 3) return sdf_star(p);
	if (shape == 4) return sdf_crescent(p);
	if (shape == 5) return sdf_hexagon(p);
	return sdf_circle(p);
}

void fragment() {
	float modulate_alpha = COLOR.a;
	float t = TIME * animation_speed;
	vec2 uv = (UV - 0.5) * 2.0;

	float d = get_sdf(uv, shape_type);

	// Warped edge using noise
	float angle = atan(uv.y, uv.x);
	float edge_warp = noise(vec2(angle * 3.0 + t, t * 0.5)) * distortion * 0.1;

	// Dark void center
	float void_mask = smoothstep(void_size + edge_warp, void_size * 0.5, d);

	// Bright rim around void
	float rim_inner = void_size;
	float rim_outer = void_size + rim_width;
	float rim = smoothstep(rim_inner, rim_inner + 0.05, d) * smoothstep(rim_outer + edge_warp, rim_outer - 0.05, d);

	// Outer glow falloff
	float outer_glow = smoothstep(0.6, 0.2, d) * (1.0 - void_mask) * 0.3;

	// Swirling accretion pattern
	float swirl = sin(angle * 3.0 - t * 2.0 + d * 8.0) * 0.5 + 0.5;
	swirl *= smoothstep(rim_outer, rim_inner, d) * 0.4;

	float intensity = (rim * 2.0 + outer_glow + swirl) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = orb_color.rgb * intensity;
	col += vec3(1.0) * rim * 0.5 * brightness; // white-hot rim
	// Void is dark
	col *= (1.0 - void_mask * 0.9);

	float body = smoothstep(0.55, 0.2, d);
	float alpha = clamp(body * 0.9, 0.0, 1.0);

	COLOR = vec4(col, alpha * modulate_alpha);
}
