shader_type canvas_item;

uniform vec4 orb_color : source_color = vec4(0.7, 0.3, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 6.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 5.0) = 0.5;
uniform int shape_type : hint_range(0, 5) = 1; // diamond default
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

// Crystal-specific
uniform float facet_count : hint_range(3.0, 12.0) = 6.0;
uniform float refraction : hint_range(0.1, 1.0) = 0.4;
uniform float sparkle_speed : hint_range(0.5, 5.0) = 2.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

	// Faceted internal reflections
	float angle = atan(uv.y, uv.x);
	float facet_angle = floor(angle / (6.28318 / facet_count)) * (6.28318 / facet_count);
	float facet_edge = abs(angle - facet_angle - 3.14159 / facet_count);
	facet_edge = facet_edge / (3.14159 / facet_count);

	// Internal facet shine
	float facet_shine = pow(1.0 - facet_edge, 3.0) * refraction;

	// Rotating sparkle highlight
	float sparkle_angle = t * sparkle_speed;
	float sparkle = pow(max(0.0, cos(angle - sparkle_angle)), 16.0) * 0.8;
	sparkle += pow(max(0.0, cos(angle - sparkle_angle + 3.14159)), 16.0) * 0.4;

	// Body
	float body = smoothstep(0.5, 0.1, d);

	// Edge highlight
	float edge = smoothstep(0.5, 0.4, d) * smoothstep(0.25, 0.4, d) * 1.5;

	float intensity = (body * (1.0 + facet_shine) + edge + sparkle * body) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	// Prismatic color split
	vec3 col = orb_color.rgb * intensity;
	col += vec3(0.2, 0.0, 0.1) * sparkle * body * brightness; // warm sparkle tint
	col += vec3(1.0) * edge * 0.3;

	float alpha = clamp(body * 0.9, 0.0, 1.0);

	COLOR = vec4(col, alpha * modulate_alpha);
}
