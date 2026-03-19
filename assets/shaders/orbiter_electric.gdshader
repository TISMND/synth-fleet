shader_type canvas_item;

uniform vec4 orb_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float brightness : hint_range(0.5, 6.0) = 2.5;
uniform float animation_speed : hint_range(0.0, 5.0) = 2.0;
uniform int shape_type : hint_range(0, 5) = 0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.0;

// Electric-specific
uniform float arc_density : hint_range(2.0, 8.0) = 4.0;
uniform float arc_intensity : hint_range(0.5, 3.0) = 1.5;
uniform float jitter : hint_range(0.5, 4.0) = 2.0;

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

	// Core
	float core = smoothstep(0.35, 0.0, d) * 1.5;

	// Electric arcs radiating from center
	float angle = atan(uv.y, uv.x);
	float arc_phase = angle * arc_density + t * jitter;
	float arc = sin(arc_phase + noise(vec2(arc_phase, t * 3.0)) * 6.0);
	arc = pow(abs(arc), 3.0) * arc_intensity;
	// Mask arcs to shape boundary
	float arc_mask = smoothstep(0.6, 0.1, d);
	arc *= arc_mask;

	// Crackling edge
	float edge_noise = noise(vec2(angle * 8.0, t * 5.0));
	float edge = smoothstep(0.4, 0.3, d) * smoothstep(0.1, 0.3, d);
	edge *= edge_noise * 2.0;

	float intensity = (core + arc + edge) * brightness;
	intensity += intensity * pulse_intensity * 1.5;

	vec3 col = orb_color.rgb * intensity;
	col += vec3(0.8, 0.9, 1.0) * core * 0.4; // white-blue core

	float alpha = clamp((core + arc * 0.5 + edge) * 0.8, 0.0, 1.0);

	COLOR = vec4(col, alpha * modulate_alpha);
}
